using System.Windows;
using System.Windows.Controls;

namespace Hopa.Windows;

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
    }

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

