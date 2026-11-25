using System.IO;
using System.Text;
using Hopa.Windows.Integrations.LocalModels;
using Xunit;

namespace Hopa.Windows.Tests;

/// <summary>The local-model store never writes outside its model directory.</summary>
public sealed class LocalModelManagerTests
{
    [Fact]
    public void ImportCopiesAGgufIntoTheModelDirectory()
    {
        var root = Directory.CreateTempSubdirectory("hopa-local-models");
        try
        {
            var source = Path.Combine(root.FullName, "tiny.gguf");
            File.WriteAllBytes(source, Encoding.ASCII.GetBytes("GGUF").Concat(new byte[64]).ToArray());
            var manager = new LocalModelManager(root.FullName);

            var imported = manager.Import(source);

            Assert.True(File.Exists(imported));
            Assert.StartsWith(manager.ModelsDirectory, imported, StringComparison.OrdinalIgnoreCase);
            Assert.True(manager.IsModelInstalled(imported));
            Assert.Contains("installed", manager.Status(imported), StringComparison.OrdinalIgnoreCase);
        }
        finally
        {
            root.Delete(recursive: true);
        }
    }

    [Fact]
    public void TheCuratedDefaultUsesItsCatalogueContextAndDisablesThinking()
    {
        var root = Directory.CreateTempSubdirectory("hopa-local-models-context");
        try
        {
            var manager = new LocalModelManager(root.FullName);

            Assert.Equal(32_000, manager.ContextTokensFor(""));
            Assert.Equal(32_000, manager.ContextTokensFor(manager.DefaultModelPath));
            Assert.True(manager.DisableThinking(manager.DefaultModelPath));
            Assert.Equal(
                8_192,
                manager.ContextTokensFor(Path.Combine(manager.ModelsDirectory, "mine.gguf")));
            Assert.False(manager.DisableThinking(Path.Combine(manager.ModelsDirectory, "mine.gguf")));
        }
        finally
        {
            root.Delete(recursive: true);
        }
    }

    [Fact]
    public void ImportRefusesANonGgufFile()
    {
        var root = Directory.CreateTempSubdirectory("hopa-local-models-bad");
        try
        {
            var source = Path.Combine(root.FullName, "not-a-model.bin");
            File.WriteAllText(source, "hello");
            var manager = new LocalModelManager(root.FullName);

            var error = Assert.Throws<InvalidOperationException>(() => manager.Import(source));

            Assert.Contains("gguf", error.Message, StringComparison.OrdinalIgnoreCase);
        }
        finally
        {
            root.Delete(recursive: true);
        }
    }

    [Fact]
    public void DeleteOnlyRemovesAModelInsideTheStore()
    {
        var root = Directory.CreateTempSubdirectory("hopa-local-models-delete");
        try
        {
            var manager = new LocalModelManager(root.FullName);
            var source = Path.Combine(root.FullName, "tiny.gguf");
            File.WriteAllBytes(source, Encoding.ASCII.GetBytes("GGUF").Concat(new byte[64]).ToArray());
            var imported = manager.Import(source);

            manager.DeleteModel(imported);

            Assert.False(File.Exists(imported));
            Assert.True(File.Exists(source));
        }
        finally
        {
            root.Delete(recursive: true);
        }
    }
}
