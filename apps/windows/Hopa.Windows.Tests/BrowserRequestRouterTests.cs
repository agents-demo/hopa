using System.Text.Json.Nodes;
using Hopa.Windows.Host;
using Hopa.Windows.Integrations.Browser;
using Xunit;

namespace Hopa.Windows.Tests;

/// <summary>A browser request becomes exactly one reply, even when it fails.</summary>
public sealed class BrowserRequestRouterTests
{
    [Fact]
    public async Task NavigateReturnsTheHostText()
    {
        var browser = new FakeBrowser { Text = "navigated to https://example.com/" };
        var results = new List<BrowserResult>();

        await new BrowserRequestRouter(browser, results.Add, _ => { })
            .HandleAsync(new JsonObject
            {
                ["id"] = "b1",
                ["op"] = "navigate",
                ["url"] = "https://example.com",
            });

        var result = Assert.Single(results);
        Assert.True(result.Ok);
        Assert.Equal("navigated to https://example.com/", result.Text);
        Assert.Equal("https://example.com", browser.LastUrl);
    }

    [Fact]
    public async Task ReadTypeAndClickReachTheController()
    {
        var browser = new FakeBrowser { Text = "page" };
        var results = new List<BrowserResult>();
        var router = new BrowserRequestRouter(browser, results.Add, _ => { });

        await router.HandleAsync(new JsonObject { ["id"] = "b1", ["op"] = "read" });
        await router.HandleAsync(new JsonObject
        {
            ["id"] = "b2",
            ["op"] = "type",
            ["text"] = "Michael",
            ["ref"] = "w2",
        });
        await router.HandleAsync(new JsonObject
        {
            ["id"] = "b3",
            ["op"] = "click",
            ["ref"] = "w3",
        });

        Assert.Equal("page", browser.LastRead);
        Assert.Equal("Michael", browser.LastText);
        Assert.Equal("w2", browser.LastReference);
        Assert.Equal("w3", browser.LastClick);
        Assert.All(results, result => Assert.True(result.Ok));
    }

    [Fact]
    public async Task AFailureIsReportedWithTheEngineId()
    {
        var browser = new FakeBrowser { Failure = new InvalidOperationException("stale ref w3") };
        var results = new List<BrowserResult>();

        await new BrowserRequestRouter(browser, results.Add, _ => { })
            .HandleAsync(new JsonObject { ["id"] = "b9", ["op"] = "click", ["ref"] = "w3" });

        var result = Assert.Single(results);
        Assert.False(result.Ok);
        Assert.Equal("b9", result.Id);
        Assert.Equal("stale ref w3", result.Error);
    }

    [Fact]
    public async Task AnUnknownOperationIsRefused()
    {
        var results = new List<BrowserResult>();

        await new BrowserRequestRouter(new FakeBrowser(), results.Add, _ => { })
            .HandleAsync(new JsonObject { ["id"] = "b1", ["op"] = "download" });

        Assert.False(Assert.Single(results).Ok);
    }

    private sealed class FakeBrowser : IBrowserController
    {
        public string Text { get; set; } = "done";

        public string LastUrl { get; private set; } = "";

        public string LastRead { get; private set; } = "";

        public string LastText { get; private set; } = "";

        public string? LastReference { get; private set; }

        public string LastClick { get; private set; } = "";

        public Exception? Failure { get; set; }

        public Task<string> NavigateAsync(string url)
        {
            ThrowIfNeeded();
            LastUrl = url;
            return Task.FromResult(Text);
        }

        public Task<string> ReadAsync()
        {
            ThrowIfNeeded();
            LastRead = Text;
            return Task.FromResult(Text);
        }

        public Task<string> ClickAsync(string reference)
        {
            ThrowIfNeeded();
            LastClick = reference;
            return Task.FromResult(Text);
        }

        public Task<string> TypeAsync(string text, string? reference)
        {
            ThrowIfNeeded();
            LastText = text;
            LastReference = reference;
            return Task.FromResult(Text);
        }

        private void ThrowIfNeeded()
        {
            if (Failure != null)
            {
                throw Failure;
            }
        }
    }
}
