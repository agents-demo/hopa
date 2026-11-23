using Hopa.Windows.Chat;
using Xunit;

namespace Hopa.Windows.Tests;

/// <summary>The sidebar order and the search are pure rules, not window state.</summary>
public sealed class ConversationFilterTests
{
    [Fact]
    public void PinnedFirstThenNewest()
    {
        var rows = ConversationFilter.Apply(
            new[]
            {
                Row("a", updated: 10),
                Row("b", pinned: true, updated: 1),
                Row("c", updated: 20),
            },
            "",
            showArchived: false);

        Assert.Equal(new[] { "b", "c", "a" }, rows.Select(row => row.Id));
    }

    [Fact]
    public void ArchivedRowsStayHiddenUntilAskedFor()
    {
        var rows = new[] { Row("a"), Row("b", archived: true) };

        var visible = ConversationFilter.Apply(rows, "", showArchived: false);
        var all = ConversationFilter.Apply(rows, "", showArchived: true);

        Assert.Single(visible);
        Assert.Equal(2, all.Count);
    }

    [Fact]
    public void SearchReadsTheMessageTextAndIgnoresCase()
    {
        var rows = new[] { Row("a", text: "Buy MILK"), Row("b", text: "butter") };

        var hit = Assert.Single(ConversationFilter.Apply(rows, "milk", showArchived: false));

        Assert.Equal("a", hit.Id);
    }

    [Fact]
    public void ABlankSearchIsNotAFilter()
    {
        var rows = new[] { Row("a", text: "anything"), Row("b") };

        Assert.Equal(2, ConversationFilter.Apply(rows, "   ", showArchived: false).Count);
    }

    private static ConversationRow Row(
        string id,
        bool pinned = false,
        bool archived = false,
        long updated = 0,
        string text = "") =>
        new()
        {
            Id = id,
            Title = id,
            SearchText = text,
            Pinned = pinned,
            Archived = archived,
            UpdatedAt = updated,
        };
}
