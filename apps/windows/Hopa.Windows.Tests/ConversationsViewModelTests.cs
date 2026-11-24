using Hopa.Windows.Ui.Chat;
using Hopa.Windows.Ui.Panes;
using Xunit;

namespace Hopa.Windows.Tests;

/// <summary>The sidebar state is testable without a window or an engine client.</summary>
public sealed class ConversationsViewModelTests
{
    [Fact]
    public void ReplaceAllShowsTheFilteredRows()
    {
        var model = new ConversationsViewModel();

        model.ReplaceAll(new[] { Row("a", updated: 10), Row("b", archived: true) });

        Assert.Equal(2, model.All.Count);
        Assert.Single(model.Visible);
        Assert.Equal("a", model.Visible[0].Id);
    }

    [Fact]
    public void SearchAndArchiveAreRules()
    {
        var model = new ConversationsViewModel();
        model.ReplaceAll(new[] { Row("a", text: "Buy MILK"), Row("b", archived: true) });

        model.Search = "milk";
        Assert.Single(model.Visible);

        model.Search = "";
        model.IncludeArchived = true;
        Assert.Equal(2, model.Visible.Count);
    }

    [Fact]
    public void UpsertAddsANewConversationAndRefreshesAnOldOne()
    {
        var model = new ConversationsViewModel();
        model.ReplaceAll(new[] { Row("a") });

        model.Upsert("b", "Second");
        Assert.Equal(2, model.All.Count);
        Assert.Equal("Second", model.Visible[0].Title);

        model.Upsert("a", "Renamed");
        Assert.Equal("Renamed", model.All.First(row => row.Id == "a").Title);
        Assert.Equal(2, model.All.Count);
    }

    [Fact]
    public void MarkSelectedTouchesTheRowsAndRemoveDropsOne()
    {
        var model = new ConversationsViewModel();
        model.ReplaceAll(new[] { Row("a"), Row("b") });

        model.MarkSelected("b");
        Assert.False(model.All.First(row => row.Id == "a").Selected);
        Assert.True(model.All.First(row => row.Id == "b").Selected);

        model.Remove(model.All.First(row => row.Id == "a"));
        Assert.Single(model.All);
        Assert.Single(model.Visible);
    }

    private static ConversationRow Row(
        string id,
        bool archived = false,
        long updated = 0,
        string text = "") =>
        new()
        {
            Id = id,
            Title = id,
            SearchText = text,
            Archived = archived,
            UpdatedAt = updated,
        };
}
