using System.Windows;
using Hopa.Windows.Ui.Dialogs;

namespace Hopa.Windows.Integrations.Browser;

/// <summary>
/// Owns the one WebView2 window the engine uses. Engine requests arrive on the
/// transport thread, so every WebView2 call is marshalled to the WPF thread and
/// serialised: two actions must not race on the same page.
/// </summary>
public sealed class BrowserController : IBrowserController, IDisposable
{
    private readonly Func<BrowserWindow> create;
    private readonly Func<string, string> openLink;
    private readonly Action<string>? log;
    private readonly SemaphoreSlim gate = new(1, 1);
    private BrowserWindow? window;

    internal BrowserWindow? Surface => window;

    public BrowserController(
        Func<BrowserWindow> create,
        Func<string, string> openLink,
        Action<string>? log = null)
    {
        this.create = create;
        this.openLink = openLink;
        this.log = log;
    }

    public async Task<string> NavigateAsync(string url)
    {
        var target = BrowserPolicy.Normalise(url);
        await gate.WaitAsync();
        try
        {
            BrowserWindow surface;
            try
            {
                surface = await OnUiAsync(() =>
                {
                    var created = EnsureWindow();
                    return Task.FromResult(created);
                });
                await OnUiAsync(async () =>
                {
                    await surface.EnsureReadyAsync();
                    return true;
                });
            }
            catch (Exception error)
            {
                log?.Invoke($"browser: WebView2 unavailable ({error.Message}); using the default browser");
                return openLink(target) +
                       " (the built-in browser is unavailable; read, click and type cannot run)";
            }

            return await OnUiAsync(() => surface.NavigateAsync(target));
        }
        finally
        {
            gate.Release();
        }
    }

    public async Task<string> ReadAsync()
    {
        await gate.WaitAsync();
        try
        {
            var surface = await EnsureSurfaceAsync();
            var page = await OnUiAsync(() => surface.ReadAsync());
            return BrowserScript.Format(page);
        }
        finally
        {
            gate.Release();
        }
    }

    public async Task<string> ClickAsync(string reference)
    {
        await gate.WaitAsync();
        try
        {
            var surface = await EnsureSurfaceAsync();
            return await OnUiAsync(() => surface.ClickAsync(reference));
        }
        finally
        {
            gate.Release();
        }
    }

    public async Task<string> TypeAsync(string text, string? reference)
    {
        await gate.WaitAsync();
        try
        {
            var surface = await EnsureSurfaceAsync();
            return await OnUiAsync(() => surface.TypeAsync(text, reference));
        }
        finally
        {
            gate.Release();
        }
    }

    private async Task<BrowserWindow> EnsureSurfaceAsync()
    {
        var surface = await OnUiAsync(() =>
        {
            var created = EnsureWindow();
            return Task.FromResult(created);
        });
        try
        {
            await OnUiAsync(async () =>
            {
                await surface.EnsureReadyAsync();
                return true;
            });
        }
        catch (Exception error)
        {
            throw new InvalidOperationException(
                "the built-in browser is unavailable: " + error.Message,
                error);
        }

        return surface;
    }

    /// <summary>Must run on the WPF thread.</summary>
    private BrowserWindow EnsureWindow()
    {
        if (window is { IsLoaded: true })
        {
            window.Activate();
            return window;
        }

        window = create();
        window.Show();
        window.Activate();
        return window;
    }

    private static Task<T> OnUiAsync<T>(Func<Task<T>> action)
    {
        var dispatcher = Application.Current?.Dispatcher
            ?? throw new InvalidOperationException("the browser needs a WPF application");
        return dispatcher.InvokeAsync(action).Task.Unwrap();
    }

    public void Dispose()
    {
        if (window != null)
        {
            window.Close();
            window = null;
        }

        gate.Dispose();
    }
}
