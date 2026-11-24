using System.Text.Json.Nodes;
using Hopa.Windows.Integrations.Browser;

namespace Hopa.Windows.Host;

/// <summary>Maps a `web.*` request to the WebView2 surface and one reply.</summary>
public sealed class BrowserRequestRouter
{
    private readonly IBrowserController browser;
    private readonly Action<BrowserResult> reply;
    private readonly Action<string> log;

    public BrowserRequestRouter(
        IBrowserController browser,
        Action<BrowserResult> reply,
        Action<string> log)
    {
        this.browser = browser;
        this.reply = reply;
        this.log = log;
    }

    public async Task HandleAsync(JsonObject message)
    {
        var id = message["id"]?.GetValue<string>() ?? "";
        var op = message["op"]?.GetValue<string>() ?? "";
        try
        {
            var text = op switch
            {
                "navigate" => await browser.NavigateAsync(message["url"]?.GetValue<string>() ?? ""),
                "read" => await browser.ReadAsync(),
                "click" => await browser.ClickAsync(message["ref"]?.GetValue<string>() ?? ""),
                "type" => await browser.TypeAsync(
                    message["text"]?.GetValue<string>() ?? "",
                    message["ref"]?.GetValue<string>()),
                _ => throw new InvalidOperationException($"the browser cannot '{op}'"),
            };
            log($"browser: {op} ok");
            reply(new BrowserResult(id, true, Text: text));
        }
        catch (Exception error)
        {
            log($"browser error: {error.Message}");
            reply(new BrowserResult(id, false, error.Message));
        }
    }
}
