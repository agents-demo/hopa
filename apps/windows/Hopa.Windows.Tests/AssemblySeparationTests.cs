using Hopa.Windows.Ui.Shell;
using Xunit;

namespace Hopa.Windows.Tests;

/// <summary>The release exe must not carry the developer gates or screenshots.</summary>
public sealed class AssemblySeparationTests
{
    [Fact]
    public void TheProductAssemblyHasNoDeveloperChecks()
    {
        var assembly = typeof(MainWindow).Assembly;

        Assert.Null(assembly.GetType("Hopa.Windows.Checks.ObservationCheck"));
        Assert.Null(assembly.GetType("Hopa.Windows.Checks.DevicePortCheck"));
        Assert.Null(assembly.GetType("Hopa.Windows.Checks.IntentCheck"));
        Assert.Null(assembly.GetType("Hopa.Windows.Checks.SettingsCheck"));

        Assert.Null(typeof(MainWindow).GetMethod("W4Check"));
        Assert.Null(typeof(MainWindow).GetMethod("DraftCheckAsync"));
        Assert.Null(typeof(MainWindow).GetMethod("ShotChat"));
        Assert.Null(typeof(MainWindow).GetMethod("KeyboardCheck"));
        Assert.Null(typeof(MainWindow).GetMethod("FrameShot"));
        Assert.Null(typeof(MainWindow).GetMethod("PcCheckAsync"));
    }

    [Fact]
    public void TheProductKeepsTheTwoScriptModes()
    {
        Assert.NotNull(typeof(MainWindow).GetMethod("RunTurnAsync"));
        Assert.NotNull(typeof(MainWindow).GetMethod("ListAsync"));
    }
}
