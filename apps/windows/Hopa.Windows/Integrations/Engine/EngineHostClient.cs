using System.Diagnostics;
using System.IO;
using System.Text.Json.Nodes;
using Hopa.Windows.Storage;

namespace Hopa.Windows.Integrations.Engine;

/// <summary>The .NET half of the NDJSON protocol with the Kotlin engine.</summary>
public sealed partial class EngineHostClient : IAsyncDisposable, IChatEngine
{
    private readonly Process? process;
    private readonly EngineTransport transport;

    public event Action<string>? LogReceived;

    public event Action<JsonObject>? DeviceRequested;

    public event Action<JsonObject>? ApprovalRequested;

    public event Action<JsonObject>? SessionUpdated;

    /// <summary>One action finished inside a turn; additive to protocol v1.</summary>
    public event Action<JsonObject>? StepReceived;

    public EngineHostClient()
    {
        var host = EngineHostProcess.Start();
        var started = host.Process;
        process = started;
        transport = new EngineTransport(host.Input, host.Output);
        transport.MessageReceived += OnMessage;
        transport.Start();
        _ = Task.Run(() =>
        {
            string? line;
            while ((line = started.StandardError.ReadLine()) != null)
            {
                LogReceived?.Invoke(line);
            }
        });
    }

    /// <summary>Integration tests own the process and hand over only its pipes.</summary>
    internal EngineHostClient(EngineTransport transport)
    {
        this.transport = transport;
        transport.MessageReceived += OnMessage;
        transport.Start();
    }

    public Task<JsonObject> RequestAsync(string type, JsonObject fields, TimeSpan timeout) =>
        transport.RequestAsync(type, fields, timeout);

    public async Task<TurnResult> StartTurnAsync(
        string goal,
        string? conversationId,
        JsonObject? attachment = null,
        bool planApproved = false)
    {
        var fields = new JsonObject { ["goal"] = goal };
        if (conversationId != null)
        {
            fields["conversationId"] = conversationId;
        }

        if (attachment != null)
        {
            fields["attachment"] = attachment.DeepClone();
        }

        if (planApproved)
        {
            fields["planApproved"] = true;
        }

        var response = await RequestAsync("turn.start", fields, TimeSpan.FromSeconds(120));
        var plan = new List<string>();
        if (response["plan"] is JsonArray array)
        {
            foreach (var item in array)
            {
                if (item?.GetValue<string>() is { Length: > 0 } step)
                {
                    plan.Add(step);
                }
            }
        }

        return new TurnResult(
            response["answer"]?.GetValue<string>() ?? "",
            response["conversationId"]?.GetValue<string>() ?? "",
            response["title"]?.GetValue<string>() ?? "New chat",
            response["steps"] as JsonArray,
            response["chainOk"]?.GetValue<bool>() == true,
            plan);
    }

    public async Task<List<JsonObject>> ListConversationsAsync(bool includeArchived = false)
    {
        var response = await RequestAsync(
            "conversations.list",
            new JsonObject { ["includeArchived"] = includeArchived },
            TimeSpan.FromSeconds(10));
        var items = new List<JsonObject>();
        if (response["items"] is JsonArray array)
        {
            foreach (var item in array)
            {
                if (item is JsonObject obj)
                {
                    items.Add(obj);
                }
            }
        }

        return items;
    }

    public async Task<JsonObject?> CreateConversationAsync()
    {
        var response = await RequestAsync("conversation.create", new JsonObject(), TimeSpan.FromSeconds(10));
        return response["conversation"] as JsonObject;
    }

    public async Task<JsonObject?> RenameConversationAsync(string id, string title)
    {
        var response = await RequestAsync(
            "conversation.rename",
            new JsonObject { ["conversationId"] = id, ["title"] = title },
            TimeSpan.FromSeconds(10));
        return response["conversation"] as JsonObject;
    }

    public async Task<JsonObject?> PinConversationAsync(string id, bool pinned)
    {
        var response = await RequestAsync(
            "conversation.pin",
            new JsonObject { ["conversationId"] = id, ["pinned"] = pinned },
            TimeSpan.FromSeconds(10));
        return response["conversation"] as JsonObject;
    }

    public async Task<JsonObject?> ArchiveConversationAsync(string id, bool archived)
    {
        var response = await RequestAsync(
            "conversation.archive",
            new JsonObject { ["conversationId"] = id, ["archived"] = archived },
            TimeSpan.FromSeconds(10));
        return response["conversation"] as JsonObject;
    }

    public async Task<bool> DeleteConversationAsync(string id)    {
        var response = await RequestAsync(
            "conversation.delete",
            new JsonObject { ["conversationId"] = id },
            TimeSpan.FromSeconds(10));
        return response["ok"]?.GetValue<bool>() == true;
    }

    public async Task<string> ExportConversationAsync(string id)
    {
        var response = await RequestAsync(
            "conversation.export",
            new JsonObject { ["conversationId"] = id },
            TimeSpan.FromSeconds(10));
        return response["json"]?.GetValue<string>() ?? "";
    }

    public async Task<List<JsonObject>> SearchConversationsAsync(string query)
    {
        var response = await RequestAsync(
            "conversation.search",
            new JsonObject { ["query"] = query },
            TimeSpan.FromSeconds(10));
        var items = new List<JsonObject>();
        if (response["items"] is JsonArray array)
        {
            foreach (var item in array)
            {
                if (item is JsonObject obj)
                {
                    items.Add(obj);
                }
            }
        }

        return items;
    }

    public async Task<JsonObject?> OpenConversationAsync(string id)
    {
        var response = await RequestAsync(
            "conversation.open",
            new JsonObject { ["conversationId"] = id },
            TimeSpan.FromSeconds(10));
        return response["conversation"] as JsonObject;
    }

    public async Task<JsonObject> ConfigureAsync(AppSettings settings, string bridgeToken, string modelKey)
    {
        var fields = new JsonObject
        {
            ["bridgeUrl"] = settings.BridgeUrl,
            ["useBridge"] = settings.UseBridge,
            ["bridgeToken"] = bridgeToken,
            ["bridgeRefresh"] = CredentialStore.Read("hopa.bridge.refresh"),
            ["modelProvider"] = settings.ModelProvider,
            ["modelBaseUrl"] = settings.ModelBaseUrl,
            ["modelName"] = settings.ModelName,
            ["modelKey"] = modelKey,
            ["tone"] = settings.Tone,
            ["profile"] = settings.Profile,
            ["replay"] = settings.ReplaySkills,
            ["planFirst"] = settings.PlanFirst,
            ["instantCommands"] = settings.InstantCommands,
            ["vision"] = settings.Vision,
        };
        return await RequestAsync("configure", fields, TimeSpan.FromSeconds(10));
    }

    public async Task<JsonObject> AttachFileAsync(string path)
    {
        var response = await RequestAsync(
            "file.attach",
            new JsonObject { ["path"] = path },
            TimeSpan.FromSeconds(20));
        if (response["error"]?.GetValue<string>() is { Length: > 0 } error)
        {
            throw new InvalidOperationException(error);
        }

        return response["attachment"] as JsonObject
            ?? throw new InvalidOperationException("the sidecar attached nothing");
    }

    public void CancelTurn()    {
        Send(new JsonObject { ["type"] = "turn.cancel" });
    }

    /// <summary>Pause before the next step; the takeover window owns the foreground.</summary>
    public void PauseTurn() => Send(new JsonObject { ["type"] = "turn.pause" });

    /// <summary>Resume after a takeover; the sidecar re-observes before deciding.</summary>
    public void ResumeTurn() => Send(new JsonObject { ["type"] = "turn.resume" });

    public void SendApprovalResult(string id, bool allow, string device = "pc")    {
        Send(new JsonObject
        {
            ["type"] = "approval.result",
            ["id"] = id,
            ["allow"] = allow,
            ["device"] = device,
        });
    }

    /// <summary>
    /// P4: the host owns the gateway socket; the sidecar only learns whether a
    /// phone peer is reachable, so it can attribute an approval honestly.
    /// </summary>
    public void SendGatewayState(bool paired, bool phoneOnline)
    {
        Send(new JsonObject
        {
            ["type"] = "gateway.state",
            ["paired"] = paired,
            ["phoneOnline"] = phoneOnline,
        });
    }

    public void SendDeviceResult(
        string id,
        bool ok,
        string? error = null,
        JsonObject? observation = null,
        string? app = null,
        string? text = null,
        string? image = null,
        JsonArray? apps = null)
    {
        var message = new JsonObject
        {
            ["type"] = "device.result",
            ["id"] = id,
            ["ok"] = ok,
        };
        if (error != null)
        {
            message["error"] = error;
        }

        if (observation != null)
        {
            message["observation"] = observation;
        }

        if (app != null)
        {
            message["app"] = app;
        }

        if (text != null)
        {
            message["text"] = text;
        }

        if (image != null)
        {
            message["image"] = image;
        }

        if (apps != null)
        {
            message["apps"] = apps;
        }

        Send(message);
    }

    private void Send(JsonObject message) => transport.Send(message);

    private void OnMessage(JsonObject message)
    {
        switch (message["type"]?.GetValue<string>())
        {
            case "ready":
                break;
            case "log":
                LogReceived?.Invoke(message["text"]?.GetValue<string>() ?? "");
                break;
            case "device.request":
                DeviceRequested?.Invoke(message);
                break;
            case "approval.request":
                ApprovalRequested?.Invoke(message);
                break;
            case "session":
                SessionUpdated?.Invoke(message);
                break;
            case "step":
                // Additive in v1: the turn's id lives on this message too, so
                // it must not fall through to the pending-request switch.
                StepReceived?.Invoke(message);
                break;
        }
    }

    public async ValueTask DisposeAsync()
    {
        if (process == null)
        {
            // The integration test owns the process and its pipes.
            return;
        }

        try
        {
            Send(new JsonObject { ["type"] = "shutdown" });
            if (!process.WaitForExit(3000))
            {
                process.Kill(true);
            }
        }
        catch (InvalidOperationException)
        {
            // The process already exited.
        }

        await transport.Completion.WaitAsync(TimeSpan.FromSeconds(2)).ConfigureAwait(false);
        process.Dispose();
    }
}
