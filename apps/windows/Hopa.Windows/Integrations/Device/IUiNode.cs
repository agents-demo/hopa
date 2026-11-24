using System.Drawing;

namespace Hopa.Windows.Integrations.Device;

/// <summary>
/// One node the device adapter can read or act on. The adapter owns UI
/// Automation; this contract lets the observation and input rules run against a
/// fake tree.
/// </summary>
public interface IUiNode
{
    string ControlType { get; }

    string Name { get; }

    string AutomationId { get; }

    bool IsPassword { get; }

    bool IsEnabled { get; }

    bool IsOffscreen { get; }

    bool HasKeyboardFocus { get; }

    bool CanInvoke { get; }

    bool CanToggle { get; }

    bool CanSelectItem { get; }

    bool CanScroll { get; }

    bool SupportsValue { get; }

    string Value { get; }

    int ProcessId { get; }

    IntPtr NativeWindowHandle { get; }

    Rectangle? Bounds { get; }

    IReadOnlyList<IUiNode> Children();

    void Invoke();

    void Toggle();

    void SelectItem();

    void SetValue(string value);

    void Focus();
}
