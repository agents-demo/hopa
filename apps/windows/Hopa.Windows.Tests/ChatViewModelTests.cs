using System.Text.Json.Nodes;
using Hopa.Windows.Chat;
using Hopa.Windows.Panes;
using Xunit;

namespace Hopa.Windows.Tests;

/// <summary>The chat pane is a view of the turn; the window still owns the engine calls.</summary>
public sealed class ChatViewModelTests
{
    [Fact]
    public void AConversationRestoresItsMessagesAndDraft()
    {
        var model = new ChatViewModel();
        var messages = new JsonArray(
            new JsonObject { ["role"] = "user", ["text"] = "hi" },
            new JsonObject { ["role"] = "assistant", ["text"] = "hello" });

        model.ShowConversation(messages, "a draft");

        Assert.Equal(2, model.Messages.Count);
        Assert.Equal("hello", model.Messages[1].Text);
        Assert.Equal("a draft", model.ComposerText);
        Assert.False(model.EmptyVisible);
        Assert.False(model.AnswerActionsVisible);
    }

    [Fact]
    public void ATurnAddsTheUserAndTheAnswer()
    {
        var model = new ChatViewModel();
        var steps = new JsonArray(new JsonObject { ["step"] = 1 });

        model.AddUser("open notepad");
        model.AddAnswer("Opened Notepad.", steps, chainOk: true);

        Assert.Equal(2, model.Messages.Count);
        Assert.True(model.Messages[0].IsUser);
        Assert.False(model.Messages[1].IsUser);
        Assert.Equal("Opened Notepad.", model.LastAnswer);
        Assert.Same(steps, model.LastSteps);
        Assert.True(model.LastChainOk);
        Assert.True(model.AnswerActionsVisible);
        Assert.True(model.CopyEnabled);
        Assert.True(model.DetailsEnabled);
        Assert.False(model.EmptyVisible);
    }

    [Fact]
    public void RunningChangesTheSendGlyph()
    {
        var model = new ChatViewModel();

        model.SetRunning(true);
        Assert.Equal("\u25A0", model.SendGlyph);

        model.SetRunning(false);
        Assert.Equal("\u2191", model.SendGlyph);
    }

    [Fact]
    public void AttachmentAndErrorAreVisibleUntilCleared()
    {
        var model = new ChatViewModel();

        model.ShowAttachment("bill.pdf", "48 KB \u00B7 application/pdf");
        model.ShowError("the bridge is offline");

        Assert.True(model.AttachmentVisible);
        Assert.Equal("bill.pdf", model.AttachmentName);
        Assert.True(model.ErrorVisible);

        model.ClearAttachment();
        model.ClearError();
        Assert.False(model.AttachmentVisible);
        Assert.False(model.ErrorVisible);
    }

    [Fact]
    public void TheTargetChipFollowsTheBridge()
    {
        var model = new ChatViewModel();

        model.SetTarget(visible: true, useBridge: true);
        Assert.True(model.TargetVisible);
        Assert.Equal("Phone", model.TargetText);

        model.SetTarget(visible: true, useBridge: false);
        Assert.Equal("Laptop", model.TargetText);
    }
}
