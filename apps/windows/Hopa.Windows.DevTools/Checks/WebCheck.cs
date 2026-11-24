using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Text.RegularExpressions;
using Hopa.Windows.Integrations.Browser;
using Hopa.Windows.Ui;
using Hopa.Windows.Ui.Dialogs;

namespace Hopa.Windows.DevTools.Checks;

/// <summary>
/// W10f: the engine's WebView2 surface, exercised without the model. A loopback
/// page proves navigate/read, tags its controls for click/type, and leaves a
/// transcript and screenshot the reviewer can open.
/// </summary>
internal static class WebCheck
{
    private const string Page = """
        <!doctype html>
        <html>
        <head><meta charset="utf-8"><title>HOPA web check</title></head>
        <body>
          <h1>HOPA web check</h1>
          <p>Read this page and fill the form.</p>
          <label>Full name <input name="name" aria-label="Full name"></label>
          <label>Signature <input name="signature" aria-label="Signature"></label>
          <button id="submit">Submit</button>
          <p id="result"></p>
          <script>
            document.getElementById('submit').addEventListener('click', function () {
              var name = document.querySelector('input[name=name]').value;
              document.getElementById('result').textContent = 'Signed by ' + name;
            });
          </script>
        </body>
        </html>
        """;

    public static async Task Run(string path)
    {
        Directory.CreateDirectory(path);
        var lines = new List<string>();
        var listener = new TcpListener(IPAddress.Loopback, 0);
        listener.Start();
        var port = ((IPEndPoint)listener.LocalEndpoint).Port;
        using var stop = new CancellationTokenSource();
        var server = ServeAsync(listener, stop.Token);
        using var browser = new BrowserController(
            () => new BrowserWindow(),
            url => throw new InvalidOperationException("WebView2 is required for --web-check"),
            line => lines.Add($"log: {line}"));
        var url = $"http://127.0.0.1:{port}/";
        try
        {
            lines.Add($"url: {url}");
            lines.Add("navigate: " + await browser.NavigateAsync(url));
            var page = await browser.ReadAsync();
            lines.Add("read:");
            lines.Add(page);
            lines.Add("has heading: " + page.Contains("HOPA web check", StringComparison.Ordinal));
            lines.Add("has name field: " + page.Contains("Full name", StringComparison.Ordinal));
            lines.Add("has submit: " + page.Contains("Submit", StringComparison.Ordinal));
            lines.Add("has refs: " + page.Contains("[w1]", StringComparison.Ordinal));

            var nameRef = RefFor(page, "Full name");
            var submitRef = RefFor(page, "Submit");
            lines.Add($"name ref: {nameRef}");
            lines.Add($"submit ref: {submitRef}");
            lines.Add("type: " + await browser.TypeAsync("Michael", nameRef));
            lines.Add("click: " + await browser.ClickAsync(submitRef));
            var signed = await browser.ReadAsync();
            lines.Add("after submit:");
            lines.Add(signed);
            lines.Add("signed visible: " +
                      signed.Contains("Signed by Michael", StringComparison.Ordinal));

            var surface = browser.Surface;
            if (surface != null)
            {
                await surface.Dispatcher.InvokeAsync(
                    () => WindowScreenshot.Save(surface, Path.Combine(path, "windows-web-check.png")));
            }
        }
        catch (Exception error)
        {
            lines.Add("FAIL: " + error.Message);
        }
        finally
        {
            stop.Cancel();
            listener.Stop();
            try
            {
                await server;
            }
            catch (Exception)
            {
                // The listener closes when the check ends.
            }
        }

        File.WriteAllLines(Path.Combine(path, "web-check.txt"), lines);
    }

    private static string RefFor(string page, string label)
    {
        var match = Regex.Match(page, $"\\[(w\\d+)\\][^\\n]*\"{Regex.Escape(label)}\"");
        return match.Success
            ? match.Groups[1].Value
            : throw new InvalidOperationException($"no readable control named '{label}'");
    }

    private static async Task ServeAsync(TcpListener listener, CancellationToken token)
    {
        while (!token.IsCancellationRequested)
        {
            TcpClient client;
            try
            {
                client = await listener.AcceptTcpClientAsync(token);
            }
            catch (OperationCanceledException)
            {
                return;
            }
            catch (ObjectDisposedException)
            {
                return;
            }

            _ = Task.Run(() => RespondAsync(client), CancellationToken.None);
        }
    }

    private static async Task RespondAsync(TcpClient client)
    {
        using (client)
        {
            try
            {
                var stream = client.GetStream();
                using var reader = new StreamReader(stream, Encoding.ASCII, leaveOpen: true);
                await reader.ReadLineAsync();
                while (await reader.ReadLineAsync() is { Length: > 0 })
                {
                }

                var body = Encoding.UTF8.GetBytes(Page);
                var header = Encoding.ASCII.GetBytes(
                    "HTTP/1.1 200 OK\r\n" +
                    "Content-Type: text/html; charset=utf-8\r\n" +
                    $"Content-Length: {body.Length}\r\n" +
                    "Connection: close\r\n\r\n");
                await stream.WriteAsync(header);
                await stream.WriteAsync(body);
                await stream.FlushAsync();
            }
            catch (Exception)
            {
                // A browser probe or a closed connection is not a check failure.
            }
        }
    }
}
