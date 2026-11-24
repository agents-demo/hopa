using System.Diagnostics;
using System.IO;

namespace Hopa.Windows.Integrations.Engine;

/// <summary>The process and pipes of the Kotlin engine host, started once per window.</summary>
internal sealed record EngineHostProcess(Process Process, StreamWriter Input, StreamReader Output)
{
    /// <summary>
    /// Finds the installed library and Java, then starts the engine host. The
    /// library is next to the app when packaged, and in the sidecar build tree
    /// when run from a checkout.
    /// </summary>
    public static EngineHostProcess Start()
    {
        var lib = Environment.GetEnvironmentVariable("HOPA_SIDECAR_LIB");
        if (string.IsNullOrEmpty(lib))
        {
            var installed = Path.Combine(AppContext.BaseDirectory, "sidecar", "lib");
            lib = Directory.Exists(installed)
                ? installed
                : Path.GetFullPath(Path.Combine(
                    AppContext.BaseDirectory,
                    "..", "..", "..", "..",
                    "sidecar", "build", "install", "hopa-windows-sidecar", "lib"));
        }

        if (!Directory.Exists(lib))
        {
            throw new InvalidOperationException(
                $"sidecar library not found at {lib}; run gradlew -p apps/windows/sidecar installDist");
        }

        var nextToApp = Path.Combine(AppContext.BaseDirectory, "runtime", "bin", "java.exe");
        var sibling = Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "runtime", "bin", "java.exe"));
        var javaHome = Environment.GetEnvironmentVariable("JAVA_HOME");
        var java = File.Exists(nextToApp)
            ? nextToApp
            : File.Exists(sibling)
                ? sibling
                : string.IsNullOrWhiteSpace(javaHome)
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
        var process = Process.Start(start)
            ?? throw new InvalidOperationException("java did not start");
        return new EngineHostProcess(process, process.StandardInput, process.StandardOutput);
    }
}
