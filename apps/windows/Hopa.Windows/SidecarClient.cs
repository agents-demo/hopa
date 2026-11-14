using System.Diagnostics;
using System.IO;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace Hopa.Windows;

/// <summary>The .NET half of the NDJSON protocol with the Kotlin engine.</summary>
public sealed class SidecarClient : IAsyncDisposable
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = null,
    };

    private readonly Process process;
    private readonly StreamWriter input;
    private readonly StreamReader output;
    private readonly Dictionary<string, TaskCompletionSource<string>> turns = new();
    private readonly Task readLoop;

    public event Action<string>? LogReceived;

    public event Action<JsonObject>? DeviceRequested;

    public SidecarClient()
    {
        var lib = Environment.GetEnvironmentVariable("HOPA_SIDECAR_LIB")
            ?? Path.GetFullPath(Path.Combine(
                AppContext.BaseDirectory,
                "..", "..", "..", "..",
                "sidecar", "build", "install", "hopa-windows-sidecar", "lib"));
        if (!Directory.Exists(lib))
        {
            throw new InvalidOperationException(
                $"sidecar library not found at {lib}; run gradlew -p apps/windows/sidecar installDist");
        }

        var javaHome = Environment.GetEnvironmentVariable("JAVA_HOME");
        var java = string.IsNullOrWhiteSpace(javaHome)
            ? "java"
            : Path.Combine(javaHome, "bin", "java.exe");
        var start = new ProcessStartInfo(java)
        {
            Arguments = $"-cp \"{lib}\\*\" com.hopa.sidecar.MainKt",
            RedirectStandardInput = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true,
            StandardOutputEncoding = System.Text.Encoding.UTF8,
            StandardErrorEncoding = System.Text.Encoding.UTF8,
        };
        process = Process.Start(start)
            ?? throw new InvalidOperationException("java did not start");
        input = process.StandardInput;
        output = process.StandardOutput;
        readLoop = Task.Run(ReadLoopAsync);
        _ = Task.Run(() =>
        {
            string? line;
            while ((line = process.StandardError.ReadLine()) != null)
            {
                LogReceived?.Invoke(line);
            }
        });
    }

    public async Task<string> StartTurnAsync(string goal)
    {
        var id = $"g-{Guid.NewGuid():N}";
        var completion = new TaskCompletionSource<string>(TaskCreationOptions.RunContinuationsAsynchronously);
        turns[id] = completion;
        Send(new JsonObject
        {
            ["type"] = "turn.start",
            ["id"] = id,
            ["goal"] = goal,
        });
        var finished = await Task.WhenAny(completion.Task, Task.Delay(TimeSpan.FromSeconds(60)));
        if (finished != completion.Task)
        {
            throw new TimeoutException("the sidecar did not answer in 60 s");
        }

        return await completion.Task;
    }

    public void SendDeviceResult(string id, bool ok, string? error = null)
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

        Send(message);
    }

    private void Send(JsonObject message)
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
                case "turn.end":
                    var id = message["id"]?.GetValue<string>();
                    if (id != null && turns.Remove(id, out var completion))
                    {
                        completion.TrySetResult(message["answer"]?.GetValue<string>() ?? "");
                    }

                    break;
            }
        }
    }

    public async ValueTask DisposeAsync()
    {
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

        await readLoop.WaitAsync(TimeSpan.FromSeconds(2)).ConfigureAwait(false);
        process.Dispose();
    }
}
