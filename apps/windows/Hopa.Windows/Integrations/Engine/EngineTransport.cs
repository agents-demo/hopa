using System.IO;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace Hopa.Windows.Integrations.Engine;

/// <summary>
/// The NDJSON half of the engine host: one request line, one reply by id, and
/// events that do not belong to a pending request. It knows nothing about Java
/// or a process, so it can run over any two text streams.
/// </summary>
internal sealed class EngineTransport
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = null,
    };

    private readonly TextWriter input;
    private readonly TextReader output;
    private readonly Dictionary<string, TaskCompletionSource<JsonObject>> pending = new();
    private Task? loop;

    public EngineTransport(TextWriter input, TextReader output)
    {
        this.input = input;
        this.output = output;
    }

    public event Action<JsonObject>? MessageReceived;

    public void Start() => loop ??= Task.Run(ReadLoopAsync);

    public Task Completion => loop ?? Task.CompletedTask;

    public async Task<JsonObject> RequestAsync(string type, JsonObject fields, TimeSpan timeout)
    {
        var id = $"r-{Guid.NewGuid():N}";
        var completion = new TaskCompletionSource<JsonObject>(TaskCreationOptions.RunContinuationsAsynchronously);
        lock (pending)
        {
            pending[id] = completion;
        }

        var message = new JsonObject
        {
            ["type"] = type,
            ["id"] = id,
        };
        foreach (var pair in fields)
        {
            message[pair.Key] = pair.Value?.DeepClone();
        }

        Send(message);
        var finished = await Task.WhenAny(completion.Task, Task.Delay(timeout));
        if (finished != completion.Task)
        {
            lock (pending)
            {
                pending.Remove(id);
            }

            throw new TimeoutException(
                $"the sidecar did not answer {type} in {timeout.TotalSeconds:0} s" +
                (loop is { IsFaulted: true } ? $"; read loop: {loop.Exception?.InnerException?.Message}" : ""));
        }

        return await completion.Task;
    }

    public void Send(JsonObject message)
    {
        lock (input)
        {
            input.WriteLine(message.ToJsonString(JsonOptions));
            input.Flush();
        }
    }

    private async Task ReadLoopAsync()
    {
        string? line;
        while ((line = await output.ReadLineAsync()) != null)
        {
            JsonObject? message;
            try
            {
                message = JsonNode.Parse(line) as JsonObject;
            }
            catch (JsonException)
            {
                continue;
            }

            if (message == null)
            {
                continue;
            }

            var type = message["type"]?.GetValue<string>() ?? "";
            if (IsEvent(type))
            {
                MessageReceived?.Invoke(message);
                continue;
            }

            var id = message["id"]?.GetValue<string>();
            if (id == null)
            {
                continue;
            }

            TaskCompletionSource<JsonObject>? completion;
            lock (pending)
            {
                pending.Remove(id, out completion);
            }

            completion?.TrySetResult(message);
        }
    }

    private static bool IsEvent(string type) => type is
        "ready" or "log" or "device.request" or "approval.request" or "session" or "step";
}
