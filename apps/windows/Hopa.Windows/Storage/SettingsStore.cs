using System.IO;
using System.Text.Json;

namespace Hopa.Windows.Storage;

/// <summary>settings.json in %LOCALAPPDATA%\HOPA, or an explicit path; secrets stay out of it.</summary>
public sealed class SettingsStore
{
    private static readonly JsonSerializerOptions Options = new() { WriteIndented = true };

    private readonly string configPath;

    public SettingsStore() : this(DefaultPath())
    {
    }

    /// <summary>A store at an explicit path, for tests and the settings check.</summary>
    public SettingsStore(string path)
    {
        configPath = path;
    }

    public string FilePath => configPath;

    private static string DefaultPath() => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "HOPA",
        "settings.json");

    public AppSettings Load()
    {
        if (!File.Exists(configPath))
        {
            return new AppSettings();
        }

        return JsonSerializer.Deserialize<AppSettings>(File.ReadAllText(configPath)) ?? new AppSettings();
    }

    public void Save(AppSettings settings)
    {
        var directory = Path.GetDirectoryName(configPath);
        if (!string.IsNullOrEmpty(directory))
        {
            Directory.CreateDirectory(directory);
        }

        File.WriteAllText(configPath, JsonSerializer.Serialize(settings, Options));
    }
}
