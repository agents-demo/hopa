using System.IO;
using Hopa.Windows.Storage;
using Xunit;

namespace Hopa.Windows.Tests;

/// <summary>The settings file is a plain JSON round-trip at an explicit path.</summary>
public sealed class SettingsStoreTests
{
    [Fact]
    public void AMissingFileLoadsTheDefaults()
    {
        var path = TempPath();
        try
        {
            var loaded = new SettingsStore(path).Load();

            Assert.Equal("", loaded.BridgeUrl);
            Assert.Equal("openai", loaded.ModelProvider);
            Assert.Equal("auto", loaded.StepSource);
            Assert.Equal(1140, loaded.WindowWidth);
        }
        finally
        {
            Clean(path);
        }
    }

    [Fact]
    public void SaveThenLoadKeepsEveryValue()
    {
        var path = TempPath();
        try
        {
            var store = new SettingsStore(path);
            store.Save(new AppSettings
            {
                BridgeUrl = "http://127.0.0.1:8901",
                UseBridge = true,
                ModelProvider = "lan",
                ModelBaseUrl = "http://127.0.0.1:11434/v1",
                ModelName = "llama",
                StepSource = "model",
                Tone = "brief",
                Profile = "power",
                ReplaySkills = false,
                PlanFirst = true,
                InstantCommands = false,
                Vision = true,
                WindowLeft = 10,
                WindowTop = 20,
                WindowWidth = 900,
                WindowHeight = 600,
                WindowMaximized = true,
            });

            var loaded = store.Load();

            Assert.Equal(path, store.FilePath);
            Assert.Equal("http://127.0.0.1:8901", loaded.BridgeUrl);
            Assert.True(loaded.UseBridge);
            Assert.Equal("lan", loaded.ModelProvider);
            Assert.Equal("llama", loaded.ModelName);
            Assert.Equal("model", loaded.StepSource);
            Assert.Equal("brief", loaded.Tone);
            Assert.Equal("power", loaded.Profile);
            Assert.False(loaded.ReplaySkills);
            Assert.True(loaded.PlanFirst);
            Assert.False(loaded.InstantCommands);
            Assert.True(loaded.Vision);
            Assert.Equal(900, loaded.WindowWidth);
            Assert.True(loaded.WindowMaximized);
        }
        finally
        {
            Clean(path);
        }
    }

    [Fact]
    public void SaveCreatesTheDirectory()
    {
        var path = TempPath();
        try
        {
            new SettingsStore(path).Save(new AppSettings());

            Assert.True(File.Exists(path));
        }
        finally
        {
            Clean(path);
        }
    }

    private static string TempPath() =>
        Path.Combine(Path.GetTempPath(), "hopa-settings-tests", $"{Guid.NewGuid():N}.json");

    private static void Clean(string path)
    {
        if (File.Exists(path))
        {
            File.Delete(path);
        }

        var directory = Path.GetDirectoryName(path);
        if (directory != null && Directory.Exists(directory) && !Directory.EnumerateFileSystemEntries(directory).Any())
        {
            Directory.Delete(directory);
        }
    }
}
