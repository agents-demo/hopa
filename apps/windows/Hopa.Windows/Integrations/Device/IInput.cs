namespace Hopa.Windows.Integrations.Device;

/// <summary>The mouse and keyboard the adapter falls back to when no pattern applies.</summary>
public interface IInput
{
    void Click(int x, int y);

    void DoubleClick(int x, int y);

    void MoveTo(int x, int y);

    void MouseDown();

    void MouseUp();

    void Type(string text);

    /// <summary>Escape, the Windows equivalent of back.</summary>
    void PressBack();

    /// <summary>Win+D, the Windows equivalent of home.</summary>
    void ShowDesktop();

    /// <summary>Releases the foreground lock without typing into the target.</summary>
    void ReleaseForegroundLock();
}
