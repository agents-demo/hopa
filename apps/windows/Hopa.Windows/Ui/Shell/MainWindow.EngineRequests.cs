using System.Text.Json.Nodes;
using System.Windows;
using Hopa.Windows.Integrations.Browser;
using Hopa.Windows.Ui.Dialogs;
using Hopa.Windows.Host;

namespace Hopa.Windows.Ui.Shell;

public partial class MainWindow : Window
{
    private BrowserController? browser;

    /// <summary>Approval goes to automation, the paired phone, or this window; the router decides.</summary>
    private void OnApprovalRequested(JsonObject message)
    {
        var router = new ApprovalRouter(
            askUser: request => Dispatcher.Invoke(
                () => new ApprovalWindow(request) { Owner = this }.ShowDialog() == true),
            phone: () => session?.Gateway,
            reply: (id, allow, source) => client?.SendApprovalResult(id, allow, source),
            log: Log,
            autoApproval: autoApproval);
        _ = router.HandleAsync(message);
    }

    private void OnDeviceRequested(JsonObject message)
    {
        var sender = client;
        if (sender == null)
        {
            return;
        }

        new DeviceRequestRouter(
            device,
            result => sender.SendDeviceResult(
                result.Id,
                result.Ok,
                result.Error,
                result.Observation,
                result.App,
                result.Text,
                result.Image,
                result.Apps),
            Log).Handle(message);
    }

    /// <summary>A `web.*` action needs the one WebView2 window, on this thread.</summary>
    private void OnBrowserRequested(JsonObject message)
    {
        var sender = client;
        if (sender == null)
        {
            return;
        }

        browser ??= new BrowserController(
            () => new BrowserWindow { Owner = this },
            device.OpenLink,
            Log);
        _ = new BrowserRequestRouter(
            browser,
            result => sender.SendBrowserResult(result.Id, result.Ok, result.Error, result.Text),
            Log).HandleAsync(message);
    }
}
