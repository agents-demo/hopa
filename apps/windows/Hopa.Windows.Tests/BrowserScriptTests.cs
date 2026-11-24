using Hopa.Windows.Integrations.Browser;
using Xunit;

namespace Hopa.Windows.Tests;

/// <summary>The ref rules and the text format are what the model actually reads.</summary>
public sealed class BrowserScriptTests
{
    [Fact]
    public void TheReadScriptTagsControls() 
    {
        Assert.Contains("data-hopa-ref", BrowserScript.Read);
        Assert.Contains("password field", BrowserScript.Read);
        Assert.Contains("elements", BrowserScript.Read);
    }

    [Fact]
    public void AReferenceIsEscapedIntoTheClickScript()
    {
        var script = BrowserScript.Click("w3\"");
        Assert.Contains("data-hopa-ref", script);
        Assert.Contains("w3\\u0022", script);
    }

    [Fact]
    public void ThePageFormatCarriesTheAddressTextAndRefs()
    {
        var page = new BrowserPage(
            "https://example.com/",
            "Example",
            "Hello",
            new List<BrowserElement> { new("w1", "link", "More") });

        var text = BrowserScript.Format(page);

        Assert.Contains("URL: https://example.com/", text);
        Assert.Contains("TITLE: Example", text);
        Assert.Contains("[w1] link \"More\"", text);
        Assert.Contains("TEXT:\nHello", text);
    }

    [Fact]
    public void APageParsesFromTheJsonTheScriptReturns()
    {
        var json = """
            {"url":"https://example.com/","title":"Example","text":"Hello",
             "elements":[{"ref":"w1","role":"button","name":"Save"}]}
            """;

        var page = BrowserScript.ParsePage(json);

        Assert.Equal("Example", page.Title);
        Assert.Equal("w1", page.Elements[0].Ref);
        Assert.Equal("Save", page.Elements[0].Name);
    }

    [Fact]
    public void AnActionFailureIsNotAnEmptySuccess()
    {
        var action = BrowserScript.ParseAction(
            """{"ok":false,"error":"stale ref; read the page again"}""");

        Assert.False(action.Ok);
        Assert.Equal("stale ref; read the page again", action.Error);
    }

    [Fact]
    public void WebView2DoubleEncodedStringIsUnwrapped()
    {
        Assert.Equal("{\"ok\":true}", BrowserScript.Unwrap("\"{\\\"ok\\\":true}\""));
        Assert.Equal("", BrowserScript.Unwrap("null"));
    }
}
