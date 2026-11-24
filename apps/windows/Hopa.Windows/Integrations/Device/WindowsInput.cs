using System.Drawing;
using FlaUI.Core.Input;
using FlaUI.Core.WindowsAPI;

namespace Hopa.Windows.Integrations.Device;

/// <summary>The real mouse and keyboard, behind the input contract.</summary>
internal sealed class WindowsInput : IInput
{
    public void Click(int x, int y) => Mouse.Click(new Point(x, y));

    public void DoubleClick(int x, int y) => Mouse.DoubleClick(new Point(x, y));

    public void MoveTo(int x, int y) => Mouse.MoveTo(new Point(x, y));

    public void MouseDown() => Mouse.Down(MouseButton.Left);

    public void MouseUp() => Mouse.Up(MouseButton.Left);

    public void Type(string text) => Keyboard.Type(text);

    public void PressBack() => Keyboard.Type(VirtualKeyShort.ESC);

    public void ShowDesktop()
    {
        Keyboard.Press(VirtualKeyShort.LWIN);
        Keyboard.Type(VirtualKeyShort.KEY_D);
        Keyboard.Release(VirtualKeyShort.LWIN);
    }

    public void ReleaseForegroundLock()
    {
        const byte vkMenu = 0x12;
        const uint keyUp = 0x0002;
        Win32.keybd_event(vkMenu, 0, 0, UIntPtr.Zero);
        Win32.keybd_event(vkMenu, 0, keyUp, UIntPtr.Zero);
    }
}
