using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Net.WebSockets;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json.Nodes;
using Hopa.Windows.Integrations.Gateway;
using Xunit;

namespace Hopa.Windows.IntegrationTests;

/// <summary>
/// A real loopback WebSocket server: the hello, the peer roster and a full
/// approval round-trip over actual frames.
/// </summary>
public sealed class GatewaySocketTests
{
    [Fact]
    public async Task HelloAndApprovalTravelOverALocalWebSocket()
    {
        var listener = new TcpListener(IPAddress.Loopback, 0);
        listener.Start();
        var port = ((IPEndPoint)listener.LocalEndpoint).Port;
        var served = new TaskCompletionSource<bool>(TaskCreationOptions.RunContinuationsAsynchronously);
        var server = Task.Run(() => ServeAsync(listener, served));

        var credentials = new GatewayCredentials
        {
            GatewayUrl = $"ws://127.0.0.1:{port}/",
            DeviceId = "pc1",
            AccessToken = "token",
        };
        await using var client = new GatewayClient(() => credentials);
        var live = new TaskCompletionSource<bool>(TaskCreationOptions.RunContinuationsAsynchronously);
        client.StateChanged += () =>
        {
            if (client.IsLive)
            {
                live.TrySetResult(true);
            }
        };

        client.Start();
        await live.Task.WaitAsync(TimeSpan.FromSeconds(10));

        Assert.Equal("pc1", client.DeviceId);
        Assert.True(client.HasPhone);
        Assert.Equal("phone1", client.PhoneDeviceId);

        var result = await client.RequestApprovalAsync(
            new JsonObject { ["title"] = "Pay the bill?" },
            "phone1",
            TimeSpan.FromSeconds(10));

        Assert.NotNull(result);
        Assert.True(result!["body"]!["approval"]!["allow"]!.GetValue<bool>());
        await served.Task.WaitAsync(TimeSpan.FromSeconds(5));

        await client.DisposeAsync();
        listener.Stop();
        try
        {
            await server.WaitAsync(TimeSpan.FromSeconds(5));
        }
        catch (Exception)
        {
            // The server side closes when the client goes away.
        }
    }

    [Fact]
    public async Task AHandoffGoesToThePhoneAsTaskCreate()
    {
        var listener = new TcpListener(IPAddress.Loopback, 0);
        listener.Start();
        var port = ((IPEndPoint)listener.LocalEndpoint).Port;
        var handoff = new TaskCompletionSource<JsonObject>(TaskCreationOptions.RunContinuationsAsynchronously);
        var server = Task.Run(() => ServeTaskAsync(listener, handoff));

        var credentials = new GatewayCredentials
        {
            GatewayUrl = $"ws://127.0.0.1:{port}/",
            DeviceId = "pc1",
            AccessToken = "token",
        };
        await using var client = new GatewayClient(() => credentials);
        var live = new TaskCompletionSource<bool>(TaskCreationOptions.RunContinuationsAsynchronously);
        client.StateChanged += () =>
        {
            if (client.IsLive)
            {
                live.TrySetResult(true);
            }
        };

        client.Start();
        await live.Task.WaitAsync(TimeSpan.FromSeconds(10));

        var taskId = await client.SendTaskAsync("open the settings page", "phone1");
        Assert.Equal("t-handoff", taskId);

        var frame = await handoff.Task.WaitAsync(TimeSpan.FromSeconds(5));
        Assert.Equal("task.create", frame["type"]!.GetValue<string>());
        Assert.Equal("phone1", frame["to"]!.GetValue<string>());
        Assert.Equal("open the settings page", frame["body"]!["goal"]!.GetValue<string>());

        await client.DisposeAsync();
        listener.Stop();
        try
        {
            await server.WaitAsync(TimeSpan.FromSeconds(5));
        }
        catch (Exception)
        {
            // The server side closes when the client goes away.
        }
    }

    private static async Task ServeTaskAsync(
        TcpListener listener,
        TaskCompletionSource<JsonObject> handoff)
    {
        using var tcp = await listener.AcceptTcpClientAsync();
        using var stream = tcp.GetStream();
        using var ws = await AcceptAsync(stream);
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(15));

        var hello = JsonNode.Parse(await ReceiveTextAsync(ws, timeout.Token))!.AsObject();
        Assert.Equal("device.hello", hello["type"]!.GetValue<string>());
        await HelloAckAsync(ws, timeout.Token);

        while (!timeout.IsCancellationRequested)
        {
            var text = await ReceiveTextAsync(ws, timeout.Token);
            var frame = JsonNode.Parse(text)!.AsObject();
            if (frame["type"]?.GetValue<string>() != "task.create")
            {
                continue;
            }

            handoff.TrySetResult(frame);
            await SendAsync(ws, new JsonObject
            {
                ["v"] = 1,
                ["type"] = "task.ack",
                ["id"] = frame["id"]!.GetValue<string>(),
                ["to"] = "pc1",
                ["body"] = new JsonObject { ["task"] = "t-handoff" },
            }, timeout.Token);
        }
    }

    private static async Task ServeAsync(TcpListener listener, TaskCompletionSource<bool> served)
    {
        using var tcp = await listener.AcceptTcpClientAsync();
        using var stream = tcp.GetStream();
        using var ws = await AcceptAsync(stream);

        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(15));
        var hello = JsonNode.Parse(await ReceiveTextAsync(ws, timeout.Token))!.AsObject();
        Assert.Equal("device.hello", hello["type"]!.GetValue<string>());

        await HelloAckAsync(ws, timeout.Token);

        while (!timeout.IsCancellationRequested)
        {
            var text = await ReceiveTextAsync(ws, timeout.Token);
            var frame = JsonNode.Parse(text)!.AsObject();
            if (frame["type"]?.GetValue<string>() != "task.needs_approval")
            {
                continue;
            }

            var id = frame["id"]!.GetValue<string>();
            await SendAsync(ws, new JsonObject
            {
                ["v"] = 1,
                ["type"] = "task.ack",
                ["id"] = id,
                ["to"] = "pc1",
                ["body"] = new JsonObject { ["task"] = "t1" },
            }, timeout.Token);
            await SendAsync(ws, new JsonObject
            {
                ["v"] = 1,
                ["type"] = "task.result",
                ["id"] = id,
                ["from"] = "phone1",
                ["to"] = "pc1",
                ["body"] = new JsonObject
                {
                    ["task"] = "t1",
                    ["approval"] = new JsonObject { ["allow"] = true },
                },
            }, timeout.Token);
            served.TrySetResult(true);
        }
    }

    private static async Task<WebSocket> AcceptAsync(NetworkStream stream)
    {
        var reader = new StreamReader(stream, Encoding.ASCII, false, 1024, leaveOpen: true);
        var requestLine = await reader.ReadLineAsync();
        Assert.StartsWith("GET /", requestLine);

        string? key = null;
        string? line;
        while (!string.IsNullOrEmpty(line = await reader.ReadLineAsync()))
        {
            if (line.StartsWith("Sec-WebSocket-Key:", StringComparison.OrdinalIgnoreCase))
            {
                key = line["Sec-WebSocket-Key:".Length..].Trim();
            }
        }

        Assert.NotNull(key);
        var accept = Convert.ToBase64String(SHA1.HashData(
            Encoding.UTF8.GetBytes(key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11")));
        var response = "HTTP/1.1 101 Switching Protocols\r\n" +
                       "Upgrade: websocket\r\n" +
                       "Connection: Upgrade\r\n" +
                       $"Sec-WebSocket-Accept: {accept}\r\n\r\n";
        await stream.WriteAsync(Encoding.ASCII.GetBytes(response));
        await stream.FlushAsync();

        return WebSocket.CreateFromStream(
            stream,
            isServer: true,
            subProtocol: null,
            keepAliveInterval: TimeSpan.FromSeconds(30));
    }

    private static Task HelloAckAsync(WebSocket ws, CancellationToken cancellationToken) =>
        SendAsync(ws, new JsonObject
        {
            ["v"] = 1,
            ["type"] = "device.hello.ack",
            ["to"] = "pc1",
            ["body"] = new JsonObject { ["peers"] = new JsonArray("phone1", "pc1") },
        }, cancellationToken);

    private static async Task<string> ReceiveTextAsync(WebSocket ws, CancellationToken cancellationToken)
    {
        var buffer = new byte[4096];
        using var message = new MemoryStream();
        WebSocketReceiveResult result;
        do
        {
            result = await ws.ReceiveAsync(new ArraySegment<byte>(buffer), cancellationToken);
            if (result.MessageType == WebSocketMessageType.Close)
            {
                return "";
            }

            message.Write(buffer, 0, result.Count);
        }
        while (!result.EndOfMessage);

        return Encoding.UTF8.GetString(message.ToArray());
    }

    private static Task SendAsync(WebSocket ws, JsonObject frame, CancellationToken cancellationToken)
    {
        var bytes = Encoding.UTF8.GetBytes(frame.ToJsonString());
        return ws.SendAsync(
            new ArraySegment<byte>(bytes),
            WebSocketMessageType.Text,
            true,
            cancellationToken);
    }
}
