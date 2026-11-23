using System.Windows;
using System.Windows.Media;

namespace Hopa.Windows.Chat;

/// <summary>One bubble in the chat column.</summary>
public sealed class MessageBubble
{
    public string Role { get; init; } = "";

    public string Text { get; init; } = "";

    public bool IsUser => Role == "user";

    public HorizontalAlignment Align => IsUser ? HorizontalAlignment.Right : HorizontalAlignment.Left;

    public Brush Fill => IsUser
        ? new SolidColorBrush(Color.FromRgb(0x0A, 0x59, 0xF7))
        : new SolidColorBrush(Colors.Transparent);

    public Brush Ink => IsUser
        ? new SolidColorBrush(Colors.White)
        : new SolidColorBrush(Color.FromRgb(0x1C, 0x1B, 0x18));
}
