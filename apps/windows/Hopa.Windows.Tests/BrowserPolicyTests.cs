using Hopa.Windows.Integrations.Browser;
using Xunit;

namespace Hopa.Windows.Tests;

/// <summary>The browser surface only accepts a web address; the rest is refused.</summary>
public sealed class BrowserPolicyTests
{
    [Theory]
    [InlineData("https://example.com", "https://example.com/")]
    [InlineData("http://127.0.0.1:8080/form", "http://127.0.0.1:8080/form")]
    public void WebAddressesPassThrough(string address, string expected)
    {
        Assert.Equal(expected, BrowserPolicy.Normalise(address));
    }

    [Fact]
    public void AMissingSchemeBecomesHttps()
    {
        Assert.Equal("https://example.com/", BrowserPolicy.Normalise("example.com"));
    }

    [Theory]
    [InlineData("file:///C:/Windows/win.ini")]
    [InlineData("javascript:alert(1)")]
    [InlineData("data:text/html,hi")]
    [InlineData("ms-settings:network")]
    public void OtherSchemesAreRefused(string address)
    {
        Assert.Throws<InvalidOperationException>(() => BrowserPolicy.Normalise(address));
    }

    [Fact]
    public void BlankNavigationIsInternalOnly()
    {
        Assert.True(BrowserPolicy.MayNavigate("about:blank"));
        Assert.True(BrowserPolicy.MayNavigate("https://example.com"));
        Assert.False(BrowserPolicy.MayNavigate("file:///C:/secret.txt"));
    }
}
