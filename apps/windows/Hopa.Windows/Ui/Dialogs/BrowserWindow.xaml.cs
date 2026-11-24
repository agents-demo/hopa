using System.Windows;
using System.Windows.Input;
using Microsoft.Web.WebView2.Core;

namespace Hopa.Windows.Ui.Dialogs;

/// <summary>
/// A desktop browsing surface. Link-out remains the fallback when the Edge
/// WebView2 runtime is missing; the engine's web.* actions are not wired yet.
/// </summary>
public partial class BrowserWindow : Window
{
    private readonly string? initialUrl;

    public BrowserWindow(string? initialUrl = null)
    {
        this.initialUrl = initialUrl;
        InitializeComponent();
        Loaded += async (_, _) => await InitializeAsync();
    }

    private async Task InitializeAsync()
    {
        try
        {
            await Web.EnsureCoreWebView2Async();
            Web.CoreWebView2.Settings.AreDevToolsEnabled = false;
            Web.CoreWebView2.Settings.IsStatusBarEnabled = false;
            Web.CoreWebView2.NavigationCompleted += (_, _) =>
            {
                AddressBox.Text = Web.Source?.ToString() ?? "";
                Title = string.IsNullOrEmpty(Web.CoreWebView2.DocumentTitle)
                    ? "HOPA Browser"
                    : $"{Web.CoreWebView2.DocumentTitle} — HOPA";
            };
            Web.CoreWebView2.NewWindowRequested += (_, args) =>
            {
                args.Handled = true;
                Navigate(args.Uri);
            };
            Navigate(initialUrl ?? "about:blank");
        }
        catch (Exception error)
        {
            StatusText.Text = "The Edge WebView2 runtime is not available. " +
                              "Use a link instead, or install the runtime. " + error.Message;
        }
    }

    private void Navigate(string text)
    {
        var value = text.Trim();
        if (value.Length == 0)
        {
            return;
        }

        if (!value.Contains("://", StringComparison.Ordinal))
        {
            value = "https://" + value;
        }

        if (!Uri.TryCreate(value, UriKind.Absolute, out var uri) || Web.CoreWebView2 == null)
        {
            StatusText.Text = $"'{text}' is not a web address.";
            return;
        }

        StatusText.Text = "";
        Web.CoreWebView2.Navigate(uri.ToString());
    }

    private void Address_KeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.Enter)
        {
            Navigate(AddressBox.Text);
            e.Handled = true;
        }
    }

    private void Go_Click(object sender, RoutedEventArgs e) => Navigate(AddressBox.Text);

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
