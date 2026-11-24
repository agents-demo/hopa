using System.Text.Json.Nodes;
using Hopa.Windows.Ui.Chat;
using Hopa.Windows.Ui.Panes;
using Xunit;

namespace Hopa.Windows.Tests;

/// <summary>The rail is a view of one turn, not a place that talks to the engine.</summary>
public sealed class RunRailViewModelTests
{
    [Fact]
    public void ATurnShowsItsStepsAndTheGateResult()
    {
        var model = new RunRailViewModel();
        var steps = new JsonArray(
            new JsonObject
            {
                ["step"] = 1,
                ["action"] = new JsonObject { ["kind"] = "ui.launch" },
                ["executed"] = true,
                ["verified"] = true,
            },
            new JsonObject
            {
                ["step"] = 2,
                ["action"] = new JsonObject { ["kind"] = "ui.type" },
                ["executed"] = true,
                ["verified"] = true,
            });

        model.ShowTurn(steps, chainOk: true, TimeSpan.FromSeconds(6.2), "open notepad");

        Assert.Equal("LAST RUN", model.Title);
        Assert.Equal("Succeeded", model.Status);
        Assert.Equal("2 steps", model.Facts);
        Assert.Equal(2, model.Steps.Count);
        Assert.Equal("Open app", model.Steps[0].Verb);
        Assert.Equal("Earlier: open notepad", model.Earlier);
        Assert.True(model.HasEarlier);
        Assert.True(model.HasMeasured);
        Assert.Equal("answered in 6.2 s", model.Measured);
    }

    [Fact]
    public void AnAnswerWithoutAStepSaysSo()
    {
        var model = new RunRailViewModel();

        model.ShowTurn(steps: null, chainOk: false, TimeSpan.FromSeconds(1.5), "what is the time");

        Assert.Equal("THIS ANSWER", model.Title);
        Assert.Equal("Answered", model.Status);
        Assert.Equal("no local record", model.Facts);
        Assert.Empty(model.Steps);
        Assert.True(model.HasEarlier);
    }

    [Fact]
    public void TheBridgeLineTracksTheSetting()
    {
        var model = new RunRailViewModel();

        model.ShowBridge(live: true);
        Assert.StartsWith("Bridge connected", model.BridgeText);

        model.ShowBridge(live: false);
        Assert.StartsWith("No bridge", model.BridgeText);
    }

    [Fact]
    public void TheMockKeepsTheW6Numbers()
    {
        var model = new RunRailViewModel();
        var step = new RunStepRow { Number = "1", Verb = "Open app", Detail = "Calculator" };

        model.ShowMock("Succeeded", "4 steps \u00B7 6.2 s", new[] { step });

        Assert.Equal("LAST RUN", model.Title);
        Assert.Equal("4 steps \u00B7 6.2 s", model.Facts);
        Assert.Single(model.Steps);
    }
}
