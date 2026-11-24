using System.Text.Json.Nodes;
using Hopa.Windows.Ui.Chat;
using Xunit;

namespace Hopa.Windows.Tests;

/// <summary>A stored message becomes a bubble with the right side and ink.</summary>
public sealed class MessageBubbleTests
{
    [Fact]
    public void AUserMessageSitsOnTheRight()
    {
        var bubble = MessageBubble.From(new JsonObject
        {
            ["role"] = "user",
            ["text"] = "pay the bill",
        });

        Assert.True(bubble.IsUser);
        Assert.Equal("pay the bill", bubble.Text);
        Assert.Equal(System.Windows.HorizontalAlignment.Right, bubble.Align);
    }

    [Fact]
    public void AMissingRoleIsAnAnswer()
    {
        var bubble = MessageBubble.From(new JsonObject { ["text"] = "done" });

        Assert.False(bubble.IsUser);
        Assert.Equal("assistant", bubble.Role);
        Assert.Equal(System.Windows.HorizontalAlignment.Left, bubble.Align);
    }
}
