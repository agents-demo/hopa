using System.Windows;
using System.Windows.Controls;
using Hopa.Windows.Integrations.Gateway;
using Hopa.Windows.Storage;

namespace Hopa.Windows.Ui.Dialogs;

public partial class SettingsWindow : Window
{
    private readonly SettingsStore store = new();

    public SettingsWindow()
    {
        InitializeComponent();
        var settings = store.Load();
        BridgeUrlBox.Text = settings.BridgeUrl;
        BridgeTokenBox.Password = CredentialStore.Read("hopa.bridge.token");
        UseBridgeBox.IsChecked = settings.UseBridge;
        Select(ProviderBox, settings.ModelProvider);
        BaseUrlBox.Text = settings.ModelBaseUrl;
        ModelNameBox.Text = settings.ModelName;
        ModelKeyBox.Password = CredentialStore.Read("hopa.model.key");
        Select(ToneBox, settings.Tone);
        var gateway = GatewayCredentials.Load();
        GatewayStatusText.Text = gateway == null
            ? "Not paired. Pairing is the first step for phone approval."
            : $"Paired as {gateway.DeviceId}.";
    }

    private async void PairGateway_Click(object sender, RoutedEventArgs e)
    {
        var link = GatewayLinkBox.Text.Trim();
        if (link.Length == 0)
        {
            GatewayStatusText.Text = "Paste the hopa://pair link first.";
            return;
        }

        PairGatewayButton.IsEnabled = false;
        GatewayStatusText.Text = "Pairing...";
        try
        {
            var credentials = await GatewayPairing.PairAsync(link, Environment.MachineName);
            GatewayLinkBox.Clear();
            GatewayStatusText.Text = $"Paired as {credentials.DeviceId}.";
        }
        catch (Exception error)
        {
            GatewayStatusText.Text = error.Message;
        }
        finally
        {
            PairGatewayButton.IsEnabled = true;
        }
    }

    private void Header_Drag(object sender, System.Windows.Input.MouseButtonEventArgs e)
    {
        if (e.ButtonState == System.Windows.Input.MouseButtonState.Pressed)
        {
            DragMove();
        }
    }

    private void Close_Click(object sender, RoutedEventArgs e) => Close();

    private void Save_Click(object sender, RoutedEventArgs e)
    {
        var settings = new AppSettings
        {
            BridgeUrl = BridgeUrlBox.Text.Trim(),
            UseBridge = UseBridgeBox.IsChecked == true,
            ModelProvider = Value(ProviderBox, "openai"),
            ModelBaseUrl = BaseUrlBox.Text.Trim(),
            ModelName = ModelNameBox.Text.Trim(),
            Tone = Value(ToneBox, "warm"),
        };
        store.Save(settings);
        SaveSecret("hopa.bridge.token", BridgeTokenBox.Password);
        SaveSecret("hopa.model.key", ModelKeyBox.Password);
        DialogResult = true;
    }

    private static void Select(ComboBox box, string value)
    {
        foreach (var item in box.Items)
        {
            if (item is ComboBoxItem candidate &&
                string.Equals(candidate.Content?.ToString(), value, StringComparison.OrdinalIgnoreCase))
            {
                box.SelectedItem = candidate;
                return;
            }
        }

        if (box.Items.Count > 0)
        {
            box.SelectedIndex = 0;
        }
    }

    private static string Value(ComboBox box, string fallback) =>
        (box.SelectedItem as ComboBoxItem)?.Content?.ToString() ?? fallback;

    private static void SaveSecret(string name, string value)
    {
        if (string.IsNullOrEmpty(value))
        {
            CredentialStore.Delete(name);
        }
        else
        {
            CredentialStore.Write(name, value);
        }
    }
}

