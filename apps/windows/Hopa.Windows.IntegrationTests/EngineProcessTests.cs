using System.Diagnostics;
using System.IO;
using System.Text.Json.Nodes;
using Hopa.Windows.Integrations.Engine;
using Xunit;

namespace Hopa.Windows.IntegrationTests;

/// <summary>
/// The transport over a real child process: bytes, stdin/stdout and the reply
/// by id, not a fake reader.
/// </summary>
public sealed class EngineProcessTests
{
    [Fact]
    public async Task ARequestTravelsThroughARealProcessAndComesBack()
    {
        var configuration = new DirectoryInfo(AppContext.BaseDirectory).Parent!.Name;
        var host = Path.GetFullPath(Path.Combine(
            AppContext.BaseDirectory,
            "..", "..", "..", "..",
            "Hopa.Windows.FakeEngine", "bin", configuration, "net10.0",
            "Hopa.Windows.FakeEngine.dll"));
        Assert.True(File.Exists(host), $"the fake engine was not built at {host}");

        var start = new ProcessStartInfo("dotnet")
        {
            Arguments = $"\"{host}\"",
            RedirectStandardInput = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true,
        };

        using var process = Process.Start(start) ?? throw new InvalidOperationException("the fake engine did not start");
        var transport = new EngineTransport(process.StandardInput, process.StandardOutput);
        transport.Start();
        try
        {
            var response = await transport.RequestAsync(
                "turn.start",
                new JsonObject { ["goal"] = "say hello" },
                TimeSpan.FromSeconds(10));

            Assert.Equal("hello", response["answer"]!.GetValue<string>());
            Assert.Equal("c1", response["conversationId"]!.GetValue<string>());
            Assert.Equal("turn.start", response["type"]!.GetValue<string>());
        }
        finally
        {
            if (!process.HasExited)
            {
                transport.Send(new JsonObject { ["type"] = "shutdown" });
            }

            if (!process.WaitForExit(3000))
            {
                process.Kill(true);
                process.WaitForExit(3000);
            }
        }
    }
}
