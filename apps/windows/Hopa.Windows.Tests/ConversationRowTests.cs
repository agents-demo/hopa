using System.Text.Json.Nodes;
using Hopa.Windows.Ui.Chat;
using Xunit;

namespace Hopa.Windows.Tests;

/// <summary>The engine's conversation JSON becomes a row with a title, a count and a group.</summary>
public sealed class ConversationRowTests
{
    [Fact]
    public void FromReadsTitleMessagesAndPin()
    {
        var now = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
        var row = ConversationRow.From(new JsonObject
        {
            ["id"] = "c1",
            ["title"] = "Groceries",
            ["updatedAt"] = now,
            ["pinned"] = true,
            ["messages"] = new JsonArray(
                new JsonObject { ["role"] = "user", ["text"] = "milk" },
                new JsonObject { ["role"] = "assistant", ["text"] = "added" }),
        });

        Assert.Equal("c1", row.Id);
        Assert.Equal("Groceries", row.Title);
        Assert.Equal(2, row.MessageCount);
        Assert.True(row.Pinned);
        Assert.Equal("PIN", row.PinLabel);
        Assert.Equal("Today", row.GroupLabel);
        Assert.Contains("milk", row.SearchText);
    }

    [Fact]
    public void ArchivedDateMarksTheRow()
    {
        var row = ConversationRow.From(new JsonObject
        {
            ["id"] = "c2",
            ["archivedAt"] = 1L,
        });

        Assert.True(row.Archived);
        Assert.Equal("archived", row.ArchivedLabel);
        Assert.Equal("New chat", row.Title);
    }

    [Fact]
    public void OldRowsFallIntoTheOlderGroup()
    {
        var old = DateTimeOffset.UtcNow.AddDays(-30).ToUnixTimeMilliseconds();
        var row = ConversationRow.From(new JsonObject
        {
            ["id"] = "c3",
            ["updatedAt"] = old,
        });

        Assert.Equal("Older", row.GroupLabel);
    }
}
