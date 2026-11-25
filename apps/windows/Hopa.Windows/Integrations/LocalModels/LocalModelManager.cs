using System.IO;
using System.IO.Compression;
using System.Net.Http;
using System.Security.Cryptography;

namespace Hopa.Windows.Integrations.LocalModels;

/// <summary>One curated local model; the URL and digest are the licence to run it.</summary>
public sealed record LocalModelSpec(
    string Id,
    string Name,
    string Url,
    string Sha256,
    long Bytes,
    int ContextTokens,
    bool Thinking,
    string License,
    string LicenseUrl);

/// <summary>
/// Downloads the llama.cpp CPU runtime and the small GGUF model, or imports a
/// person's own GGUF. Model files stay outside the MSI.
/// </summary>
public sealed class LocalModelManager
{
    public const string RuntimeVersion = "b12721";
    private const string RuntimeUrl =
        "https://github.com/ggml-org/llama.cpp/releases/download/b12721/llama-b12721-bin-win-cpu-x64.zip";
    private const string RuntimeSha256 =
        "BEF517FBED4BC174C9668BC153554726FC3094635AF475BF57F2956FC8003046";

    public static readonly LocalModelSpec Default = new(
        Id: "qwen3-1.7b",
        Name: "Qwen3 1.7B",
        Url: "https://huggingface.co/ggml-org/Qwen3-1.7B-GGUF/resolve/main/Qwen3-1.7B-Q4_K_M.gguf",
        Sha256: "D2387CA2DBFEE2FFABCE7120D3770DADCA0B293052BC2F0E138FDC940D9BC7B5",
        Bytes: 1_282_439_264,
        ContextTokens: 32_000,
        // Qwen3 spends the answer budget on thinking; a turn needs the decision.
        Thinking: true,
        License: "Apache-2.0",
        LicenseUrl: "https://www.apache.org/licenses/LICENSE-2.0");

    /// <summary>
    /// An imported GGUF has no catalogue entry, so its context is the safe
    /// minimum the Android catalogue gives a small model, not a guess.
    /// </summary>
    private const int ImportedContextTokens = 8_192;

    private static readonly HttpClient Http = new() { Timeout = TimeSpan.FromMinutes(10) };

    private readonly string root;

    public LocalModelManager(string? root = null)
    {
        this.root = root ?? Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "HOPA");
    }

    public string ModelsDirectory => Path.Combine(root, "models");
    public string RuntimeDirectory => Path.Combine(root, "local", $"llama-{RuntimeVersion}");
    public string ServerPath => Path.Combine(RuntimeDirectory, "llama-server.exe");
    public string DefaultModelPath => Path.Combine(ModelsDirectory, $"{Default.Id}.gguf");

    public bool IsRuntimeInstalled => File.Exists(ServerPath);

    public bool IsModelInstalled(string? path) =>
        File.Exists(string.IsNullOrWhiteSpace(path) ? DefaultModelPath : path);

    private bool IsDefault(string? path) =>
        string.IsNullOrWhiteSpace(path) ||
        string.Equals(path, DefaultModelPath, StringComparison.OrdinalIgnoreCase);

    /// <summary>The curated default has its catalogue context; an import gets the minimum.</summary>
    public int ContextTokensFor(string? path) =>
        IsDefault(path) ? Default.ContextTokens : ImportedContextTokens;

    /// <summary>Qwen3 must not spend the answer budget on a thinking block.</summary>
    public bool DisableThinking(string? path) => IsDefault(path) && Default.Thinking;

    public string Status(string? modelPath)
    {
        var installed = IsModelInstalled(modelPath);
        var runtime = IsRuntimeInstalled;
        return (runtime, installed) switch
        {
            (true, true) => "Local model ready.",
            (false, true) => "Model is installed; the llama.cpp runtime is missing.",
            (true, false) => "Runtime is installed; install or import a GGUF model.",
            _ => "Local model is not installed. Install it here; it is downloaded separately from the MSI.",
        };
    }

    /// <summary>Installs the runtime and the default model, returning the model path.</summary>
    public async Task<string> InstallAsync(
        string? modelPath,
        IProgress<string>? progress = null,
        CancellationToken cancellationToken = default)
    {
        Directory.CreateDirectory(ModelsDirectory);
        Directory.CreateDirectory(RuntimeDirectory);

        if (!IsRuntimeInstalled)
        {
            progress?.Report("Downloading the llama.cpp CPU runtime...");
            var zip = Path.Combine(RuntimeDirectory, "llama.zip");
            await DownloadAsync(RuntimeUrl, zip, RuntimeSha256, progress, cancellationToken);
            progress?.Report("Extracting the llama.cpp runtime...");
            ZipFile.ExtractToDirectory(zip, RuntimeDirectory, overwriteFiles: true);
            File.Delete(zip);
            if (!IsRuntimeInstalled)
            {
                throw new InvalidOperationException("The llama.cpp archive did not contain llama-server.exe.");
            }
        }

        var target = string.IsNullOrWhiteSpace(modelPath) ? DefaultModelPath : modelPath;
        if (!File.Exists(target))
        {
            progress?.Report($"Downloading {Default.Name} ({Default.Bytes / 1_000_000} MB)...");
            await DownloadAsync(Default.Url, target, Default.Sha256, progress, cancellationToken);
        }

        return target;
    }

    /// <summary>Copies a person's .gguf into the model directory.</summary>
    public string Import(string source)
    {
        var file = new FileInfo(source);
        if (!file.Exists)
        {
            throw new InvalidOperationException("The selected model file does not exist.");
        }

        using (var stream = file.OpenRead())
        {
            var magic = new byte[4];
            if (stream.Read(magic, 0, magic.Length) != magic.Length ||
                System.Text.Encoding.ASCII.GetString(magic) != "GGUF")
            {
                throw new InvalidOperationException("Choose a .gguf model file.");
            }
        }

        Directory.CreateDirectory(ModelsDirectory);
        var target = Path.Combine(ModelsDirectory, file.Name);
        if (!string.Equals(file.FullName, target, StringComparison.OrdinalIgnoreCase))
        {
            File.Copy(file.FullName, target, overwrite: true);
        }

        return target;
    }

    public void DeleteModel(string? path)
    {
        var target = string.IsNullOrWhiteSpace(path) ? DefaultModelPath : path;
        if (File.Exists(target) &&
            target.StartsWith(ModelsDirectory, StringComparison.OrdinalIgnoreCase))
        {
            File.Delete(target);
        }
    }

    private static async Task DownloadAsync(
        string url,
        string target,
        string sha256,
        IProgress<string>? progress,
        CancellationToken cancellationToken)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(target)!);
        var part = target + ".part";
        using (var response = await Http.GetAsync(
                   url,
                   HttpCompletionOption.ResponseHeadersRead,
                   cancellationToken))
        {
            response.EnsureSuccessStatusCode();
            await using var input = await response.Content.ReadAsStreamAsync(cancellationToken);
            await using var output = File.Create(part);
            await input.CopyToAsync(output, cancellationToken);
        }

        using var downloaded = File.OpenRead(part);
        var actual = Convert.ToHexString(SHA256.HashData(downloaded));
        if (!actual.Equals(sha256, StringComparison.OrdinalIgnoreCase))
        {
            File.Delete(part);
            throw new InvalidOperationException(
                $"The downloaded file failed its SHA-256 check ({actual}).");
        }

        File.Move(part, target, overwrite: true);
        progress?.Report($"Downloaded {Path.GetFileName(target)}.");
    }
}
