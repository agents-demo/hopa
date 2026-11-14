using System.Text.Json.Nodes;
using System.Windows;

namespace Hopa.Windows;

public partial class ApprovalWindow : Window
{
    public ApprovalWindow(JsonObject request)
    {
        InitializeComponent();
        TitleLabel.Text = request["title"]?.GetValue<string>() ?? "Allow this action?";
        BodyLabel.Text = request["body"]?.GetValue<string>() ?? "";
        var amount = request["amount"]?.GetValue<string>() ?? "";
        var merchant = request["merchant"]?.GetValue<string>() ?? "";
        AmountLabel.Text = amount.Length > 0 ? $"Amount: {amount}" : "";
        MerchantLabel.Text = merchant.Length > 0 ? $"Merchant: {merchant}" : "";
        ConsequenceLabel.Text = request["consequence"]?.GetValue<string>() ?? "";
        AmountLabel.Visibility = amount.Length > 0 ? Visibility.Visible : Visibility.Collapsed;
        MerchantLabel.Visibility = merchant.Length > 0 ? Visibility.Visible : Visibility.Collapsed;
    }

    private void Allow_Click(object sender, RoutedEventArgs e) => DialogResult = true;

    private void Deny_Click(object sender, RoutedEventArgs e) => DialogResult = false;
}
