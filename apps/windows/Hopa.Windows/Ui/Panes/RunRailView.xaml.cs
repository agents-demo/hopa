using System.Windows.Controls;

namespace Hopa.Windows.Ui.Panes;

/// <summary>The right rail control. Its state lives in <see cref="Model"/>.</summary>
public partial class RunRailView : UserControl
{
    public RunRailView()
    {
        InitializeComponent();
        DataContext = Model;
    }

    public RunRailViewModel Model { get; } = new();
}
