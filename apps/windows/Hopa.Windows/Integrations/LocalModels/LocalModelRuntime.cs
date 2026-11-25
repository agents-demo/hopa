using System.Collections.Concurrent;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Net.Sockets;

namespace Hopa.Windows.Integrations.LocalModels;

/// <summary>
/// Runs llama.cpp's OpenAI-compatible server on loopback. The sidecar sees it as
/// a LAN endpoint; nothing leaves the machine.
/// </summary>
public sealed class LocalModelRuntime : IDisposable
{
    private static readonly HttpClient Http = new() { Timeout = TimeSpan.FromSeconds(2) };
    private readonly LocalModelManager manager;
    private readonly ConcurrentQueue<string> log = new();
    private Process? process;
    private string? loadedModel;

    public LocalModelRuntime(LocalModelManager? manager = null)
    {
        this.manager = manager ?? new LocalModelManager();
    }

    public string? Endpoint { get; private set; }

    public bool IsRunning => process is { HasExited: false } && Endpoint != null;

    public async Task<string> StartAsync(
        string? modelPath,
        CancellationToken cancellationToken = default)
    {
        var model = string.IsNullOrWhiteSpace(modelPath) ? manager.DefaultModelPath : modelPath;
        if (IsRunning && string.Equals(loadedModel, model, StringComparison.OrdinalIgnoreCase))
        {
            return Endpoint!;
        }

        Stop();
        if (!manager.IsRuntimeInstalled)
        {
            throw new InvalidOperationException(
                "The local runtime is not installed. Open Settings, Answers, and install the local model.");
        }

        if (!File.Exists(model))
        {
            throw new InvalidOperationException(
                "The local model file is missing. Install or import it in Settings, Answers.");
        }

        var port = FreePort();
        var contextTokens = manager.ContextTokensFor(model);
        var start = new ProcessStartInfo(manager.ServerPath)
        {
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            WorkingDirectory = manager.RuntimeDirectory,
        };
        var arguments = new List<string>
        {
            "-m", model,
            "--host", "127.0.0.1",
            "--port", port.ToString(),
            "-c", contextTokens.ToString(),
            "-np", "1",
            "-n", "256",
            "--no-webui",
        };
        if (manager.DisableThinking(model))
        {
            // Qwen3 would otherwise write a thinking block instead of a decision.
            arguments.Add("--reasoning-budget");
            arguments.Add("0");
        }

        foreach (var argument in arguments)
        {
            start.ArgumentList.Add(argument);
        }

        process = Process.Start(start)
            ?? throw new InvalidOperationException("llama-server did not start.");
        process.OutputDataReceived += (_, args) => Keep(args.Data);
        process.ErrorDataReceived += (_, args) => Keep(args.Data);
        process.BeginOutputReadLine();
        process.BeginErrorReadLine();

        var endpoint = $"http://127.0.0.1:{port}/v1";
        var health = $"http://127.0.0.1:{port}/health";
        var deadline = DateTime.UtcNow.AddSeconds(60);
        while (DateTime.UtcNow < deadline)
        {
            cancellationToken.ThrowIfCancellationRequested();
            if (process.HasExited)
            {
                break;
            }

            try
            {
                using var response = await Http.GetAsync(health, cancellationToken);
                if (response.IsSuccessStatusCode)
                {
                    Endpoint = endpoint;
                    loadedModel = model;
                    return endpoint;
                }
            }
            catch (HttpRequestException)
            {
                // Not listening yet.
            }
            catch (TaskCanceledException) when (!cancellationToken.IsCancellationRequested)
            {
                // The short probe timed out; try again.
            }

            await Task.Delay(500, cancellationToken);
        }

        var tail = string.Join(Environment.NewLine, log.TakeLast(8));
        Stop();
        throw new InvalidOperationException(
            "The local model did not start." + (tail.Length > 0 ? Environment.NewLine + tail : ""));
    }

    public void Stop()
    {
        Endpoint = null;
        loadedModel = null;
        if (process == null)
        {
            return;
        }

        try
        {
            if (!process.HasExited)
            {
                process.Kill(entireProcessTree: true);
                process.WaitForExit(3000);
            }
        }
        catch (Exception)
        {
            // Already gone.
        }
        finally
        {
            process.Dispose();
            process = null;
            log.Clear();
        }
    }

    public void Dispose() => Stop();

    private void Keep(string? line)
    {
        if (string.IsNullOrWhiteSpace(line))
        {
            return;
        }

        log.Enqueue(line);
        while (log.Count > 20)
        {
            log.TryDequeue(out _);
        }
    }

    private static int FreePort()
    {
        var listener = new TcpListener(IPAddress.Loopback, 0);
        listener.Start();
        var port = ((IPEndPoint)listener.LocalEndpoint).Port;
        listener.Stop();
        return port;
    }
}
