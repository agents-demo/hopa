namespace Hopa.Windows.Integrations.Device;

/// <summary>
/// The session facts around the UI tree: whether the desktop may be driven, what
/// is in front, its size and scale, and a screenshot. Kept apart from the tree so
/// the lock screen and elevation rules can be faked.
/// </summary>
public interface IDesktopSession
{
    /// <summary>The refusal the current foreground would produce, or null when usable.</summary>
    string? UnreadableReason();

    string ForegroundApp();

    System.Windows.Size ScreenSize();

    /// <summary>Display scale relative to 96 DPI.</summary>
    double Dpi();

    byte[]? CaptureWindow();
}
