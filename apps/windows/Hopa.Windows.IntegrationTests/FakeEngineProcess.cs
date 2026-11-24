using System.Diagnostics;
using System.IO;
using System.Text.Json.Nodes;
using Hopa.Windows.Integrations.Engine;

namespace Hopa.Windows.IntegrationTests;

/// <summary>The fake engine process, owned by the integration test.</summary>
internal sealed class FakeEngineProcess : IAsyncDisposable
{
    private readonly Process process;

    private FakeEngineProcess(Process process, EngineTransport transport)
    {
        this.process = process;
        Transport = transport;
    }

    public EngineTransport Transport { get; }

    public static FakeEngineProcess Start()
    {
        var configuration = new DirectoryInfo(AppContext.BaseDirectory).Parent!.Name;
        var host = Path.GetFullPath(Path.Combine(
            AppContext.BaseDirectory,
            "..", "..", "..", "..",
            "Hopa.Windows.FakeEngine", "bin", configuration, "net8.0",
            "Hopa.Windows.FakeEngine.dll"));
        if (!File.Exists(host))
        {
            throw new InvalidOperationException($"the fake engine was not built at {host}");
        }

        var start = new ProcessStartInfo("dotnet")
        {
            Arguments = $"\"{host}\"",
            RedirectStandardInput = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true,
        };

        var process = Process.Start(start) ?? throw new InvalidOperationException("the fake engine did not start");
        var transport = new EngineTransport(process.StandardInput, process.StandardOutput);
        transport.Start();
        return new FakeEngineProcess(process, transport);
    }

    public async ValueTask DisposeAsync()
    {
        if (!process.HasExited)
        {
            Transport.Send(new JsonObject { ["type"] = "shutdown" });
        }

        if (!process.WaitForExit(3000))
        {
            process.Kill(true);
            process.WaitForExit(3000);
        }

        process.Dispose();
        await Task.CompletedTask;
    }
}
