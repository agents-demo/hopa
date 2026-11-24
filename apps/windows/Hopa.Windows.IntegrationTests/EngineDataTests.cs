using Hopa.Windows.Integrations.Engine;
using Xunit;

namespace Hopa.Windows.IntegrationTests;

/// <summary>Memory and skills over the real child process, not a fake reader.</summary>
public sealed class EngineDataTests
{
    [Fact]
    public async Task MemoryRoundTripsThroughTheEngine()
    {
        await using var host = FakeEngineProcess.Start();
        await using var client = new EngineHostClient(host.Transport);

        Assert.Empty(await client.ListMemoryAsync());

        var added = await client.AddMemoryAsync("the car is blue");
        Assert.Equal(new[] { "the car is blue" }, added);

        var reloaded = await client.ListMemoryAsync();
        Assert.Equal(new[] { "the car is blue" }, reloaded);

        var deleted = await client.DeleteMemoryAsync("the car is blue");
        Assert.Empty(deleted);

        var cleared = await client.ClearMemoryAsync();
        Assert.Empty(cleared);
    }

    [Fact]
    public async Task SkillsRoundTripThroughTheEngine()
    {
        await using var host = FakeEngineProcess.Start();
        await using var client = new EngineHostClient(host.Transport);

        Assert.Empty(await client.ListSkillsAsync());

        var added = await client.AddSkillAsync("open mail", "launch the mail app");
        Assert.Equal(new[] { new Skill("open mail", "launch the mail app") }, added);

        var deleted = await client.DeleteSkillAsync("open mail");
        Assert.Empty(deleted);

        var cleared = await client.ClearSkillsAsync();
        Assert.Empty(cleared);
    }

    [Fact]
    public async Task HistoryAndUsageComeFromTheRecordStore()
    {
        await using var host = FakeEngineProcess.Start();
        await using var client = new EngineHostClient(host.Transport);

        var history = await client.ListHistoryAsync();
        var entry = Assert.Single(history);
        Assert.Equal("Say hello", entry.Title);
        Assert.Equal(2, entry.Steps);
        Assert.Equal(1, entry.Executed);
        Assert.Equal(1, entry.Failed);

        var usage = await client.UsageAsync();
        Assert.Equal(2, usage.Total);
        Assert.Equal(1, usage.Executed);
        Assert.Equal(1, usage.Failed);
        Assert.Equal(2, usage.TopActions.Count);
        Assert.Equal("ui.tap", usage.TopActions[0].Kind);
    }

    [Fact]
    public async Task RecipesListAndDelete()
    {
        await using var host = FakeEngineProcess.Start();
        await using var client = new EngineHostClient(host.Transport);

        var recipes = await client.ListRecipesAsync();
        var recipe = Assert.Single(recipes);
        Assert.Equal("open mail", recipe.Goal);
        Assert.True(recipe.Replayable);

        var deleted = await client.DeleteRecipeAsync("open mail");
        Assert.Empty(deleted);
    }

    [Fact]
    public async Task ProfilesListAndSelect()
    {
        await using var host = FakeEngineProcess.Start();
        await using var client = new EngineHostClient(host.Transport);

        var (selected, profiles) = await client.ListProfilesAsync();
        Assert.Equal("everyday", selected);
        Assert.Equal(5, profiles.Count);
        Assert.Contains(profiles, profile => profile.Key == "power");

        var (changed, _) = await client.SelectProfileAsync("power");
        Assert.Equal("power", changed);

        var (reloaded, _) = await client.ListProfilesAsync();
        Assert.Equal("power", reloaded);

        await Assert.ThrowsAsync<InvalidOperationException>(() => client.SelectProfileAsync("nope"));
    }

    [Fact]
    public async Task CapabilitiesReflectTheLiveState()
    {
        await using var host = FakeEngineProcess.Start();
        await using var client = new EngineHostClient(host.Transport);

        var summary = await client.CapabilitiesAsync();
        Assert.Equal("windows", summary.Platform);
        Assert.Equal("everyday", summary.Profile);
        Assert.False(summary.ModelReady);
        Assert.Equal(2, summary.WindowsApps);
        Assert.Equal(1, summary.Runs);
    }

    [Fact]
    public async Task AMalformedMemoryAddIsAnError()
    {
        await using var host = FakeEngineProcess.Start();
        await using var client = new EngineHostClient(host.Transport);

        var error = await Assert.ThrowsAsync<InvalidOperationException>(() => client.AddMemoryAsync(""));
        Assert.Contains("text is empty", error.Message);
    }
}
