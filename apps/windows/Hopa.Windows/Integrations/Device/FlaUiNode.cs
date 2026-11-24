using System.Drawing;
using FlaUI.Core.AutomationElements;

namespace Hopa.Windows.Integrations.Device;

/// <summary>One UI Automation element exposed through the device contract.</summary>
internal sealed class FlaUiNode : IUiNode
{
    private readonly AutomationElement element;

    public FlaUiNode(AutomationElement element) => this.element = element;

    public string ControlType => element.Properties.ControlType.ValueOrDefault.ToString();

    public string Name => element.Properties.Name.ValueOrDefault ?? "";

    public string AutomationId => element.Properties.AutomationId.ValueOrDefault ?? "";

    public bool IsPassword => element.Properties.IsPassword.ValueOrDefault;

    public bool IsEnabled => element.Properties.IsEnabled.ValueOrDefault;

    public bool IsOffscreen => element.Properties.IsOffscreen.ValueOrDefault;

    public bool HasKeyboardFocus => element.Properties.HasKeyboardFocus.ValueOrDefault;

    public bool CanInvoke => element.Patterns.Invoke.IsSupported;

    public bool CanToggle => element.Patterns.Toggle.IsSupported;

    public bool CanSelectItem => element.Patterns.SelectionItem.IsSupported;

    public bool CanScroll => element.Patterns.Scroll.IsSupported;

    public bool SupportsValue => element.Patterns.Value.IsSupported;

    public string Value => element.Patterns.Value.Pattern.Value.Value ?? "";

    public int ProcessId => element.Properties.ProcessId.Value;

    public IntPtr NativeWindowHandle => (IntPtr)element.Properties.NativeWindowHandle.Value;

    public Rectangle? Bounds => element.BoundingRectangle;

    public IReadOnlyList<IUiNode> Children() =>
        element.FindAllChildren()
            .Select(child => (IUiNode)new FlaUiNode(child))
            .ToArray();

    public void Invoke() => element.Patterns.Invoke.Pattern.Invoke();

    public void Toggle() => element.Patterns.Toggle.Pattern.Toggle();

    public void SelectItem() => element.Patterns.SelectionItem.Pattern.Select();

    public void SetValue(string value) => element.Patterns.Value.Pattern.SetValue(value);

    public void Focus() => element.Focus();
}
