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
    public async Task AMalformedMemoryAddIsAnError()
    {
        await using var host = FakeEngineProcess.Start();
        await using var client = new EngineHostClient(host.Transport);

        var error = await Assert.ThrowsAsync<InvalidOperationException>(() => client.AddMemoryAsync(""));
        Assert.Contains("text is empty", error.Message);
    }
}
