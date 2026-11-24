using System.Drawing;
using System.Text.Json.Nodes;
using Hopa.Windows.Integrations.Device;
using Xunit;

namespace Hopa.Windows.Tests;

/// <summary>
/// Observation, refs and input against fake ports: the Windows rules are
/// testable without a real desktop.
/// </summary>
public sealed class WindowsDeviceTests
{
    [Fact]
    public void ObserveBuildsAPreOrderTreeWithRefsAndText()
    {
        var harness = new Harness();
        harness.Tree.Root = Window(
            "Notepad",
            Button("Save"),
            Edit("Body", value: "hello"),
            Password("Secret", "hunter2"));

        var (observation, nodes) = harness.Device.Observe();

        Assert.Equal(3, nodes);
        Assert.Equal("notepad", observation["app"]!.GetValue<string>());
        Assert.Equal(1920, observation["screenSize"]!["width"]!.GetValue<int>());
        Assert.Equal(1080, observation["screenSize"]!["height"]!.GetValue<int>());
        Assert.Equal(1.0, observation["density"]!.GetValue<double>());
        Assert.False(observation["truncated"]!.GetValue<bool>());

        var tree = (JsonObject)observation["tree"]!;
        Assert.Equal("e1", tree["ref"]!.GetValue<string>());
        Assert.Equal("window", tree["type"]!.GetValue<string>());
        Assert.Equal("Notepad", tree["text"]!.GetValue<string>());

        var children = (JsonArray)tree["children"]!;
        Assert.Equal(3, children.Count);
        Assert.Equal("e2", children[0]!["ref"]!.GetValue<string>());
        Assert.Equal("button", children[0]!["type"]!.GetValue<string>());
        Assert.Equal("Save", children[0]!["text"]!.GetValue<string>());
        Assert.Equal("e3", children[1]!["ref"]!.GetValue<string>());

        var lines = new[]
        {
            "e1 window Notepad",
            "e2 button Save",
            "e3 edit Body",
            "e4 password field (dropped)",
        };
        Assert.Equal(string.Join("\n", lines), observation["text"]!.GetValue<string>());
        Assert.Equal(
            ObservationRules.Hash("notepad", 1920, 1080, lines),
            observation["hash"]!.GetValue<string>());
    }

    [Fact]
    public void ObserveDropsThePasswordTextAndItsRef()
    {
        var harness = new Harness();
        harness.Tree.Root = Window("Sign in", Password("Secret", "hunter2"));

        var (observation, nodes) = harness.Device.Observe();

        Assert.Equal(1, nodes);
        var password = (JsonObject)((JsonArray)((JsonObject)observation["tree"]!)["children"]!)[0]!;
        Assert.Equal("password", password["type"]!.GetValue<string>());
        Assert.Equal("", password["text"]!.GetValue<string>());
        Assert.DoesNotContain("hunter2", observation["text"]!.GetValue<string>());

        var error = Assert.Throws<InvalidOperationException>(() =>
            harness.Device.Act("tap", new JsonObject { ["ref"] = "e2" }));
        Assert.Contains("stale ref e2", error.Message);
    }

    [Fact]
    public void ObserveRefusesALockedDesktopBeforeReadingTheTree()
    {
        var harness = new Harness();
        harness.Desktop.Refusal = "the screen is locked or secure; HOPA cannot see or touch it";
        harness.Tree.Root = Window("Notepad");

        var error = Assert.Throws<InvalidOperationException>(() => harness.Device.Observe());

        Assert.Contains("locked or secure", error.Message);
        Assert.Equal(0, harness.Tree.ForegroundCalls);
    }

    [Fact]
    public void ObserveRefusesATreeWithOnlyTheRoot()
    {
        var harness = new Harness();

        var error = Assert.Throws<InvalidOperationException>(() => harness.Device.Observe());

        Assert.Contains("exposes no UI Automation tree", error.Message);
    }

    [Fact]
    public void TapUsesTheInvokePatternWhenTheControlOffersIt()
    {
        var harness = new Harness();
        var button = Button("Save");
        harness.Tree.Root = Window("Notepad", button);
        harness.Device.Observe();

        var result = harness.Device.Act("tap", new JsonObject { ["ref"] = "e2" });

        Assert.Equal("invoked e2", result);
        Assert.True(button.Invoked);
        Assert.Empty(harness.Input.Calls);
    }

    [Fact]
    public void TapFallsBackToTheMouseWhenThePatternFails()
    {
        var harness = new Harness();
        var button = Button("Save", bounds: new Rectangle(0, 0, 100, 40));
        button.InvokeError = new InvalidOperationException("not now");
        harness.Tree.Root = Window("Notepad", button);
        harness.Device.Observe();

        var result = harness.Device.Act("tap", new JsonObject { ["ref"] = "e2" });

        Assert.Equal("clicked 50,20", result);
        Assert.Equal(new[] { "click 50,20" }, harness.Input.Calls);
    }

    [Fact]
    public void TapRefusesAStaleRef()
    {
        var harness = new Harness();
        harness.Tree.Root = Window("Notepad", Button("Save"));
        harness.Device.Observe();

        var error = Assert.Throws<InvalidOperationException>(() =>
            harness.Device.Act("tap", new JsonObject { ["ref"] = "e9" }));

        Assert.Contains("stale ref e9", error.Message);
    }

    [Fact]
    public void TypeSetsTheValueWhenTheControlSupportsIt()
    {
        var harness = new Harness();
        var edit = Edit("Body", value: "");
        harness.Tree.Root = Window("Notepad", edit);
        harness.Device.Observe();

        var result = harness.Device.Act(
            "type",
            new JsonObject { ["ref"] = "e2", ["text"] = "hello" });

        Assert.Equal("set e2 to 5 chars", result);
        Assert.Equal("hello", edit.Value);
        Assert.Empty(harness.Input.Calls);
    }

    [Fact]
    public void TypeFallsBackToTheKeyboardAndNeedsARef()
    {
        var harness = new Harness();
        var pane = Pane("Field");
        harness.Tree.Root = Window("Notepad", pane);
        harness.Device.Observe();

        var result = harness.Device.Act(
            "type",
            new JsonObject { ["ref"] = "e2", ["text"] = "hello" });

        Assert.Equal("typed 5 chars", result);
        Assert.True(pane.Focused);
        Assert.Equal(new[] { "type hello" }, harness.Input.Calls);

        var error = Assert.Throws<InvalidOperationException>(() =>
            harness.Device.Act("type", new JsonObject { ["text"] = "hello" }));
        Assert.Contains("type needs a ref", error.Message);
    }

    [Fact]
    public void SwipeAndKeysMapToTheInputStack()
    {
        var harness = new Harness();
        harness.Tree.Root = Window("Notepad");
        harness.Device.Observe();

        var swipe = harness.Device.Act("swipe", new JsonObject
        {
            ["fromX"] = 1,
            ["fromY"] = 2,
            ["toX"] = 3,
            ["toY"] = 4,
        });
        Assert.Equal("swiped 1,2 -> 3,4", swipe);
        Assert.Equal(new[] { "move 1,2", "down", "move 3,4", "up" }, harness.Input.Calls);

        harness.Input.Calls.Clear();
        Assert.Equal("pressed Escape (back)", harness.Device.Act("key", new JsonObject { ["key"] = "back" }));
        Assert.Equal("showed the desktop (home)", harness.Device.Act("key", new JsonObject { ["key"] = "home" }));
        Assert.Equal(new[] { "back", "home" }, harness.Input.Calls);
    }

    [Fact]
    public void OpenLinkAllowsOnlyTheThreeSchemesAndDelegates()
    {
        var harness = new Harness();

        var result = harness.Device.OpenLink("https://example.com");
        Assert.Equal("opened https://example.com", result);
        Assert.Equal(new[] { "https://example.com" }, harness.Launcher.Opened);

        Assert.Throws<InvalidOperationException>(() =>
            harness.Device.OpenLink("file:///C:/secrets.txt"));
        Assert.Throws<InvalidOperationException>(() =>
            harness.Device.OpenLink("not a uri"));
        Assert.Single(harness.Launcher.Opened);
    }

    [Fact]
    public void LaunchAndStopDelegateAndRefuseAnEmptyApp()
    {
        var harness = new Harness();

        Assert.Equal("launched calc", harness.Device.Act(
            "launch",
            new JsonObject { ["app"] = "calc" }));
        Assert.Equal("stopped calc", harness.Device.Act(
            "stop",
            new JsonObject { ["app"] = "calc" }));
        Assert.Equal(new[] { "calc" }, harness.Launcher.Launched);
        Assert.Equal(new[] { "calc" }, harness.Launcher.Stopped);

        Assert.Throws<InvalidOperationException>(() =>
            harness.Device.Act("launch", new JsonObject()));
        Assert.Throws<InvalidOperationException>(() =>
            harness.Device.Act("stop", new JsonObject()));
    }

    [Fact]
    public void AppsAndRefusalsComeFromTheirPorts()
    {
        var harness = new Harness();
        harness.Apps.Items.Add(new DeviceApp("calc.exe", "Calculator"));
        harness.Desktop.Refusal = "locked";

        Assert.Equal("Calculator", Assert.Single(harness.Device.Apps()).Label);
        Assert.Equal("locked", harness.Device.UnreadableReason());

        var error = Assert.Throws<InvalidOperationException>(() =>
            harness.Device.Act("tap", new JsonObject { ["x"] = 1, ["y"] = 2 }));
        Assert.Equal("locked", error.Message);
    }

    private static FakeNode Window(string name, params FakeNode[] children) => new()
    {
        ControlType = "Window",
        Name = name,
        Bounds = new Rectangle(0, 0, 800, 600),
        Kids = children.Cast<IUiNode>().ToList(),
    };

    private static FakeNode Button(string name, Rectangle? bounds = null) => new()
    {
        ControlType = "Button",
        Name = name,
        CanInvoke = true,
        Bounds = bounds ?? new Rectangle(0, 0, 100, 30),
    };

    private static FakeNode Edit(string name, string value) => new()
    {
        ControlType = "Edit",
        Name = name,
        SupportsValue = true,
        Value = value,
        Bounds = new Rectangle(0, 40, 300, 100),
    };

    private static FakeNode Password(string name, string value) => new()
    {
        ControlType = "Edit",
        Name = name,
        IsPassword = true,
        SupportsValue = true,
        Value = value,
        Bounds = new Rectangle(0, 40, 300, 100),
    };

    private static FakeNode Pane(string name) => new()
    {
        ControlType = "Pane",
        Name = name,
        Bounds = new Rectangle(0, 40, 300, 100),
    };

    private sealed class Harness
    {
        public FakeTree Tree { get; } = new();

        public RecordingInput Input { get; } = new();

        public FakeDesktop Desktop { get; } = new();

        public FakeApps Apps { get; } = new();

        public FakeLauncher Launcher { get; } = new();

        public WindowsDevice Device { get; }

        public Harness() => Device = new WindowsDevice(Tree, Input, Desktop, Apps, Launcher);
    }

    private sealed class FakeTree : IUiTree
    {
        public IUiNode? Root { get; set; }

        public int ForegroundCalls { get; private set; }

        public IUiNode? Foreground()
        {
            ForegroundCalls += 1;
            return Root;
        }

        public IUiNode Desktop() => Root ?? new FakeNode();

        public void Dispose()
        {
        }
    }

    private sealed class FakeNode : IUiNode
    {
        public string ControlType { get; init; } = "Pane";

        public string Name { get; init; } = "";

        public string AutomationId { get; init; } = "";

        public bool IsPassword { get; init; }

        public bool IsEnabled { get; init; } = true;

        public bool IsOffscreen { get; init; }

        public bool HasKeyboardFocus { get; init; }

        public bool CanInvoke { get; init; }

        public bool CanToggle { get; init; }

        public bool CanSelectItem { get; init; }

        public bool CanScroll { get; init; }

        public bool SupportsValue { get; init; }

        public string Value { get; set; } = "";

        public int ProcessId { get; init; }

        public IntPtr NativeWindowHandle { get; init; }

        public Rectangle? Bounds { get; init; }

        public List<IUiNode> Kids { get; init; } = new();

        public Exception? InvokeError { get; set; }

        public bool Invoked { get; private set; }

        public bool Focused { get; private set; }

        public string? SetText { get; private set; }

        public IReadOnlyList<IUiNode> Children() => Kids;

        public void Invoke()
        {
            Invoked = true;
            if (InvokeError != null)
            {
                throw InvokeError;
            }
        }

        public void Toggle()
        {
        }

        public void SelectItem()
        {
        }

        public void SetValue(string value)
        {
            SetText = value;
            Value = value;
        }

        public void Focus() => Focused = true;
    }

    private sealed class RecordingInput : IInput
    {
        public List<string> Calls { get; } = new();

        public void Click(int x, int y) => Calls.Add($"click {x},{y}");

        public void DoubleClick(int x, int y) => Calls.Add($"doubleClick {x},{y}");

        public void MoveTo(int x, int y) => Calls.Add($"move {x},{y}");

        public void MouseDown() => Calls.Add("down");

        public void MouseUp() => Calls.Add("up");

        public void Type(string text) => Calls.Add($"type {text}");

        public void PressBack() => Calls.Add("back");

        public void ShowDesktop() => Calls.Add("home");

        public void ReleaseForegroundLock()
        {
        }
    }

    private sealed class FakeDesktop : IDesktopSession
    {
        public string? Refusal { get; set; }

        public string App { get; set; } = "notepad";

        public System.Windows.Size Screen { get; set; } = new(1920, 1080);

        public double Scale { get; set; } = 96;

        public string? UnreadableReason() => Refusal;

        public string ForegroundApp() => App;

        public System.Windows.Size ScreenSize() => Screen;

        public double Dpi() => Scale;

        public byte[]? CaptureWindow() => null;
    }

    private sealed class FakeApps : IAppCatalog
    {
        public List<DeviceApp> Items { get; } = new();

        public List<DeviceApp> Apps() => Items;
    }

    private sealed class FakeLauncher : IAppLauncher
    {
        public List<string> Opened { get; } = new();

        public List<string> Launched { get; } = new();

        public List<string> Stopped { get; } = new();

        public string OpenLink(string url)
        {
            Opened.Add(url);
            return $"opened {url}";
        }

        public string Launch(string app)
        {
            Launched.Add(app);
            return $"launched {app}";
        }

        public string Stop(string app)
        {
            Stopped.Add(app);
            return $"stopped {app}";
        }
    }
}
