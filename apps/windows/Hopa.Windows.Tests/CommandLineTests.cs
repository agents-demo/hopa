using Hopa.Windows.Cli;
using Xunit;

namespace Hopa.Windows.Tests;

/// <summary>The flags are an external contract: docs and tools depend on every spelling.</summary>
public sealed class CommandLineTests
{
    [Theory]
    [InlineData("--w3-check", RunMode.ObservationCheck)]
    [InlineData("--p2-check", RunMode.DevicePortCheck)]
    [InlineData("--p3-check", RunMode.IntentCheck)]
    [InlineData("--matrix-check", RunMode.AppMatrixCheck)]
    [InlineData("--settings-check", RunMode.SettingsCheck)]
    [InlineData("--draft-check", RunMode.DraftCheck)]
    [InlineData("--cancel-check", RunMode.CancelCheck)]
    [InlineData("--history-check", RunMode.HistoryCheck)]
    [InlineData("--pc-check", RunMode.PcCheck)]
    [InlineData("--shot-chat", RunMode.ChatShot)]
    [InlineData("--keyboard-check", RunMode.KeyboardCheck)]
    [InlineData("--shot-components", RunMode.ComponentShot)]
    [InlineData("--shot-frame", RunMode.FrameShot)]
    [InlineData("--w4-check", RunMode.WindowCheck)]
    [InlineData("--shot-settings", RunMode.SettingsShot)]
    [InlineData("--shot-settings-pages", RunMode.SettingsPagesShot)]
    [InlineData("--web-check", RunMode.WebCheck)]
    [InlineData("--p5-check", RunMode.P5Check)]
    public void OnePathCheckMapsToItsMode(string flag, RunMode mode)
    {
        var command = CommandLine.Parse(new[] { flag, "out.txt" });

        Assert.NotNull(command);
        Assert.Equal(mode, command!.Mode);
        Assert.Equal("out.txt", command.Arg(0));
    }

    [Fact]
    public void P2WaitDefaultsToTwelveSecondsAndLock()
    {
        var command = CommandLine.Parse(new[] { "--p2-wait", "out.txt" });

        Assert.Equal(RunMode.DevicePortWait, command!.Mode);
        Assert.Equal(12, command.Int(1, 12));
        Assert.Equal("lock", command.ArgOr(2, "lock"));
    }

    [Fact]
    public void P2WaitReadsSecondsAndMode()
    {
        var command = CommandLine.Parse(new[] { "--p2-wait", "out.txt", "30", "logon" });

        Assert.Equal(30, command!.Int(1, 12));
        Assert.Equal("logon", command.ArgOr(2, "lock"));
    }

    [Fact]
    public void TurnCarriesTheGoalAndTheOptionalPairs()
    {
        var command = CommandLine.Parse(new[]
        {
            "--turn", "pay the bill", "--out", "log.txt", "--shot", "shot.png", "--approval", "allow",
        });

        Assert.Equal(RunMode.Turn, command!.Mode);
        Assert.Equal("pay the bill", command.Arg(0));
        Assert.Equal("log.txt", command.ArgOrNull(1));
        Assert.Equal("shot.png", command.ArgOrNull(2));
        Assert.Equal("allow", command.ArgOrNull(3));
    }

    [Fact]
    public void TurnWithoutPairsLeavesThemEmpty()
    {
        var command = CommandLine.Parse(new[] { "--turn", "hello" });

        Assert.Null(command!.ArgOrNull(1));
        Assert.Null(command.ArgOrNull(2));
        Assert.Null(command.ArgOrNull(3));
    }

    [Fact]
    public void ListReadsTheOptionalOutPath()
    {
        var command = CommandLine.Parse(new[] { "--list", "--out", "list.txt" });

        Assert.Equal(RunMode.ConversationList, command!.Mode);
        Assert.Equal("list.txt", command.ArgOrNull(0));
        Assert.Null(CommandLine.Parse(new[] { "--list" })!.ArgOrNull(0));
    }

    [Fact]
    public void MultiOperandFlagsNeedTheirOperands()
    {
        Assert.Equal(RunMode.BridgeCheck, CommandLine.Parse(new[] { "--bridge-check", "u", "t", "p" })!.Mode);
        Assert.Equal(RunMode.AttachCheck, CommandLine.Parse(new[] { "--attach-check", "f", "p" })!.Mode);
        Assert.Equal(RunMode.Pair, CommandLine.Parse(new[] { "--pair", "u", "c", "p" })!.Mode);
        Assert.Equal(RunMode.StaleCheck, CommandLine.Parse(new[] { "--stale-check", "u", "p" })!.Mode);
        Assert.Null(CommandLine.Parse(new[] { "--bridge-check", "u", "t" }));
        Assert.Null(CommandLine.Parse(new[] { "--attach-check", "f" }));
        Assert.Null(CommandLine.Parse(new[] { "--pair", "u", "c" }));
        Assert.Null(CommandLine.Parse(new[] { "--stale-check", "u" }));
    }

    [Fact]
    public void UnknownOrEmptyFallsBackToTheWindow()
    {
        Assert.Null(CommandLine.Parse(Array.Empty<string>()));
        Assert.Null(CommandLine.Parse(new[] { "--nope", "x" }));
        Assert.Null(CommandLine.Parse(new[] { "--turn" }));
    }

    [Fact]
    public void VoiceCheckNeedsUrlAndPath()
    {
        var command = CommandLine.Parse(new[] { "--voice-check", "http://bridge", "out.txt" });

        Assert.Equal(RunMode.VoiceCheck, command!.Mode);
        Assert.Equal("http://bridge", command.Arg(0));
        Assert.Equal("out.txt", command.Arg(1));
        Assert.Null(CommandLine.Parse(new[] { "--voice-check", "http://bridge" }));
    }
}
