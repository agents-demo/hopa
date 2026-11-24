using System.Windows;
using System.Windows.Input;
using Hopa.Windows.Integrations.Browser;
using Microsoft.Web.WebView2.Core;

namespace Hopa.Windows.Ui.Dialogs;

/// <summary>
/// A desktop browsing surface. Link-out remains the fallback when the Edge
/// WebView2 runtime is missing; the engine's web.* actions use the same window
/// through <see cref="BrowserController"/>.
/// </summary>
public partial class BrowserWindow : Window
{
    private readonly string? initialUrl;
    private Task? ready;
    private TaskCompletionSource<bool>? navigation;

    public BrowserWindow(string? initialUrl = null)
    {
        this.initialUrl = initialUrl;
        InitializeComponent();
        Loaded += async (_, _) =>
        {
            try
            {
                await EnsureReadyAsync();
                if (!string.IsNullOrEmpty(initialUrl))
                {
                    await NavigateAsync(initialUrl);
                }
            }
            catch (Exception error)
            {
                ShowUnavailable(error);
            }
        };
    }

    /// <summary>Starts WebView2 once; a failure is remembered and rethrown.</summary>
    public async Task EnsureReadyAsync()
    {
        ready ??= InitializeAsync();
        await ready;
    }

    private async Task InitializeAsync()
    {
        await Web.EnsureCoreWebView2Async();
        var core = Web.CoreWebView2
            ?? throw new InvalidOperationException("WebView2 started without a core");

        core.Settings.AreDevToolsEnabled = false;
        core.Settings.AreDefaultScriptDialogsEnabled = false;
        core.Settings.IsStatusBarEnabled = false;
        core.Settings.IsWebMessageEnabled = false;
        core.Settings.AreHostObjectsAllowed = false;
        core.Settings.IsGeneralAutofillEnabled = false;
        core.Settings.IsPasswordAutosaveEnabled = false;

        core.PermissionRequested += (_, args) => args.State = CoreWebView2PermissionState.Deny;
        core.DownloadStarting += (_, args) => args.Cancel = true;
        core.NavigationStarting += (_, args) =>
        {
            if (!BrowserPolicy.MayNavigate(args.Uri))
            {
                args.Cancel = true;
                StatusText.Text = $"Blocked navigation to {args.Uri}";
            }
        };
        core.NewWindowRequested += (_, args) =>
        {
            args.Handled = true;
            if (BrowserPolicy.MayNavigate(args.Uri))
            {
                core.Navigate(args.Uri);
            }
        };
        core.NavigationCompleted += (_, args) =>
        {
            AddressBox.Text = core.Source ?? "";
            Title = string.IsNullOrEmpty(core.DocumentTitle)
                ? "HOPA Browser"
                : $"{core.DocumentTitle} - HOPA";
            if (!args.IsSuccess)
            {
                StatusText.Text = $"The page did not load: {args.WebErrorStatus}";
            }

            navigation?.TrySetResult(args.IsSuccess);
        };
    }

    /// <summary>Loads a web address and waits for the page to finish.</summary>
    public async Task<string> NavigateAsync(string address)
    {
        await EnsureReadyAsync();
        var core = Web.CoreWebView2
            ?? throw new InvalidOperationException("WebView2 started without a core");
        var url = BrowserPolicy.Normalise(address);
        var completion = new TaskCompletionSource<bool>(TaskCreationOptions.RunContinuationsAsynchronously);
        navigation = completion;
        StatusText.Text = "";
        try
        {
            core.Navigate(url);
            var finished = await Task.WhenAny(completion.Task, Task.Delay(TimeSpan.FromSeconds(30)));
            if (finished != completion.Task)
            {
                throw new TimeoutException($"the page did not finish loading in 30 s: {url}");
            }

            if (!await completion.Task)
            {
                throw new InvalidOperationException($"the page did not load: {core.Source}");
            }

            return $"navigated to {core.Source}";
        }
        finally
        {
            navigation = null;
        }
    }

    /// <summary>The readable page: address, title, text and tagged controls.</summary>
    public async Task<BrowserPage> ReadAsync()
    {
        await EnsureReadyAsync();
        var json = BrowserScript.Unwrap(await ExecuteAsync(BrowserScript.Read));
        return BrowserScript.ParsePage(json);
    }

    public async Task<string> ClickAsync(string reference)
    {
        await EnsureReadyAsync();
        var action = BrowserScript.ParseAction(
            BrowserScript.Unwrap(await ExecuteAsync(BrowserScript.Click(reference))));
        if (!action.Ok)
        {
            throw new InvalidOperationException(action.Error ?? "the click failed");
        }

        return action.Text ?? $"clicked {reference}";
    }

    public async Task<string> TypeAsync(string text, string? reference)
    {
        await EnsureReadyAsync();
        var action = BrowserScript.ParseAction(
            BrowserScript.Unwrap(await ExecuteAsync(BrowserScript.Type(text, reference))));
        if (!action.Ok)
        {
            throw new InvalidOperationException(action.Error ?? "the type failed");
        }

        return action.Text ?? $"typed {text.Length} chars";
    }

    private async Task<string> ExecuteAsync(string script)
    {
        var core = Web.CoreWebView2
            ?? throw new InvalidOperationException("WebView2 is not ready");
        return await core.ExecuteScriptAsync(script);
    }

    private async Task SafeNavigateAsync(string address)
    {
        try
        {
            await NavigateAsync(address);
        }
        catch (Exception error)
        {
            ShowUnavailable(error);
        }
    }

    private void ShowUnavailable(Exception error)
    {
        StatusText.Text = "The Edge WebView2 runtime is not available. " +
                          "Use a link instead, or install the runtime. " + error.Message;
    }

    private void Address_KeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.Enter)
        {
            _ = SafeNavigateAsync(AddressBox.Text);
            e.Handled = true;
        }
    }

    private void Go_Click(object sender, RoutedEventArgs e) => _ = SafeNavigateAsync(AddressBox.Text);

    private void Back_Click(object sender, RoutedEventArgs e)
    {
        if (Web.CoreWebView2?.CanGoBack == true)
        {
            Web.CoreWebView2.GoBack();
        }
    }

    private void Forward_Click(object sender, RoutedEventArgs e)
    {
        if (Web.CoreWebView2?.CanGoForward == true)
        {
            Web.CoreWebView2.GoForward();
        }
    }

    private void Reload_Click(object sender, RoutedEventArgs e) => Web.CoreWebView2?.Reload();

    private void Header_Drag(object sender, MouseButtonEventArgs e)
    {
        if (e.ButtonState == MouseButtonState.Pressed)
        {
            DragMove();
        }
    }

    private void Close_Click(object sender, RoutedEventArgs e) => Close();
}
