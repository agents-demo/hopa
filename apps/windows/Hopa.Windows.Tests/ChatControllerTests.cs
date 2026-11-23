using System.Text.Json.Nodes;
using Hopa.Windows.Engine;
using Hopa.Windows.Panes;
using Hopa.Windows.Shell;
using Xunit;

namespace Hopa.Windows.Tests;

/// <summary>The turn lifecycle is testable without the sidecar process or a window.</summary>
public sealed class ChatControllerTests
{
    [Fact]
    public async Task ASendAddsBothBubblesAndUpdatesTheConversation()
    {
        var engine = new FakeEngine
        {
            Turn = new TurnResult("Opened Notepad.", "c1", "Notepad", new JsonArray(), true),
        };
        var chat = new ChatViewModel();
        var conversations = new ConversationsViewModel();
        var controller = new ChatController(engine, chat, conversations);
        var changed = 0;
        controller.MessagesChanged += () => changed++;

        var report = await controller.SendAsync("open notepad", attachment: null);

        Assert.Null(report.Error);
        Assert.Equal("Opened Notepad.", report.Answer);
        Assert.Equal("Notepad", report.Title);
        Assert.Equal("c1", controller.CurrentId);
        Assert.Equal(2, chat.Messages.Count);
        Assert.Single(conversations.All);
        Assert.Equal(2, changed);
        Assert.False(controller.Running);
    }

    [Fact]
    public async Task AFailedTurnIsAnErrorReportAndTheRunningFlagClears()
    {
        var engine = new FakeEngine { Failure = new InvalidOperationException("sidecar is gone") };
        var chat = new ChatViewModel();
        var controller = new ChatController(engine, chat, new ConversationsViewModel());

        var report = await controller.SendAsync("hello", attachment: null);

        Assert.Equal("sidecar is gone", report.Error);
        Assert.True(chat.ErrorVisible);
        Assert.False(controller.Running);
    }

    [Fact]
    public async Task SelectKeepsTheComposerDraftPerConversation()
    {
        var engine = new FakeEngine
        {
            Open = id => id == "a"
                ? new JsonObject
                {
                    ["title"] = "First",
                    ["messages"] = new JsonArray(new JsonObject { ["role"] = "user", ["text"] = "one" }),
                }
                : new JsonObject { ["title"] = "Second", ["messages"] = new JsonArray() },
        };
        var chat = new ChatViewModel();
        var controller = new ChatController(engine, chat, new ConversationsViewModel());

        Assert.Equal("First", await controller.SelectAsync("a"));
        chat.ComposerText = "draft";
        Assert.Equal("Second", await controller.SelectAsync("b"));
        Assert.Equal("", chat.ComposerText);
        Assert.Equal("First", await controller.SelectAsync("a"));
        Assert.Equal("draft", chat.ComposerText);
    }

    [Fact]
    public async Task CreateAddsTheRowTheEngineReturned()
    {
        var engine = new FakeEngine
        {
            Created = new JsonObject { ["id"] = "c2", ["title"] = "New chat" },
        };
        var conversations = new ConversationsViewModel();
        var controller = new ChatController(engine, new ChatViewModel(), conversations);

        var row = await controller.CreateAsync();

        Assert.NotNull(row);
        Assert.Equal("c2", row!.Id);
        Assert.Single(conversations.All);
        Assert.Single(conversations.Visible);
    }

    [Fact]
    public async Task LoadCreatesTheFirstConversationOnlyWhenAsked()
    {
        var engine = new FakeEngine
        {
            Created = new JsonObject { ["id"] = "c1", ["title"] = "First" },
        };
        var conversations = new ConversationsViewModel();
        var controller = new ChatController(engine, new ChatViewModel(), conversations);

        var first = await controller.LoadAsync(includeArchived: false, createIfEmpty: true);
        Assert.Equal("c1", first);
        Assert.Single(conversations.All);

        var empty = new ConversationsViewModel();
        var second = new ChatController(
            new FakeEngine { Created = null },
            new ChatViewModel(),
            empty);
        Assert.Null(await second.LoadAsync(includeArchived: true, createIfEmpty: false));
        Assert.Empty(empty.All);
    }

    [Fact]
    public async Task LoadReplacesTheListItWasGiven()
    {
        var engine = new FakeEngine
        {
            Conversations = new List<JsonObject>
            {
                new() { ["id"] = "a", ["title"] = "A", ["updatedAt"] = 10L },
                new() { ["id"] = "b", ["title"] = "B", ["updatedAt"] = 20L },
            },
        };
        var conversations = new ConversationsViewModel();
        var controller = new ChatController(engine, new ChatViewModel(), conversations);

        var first = await controller.LoadAsync(includeArchived: false, createIfEmpty: false);

        Assert.Equal("b", first);
        Assert.Equal(2, conversations.All.Count);
        Assert.Equal("b", conversations.Visible[0].Id);
    }

    private sealed class FakeEngine : IChatEngine
    {
        public TurnResult Turn { get; set; } =
            new("answer", "c1", "Title", null, true);

        public Exception? Failure { get; set; }

        public JsonObject? Created { get; set; }

        public List<JsonObject> Conversations { get; set; } = new();

        public Func<string, JsonObject?> Open { get; set; } = _ => new JsonObject();

        public Task<TurnResult> StartTurnAsync(
            string goal,
            string? conversationId,
            JsonObject? attachment = null) =>
            Failure != null
                ? Task.FromException<TurnResult>(Failure)
                : Task.FromResult(Turn);

        public Task<JsonObject?> OpenConversationAsync(string id) =>
            Task.FromResult(Open(id));

        public Task<JsonObject?> CreateConversationAsync() =>
            Task.FromResult(Created);

        public Task<List<JsonObject>> ListConversationsAsync(bool includeArchived = false) =>
            Task.FromResult(Conversations);
    }
}
