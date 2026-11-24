namespace Hopa.Windows.Integrations.Device;

/// <summary>
/// W3: the Windows device adapter. Observation is a UI Automation tree with
/// pre-order refs, bounded depth, bounded text and a hash. Actions try the UIA
/// pattern first and fall back to the input stack. The tree, input, desktop and
/// app ports keep the rules testable without a real desktop.
/// </summary>
public sealed partial class WindowsDevice
{
    /// <summary>
    /// Open a URI through the shell. Only the schemes an assistant has a reason
    /// to use are allowed: a web page or a Windows settings page. Anything else
    /// is refused instead of handing an arbitrary handler to the OS.
    /// </summary>
    public string OpenLink(string url)
    {
        if (!Uri.TryCreate(url, UriKind.Absolute, out var uri))
        {
            throw new InvalidOperationException($"'{url}' is not an absolute URI");
        }

        var scheme = uri.Scheme.ToLowerInvariant();
        if (scheme is not ("http" or "https" or "ms-settings"))
        {
            throw new InvalidOperationException(
                $"the '{scheme}' scheme is not allowed; only http, https and ms-settings");
        }

        return launcher.OpenLink(url);
    }
}
