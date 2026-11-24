using System.Text.Json.Nodes;
using Hopa.Windows.Ui.Chat;
using Xunit;

namespace Hopa.Windows.Tests;

/// <summary>A run step is named for the action and states what the gate actually did.</summary>
public sealed class RunStepRowTests
{
    [Fact]
    public void FromNamesTheActionAndTheResult()
    {
        var row = RunStepRow.From(new JsonObject
        {
            ["step"] = 2,
            ["action"] = new JsonObject { ["kind"] = "ui.type" },
            ["executed"] = true,
            ["verified"] = true,
        });

        Assert.Equal("2", row.Number);
        Assert.Equal("Type", row.Verb);
        Assert.Equal("verified", row.Detail);
    }

    [Fact]
    public void ARefusalIsSaidAsARefusal()
    {
        var row = RunStepRow.From(new JsonObject
        {
            ["step"] = 1,
            ["action"] = new JsonObject { ["kind"] = "ui.tap" },
            ["approved"] = false,
        });

        Assert.Equal("Tap", row.Verb);
        Assert.Equal("refused by the gate", row.Detail);
    }

    [Fact]
    public void LinesKeepTheGateAndTheHashPrefix()
    {
        var steps = new JsonArray(new JsonObject
        {
            ["step"] = 1,
            ["action"] = new JsonObject { ["kind"] = "ui.launch" },
            ["classification"] = "read",
            ["approved"] = true,
            ["executed"] = true,
            ["verified"] = true,
            ["error"] = "",
            ["hash"] = "abcdef1234567890",
        });

        var line = Assert.Single(RunStepRow.Lines(steps));
        Assert.Contains("#1 ui.launch [read]", line);
        Assert.Contains("approved=True", line);
        Assert.Contains("hash=abcdef1234", line);
    }
}
