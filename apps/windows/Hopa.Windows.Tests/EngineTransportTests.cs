using System.IO;
using System.Text;
using System.Text.Json.Nodes;
using System.Threading.Channels;
using Hopa.Windows.Integrations.Engine;
using Xunit;

namespace Hopa.Windows.Tests;

/// <summary>The NDJSON transport is testable over two text streams.</summary>
public sealed class EngineTransportTests
{
    [Fact]
    public async Task ARequestGetsTheReplyWithTheSameId()
    {
        var reader = new QueueReader();
        var writer = new LineWriter();
        var transport = new EngineTransport(writer, reader);
        writer.OnLine = line =>
        {
            var id = JsonNode.Parse(line)!["id"]!.GetValue<string>();
            reader.Push($"{{\"type\":\"ok\",\"id\":\"{id}\",\"answer\":\"hello\"}}");
        };
        transport.Start();

        var response = await transport.RequestAsync(
            "say.hello",
            new JsonObject(),
            TimeSpan.FromSeconds(1));

        Assert.Equal("hello", response["answer"]!.GetValue<string>());
    }

    [Fact]
    public async Task EventsReachTheClientWithoutAPendingRequest()
    {
        var reader = new QueueReader();
        var transport = new EngineTransport(new LineWriter(), reader);
        var step = new TaskCompletionSource<JsonObject>(TaskCreationOptions.RunContinuationsAsynchronously);
        transport.MessageReceived += message =>
        {
            if (message["type"]?.GetValue<string>() == "step")
            {
                step.TrySetResult(message);
            }
        };
        transport.Start();

        reader.Push("{\"type\":\"step\",\"index\":2}");
        var received = await step.Task.WaitAsync(TimeSpan.FromSeconds(1));

        Assert.Equal(2, received["index"]!.GetValue<int>());
    }

    [Fact]
    public async Task BrowserRequestsAreEventsNotPendingReplies()
    {
        var reader = new QueueReader();
        var transport = new EngineTransport(new LineWriter(), reader);
        var request = new TaskCompletionSource<JsonObject>(TaskCreationOptions.RunContinuationsAsynchronously);
        transport.MessageReceived += message =>
        {
            if (message["type"]?.GetValue<string>() == "browser.request")
            {
                request.TrySetResult(message);
            }
        };
        transport.Start();

        reader.Push("{\"type\":\"browser.request\",\"id\":\"b1\",\"op\":\"read\"}");
        var received = await request.Task.WaitAsync(TimeSpan.FromSeconds(1));

        Assert.Equal("b1", received["id"]!.GetValue<string>());
        Assert.Equal("read", received["op"]!.GetValue<string>());
    }

    [Fact]
    public async Task AMalformedLineIsIgnored()
    {
        var reader = new QueueReader();
        var transport = new EngineTransport(new LineWriter(), reader);
        var ready = new TaskCompletionSource<JsonObject>(TaskCreationOptions.RunContinuationsAsynchronously);
        transport.MessageReceived += message => ready.TrySetResult(message);
        transport.Start();

        reader.Push("not json");
        reader.Push("{\"type\":\"ready\"}");
        var received = await ready.Task.WaitAsync(TimeSpan.FromSeconds(1));

        Assert.Equal("ready", received["type"]!.GetValue<string>());
    }

    [Fact]
    public async Task ASilentHostTimesOut()
    {
        var transport = new EngineTransport(new LineWriter(), new QueueReader());
        transport.Start();

        await Assert.ThrowsAsync<TimeoutException>(() =>
            transport.RequestAsync("never", new JsonObject(), TimeSpan.FromMilliseconds(50)));
    }

    private sealed class QueueReader : TextReader
    {
        private readonly Channel<string> lines = Channel.CreateUnbounded<string>();

        public void Push(string line) => lines.Writer.TryWrite(line);

        public override async Task<string?> ReadLineAsync() =>
            await lines.Reader.ReadAsync();
    }

    private sealed class LineWriter : TextWriter
    {
        public Action<string>? OnLine { get; set; }

        public override Encoding Encoding => Encoding.UTF8;

        public override void WriteLine(string? value) => OnLine?.Invoke(value ?? "");

        public override void Flush()
        {
        }
    }
}
