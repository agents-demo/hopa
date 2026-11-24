using System.Text.Json.Nodes;
using Hopa.Windows.Integrations.Device;
using Hopa.Windows.Host;
using Xunit;

namespace Hopa.Windows.Tests;

/// <summary>The device request router is the engine's view of this PC.</summary>
public sealed class DeviceRequestRouterTests
{
    [Fact]
    public void ObserveSendsTheTreeAndTheNodeCountIsLogged()
    {
        var device = new FakeDevice
        {
            Observation = new JsonObject { ["app"] = "notepad", ["text"] = "hello" },
            Nodes = 7,
        };
        var results = new List<DeviceResult>();
        var logs = new List<string>();

        new DeviceRequestRouter(device, results.Add, logs.Add)
            .Handle(new JsonObject { ["id"] = "d1", ["op"] = "observe" });

        var result = Assert.Single(results);
        Assert.True(result.Ok);
        Assert.Same(device.Observation, result.Observation);
        Assert.Contains("7 nodes", logs[0]);
    }

    [Fact]
    public void AScreenshotRoundTripsAsBase64()
    {
        var device = new FakeDevice { Screenshot = new byte[] { 1, 2, 3 } };
        var results = new List<DeviceResult>();

        new DeviceRequestRouter(device, results.Add, _ => { })
            .Handle(new JsonObject { ["id"] = "d1", ["op"] = "screenshot" });

        var result = Assert.Single(results);
        Assert.Equal(Convert.ToBase64String(new byte[] { 1, 2, 3 }), result.Image);
    }

    [Fact]
    public void AProtectedScreenStillAnswersWithOk()
    {
        var device = new FakeDevice { Screenshot = null };
        var results = new List<DeviceResult>();

        new DeviceRequestRouter(device, results.Add, _ => { })
            .Handle(new JsonObject { ["id"] = "d1", ["op"] = "screenshot" });

        var result = Assert.Single(results);
        Assert.True(result.Ok);
        Assert.Null(result.Image);
    }

    [Fact]
    public void AppsBecomeJsonObjects()
    {
        var device = new FakeDevice
        {
            Applications = new List<DeviceApp> { new("calc.exe", "Calculator") },
        };
        var results = new List<DeviceResult>();

        new DeviceRequestRouter(device, results.Add, _ => { })
            .Handle(new JsonObject { ["id"] = "d1", ["op"] = "apps" });

        var result = Assert.Single(results);
        var app = Assert.Single(result.Apps!.OfType<JsonObject>());
        Assert.Equal("calc.exe", app["package"]!.GetValue<string>());
        Assert.Equal("Calculator", app["label"]!.GetValue<string>());
    }

    [Fact]
    public void AnUnknownActionGoesToActAndAFailureIsReported()
    {
        var device = new FakeDevice { ActResult = "typed 4 chars" };
        var results = new List<DeviceResult>();

        new DeviceRequestRouter(device, results.Add, _ => { })
            .Handle(new JsonObject { ["id"] = "d1", ["op"] = "type", ["text"] = "HOPA" });

        Assert.Equal("typed 4 chars", Assert.Single(results).Text);

        results.Clear();
        device.Failure = new InvalidOperationException("stale ref e9");
        new DeviceRequestRouter(device, results.Add, _ => { })
            .Handle(new JsonObject { ["id"] = "d2", ["op"] = "type" });

        var failed = Assert.Single(results);
        Assert.False(failed.Ok);
        Assert.Equal("stale ref e9", failed.Error);
    }

    [Fact]
    public void TheOpenLinkLogDoesNotRepeatTheUrl()
    {
        var device = new FakeDevice { OpenLinkResult = "opened https://secret.example/token" };
        var logs = new List<string>();
        var results = new List<DeviceResult>();

        new DeviceRequestRouter(device, results.Add, logs.Add)
            .Handle(new JsonObject
            {
                ["id"] = "d1",
                ["op"] = "openLink",
                ["url"] = "https://secret.example/token",
            });

        Assert.True(Assert.Single(results).Ok);
        Assert.DoesNotContain(logs, line => line.Contains("secret", StringComparison.Ordinal));
    }

    private sealed class FakeDevice : IDevice
    {
        public JsonObject Observation { get; set; } = new();

        public int Nodes { get; set; }

        public byte[]? Screenshot { get; set; }

        public List<DeviceApp> Applications { get; set; } = new();

        public string OpenLinkResult { get; set; } = "opened";

        public string ActResult { get; set; } = "done";

        public Exception? Failure { get; set; }

        public (JsonObject Observation, int Nodes) Observe() =>
            ThrowIfNeeded((Observation, Nodes));

        public string ForegroundApp() => ThrowIfNeeded("notepad");

        public byte[]? CaptureWindow() => ThrowIfNeeded(Screenshot);

        public List<DeviceApp> Apps() => ThrowIfNeeded(Applications);

        public string OpenLink(string url) => ThrowIfNeeded(OpenLinkResult);

        public string Act(string op, JsonObject message) => ThrowIfNeeded(ActResult);

        private T ThrowIfNeeded<T>(T value) =>
            Failure != null ? throw Failure : value;
    }
}
