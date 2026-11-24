using System.Windows;
using System.Windows.Input;

namespace Hopa.Windows.Ui.Dialogs;

/// <summary>The numbered plan a plan-first turn returns. Nothing has run yet.</summary>
public partial class PlanWindow : Window
{
    public PlanWindow(string goal, IReadOnlyList<string> plan)
    {
        InitializeComponent();
        GoalText.Text = goal;
        for (var index = 0; index < plan.Count; index++)
        {
            StepList.Items.Add($"{index + 1}. {plan[index]}");
        }
    }

    private void Header_Drag(object sender, MouseButtonEventArgs e)
    {
        if (e.ButtonState == MouseButtonState.Pressed)
        {
            DragMove();
        }
    }

    private void Cancel_Click(object sender, RoutedEventArgs e) => Close();

    private void Approve_Click(object sender, RoutedEventArgs e) => DialogResult = true;
}
