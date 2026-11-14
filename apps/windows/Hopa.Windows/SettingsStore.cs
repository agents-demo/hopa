using System.IO;
using System.Text.Json;

namespace Hopa.Windows;

/// <summary>settings.json in %LOCALAPPDATA%\HOPA; secrets stay out of it.</summary>
public sealed class SettingsStore
{
    private static readonly JsonSerializerOptions Options = new() { WriteIndented = true };

    private readonly string configPath;

    public SettingsStore()
    {
        configPath = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "HOPA",
            "settings.json");
    }

    public string FilePath => configPath;

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
