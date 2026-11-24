using System.Text.Json.Nodes;
using Hopa.Windows.Integrations.Gateway;
using Xunit;

namespace Hopa.Windows.Tests;

/// <summary>The gateway frame contract is read once and can be tested without a socket.</summary>
public sealed class GatewayFramesTests
{
    [Fact]
    public void HelloAckCarriesTheDeviceAndPeers()
    {
        var frame = GatewayFrames.Parse(new JsonObject
        {
            ["type"] = "device.hello.ack",
            ["to"] = "pc1",
            ["body"] = new JsonObject { ["peers"] = new JsonArray("phone1", "pc1") },
        });

        Assert.Equal(GatewayFrameKind.HelloAck, frame.Kind);
        Assert.Equal("pc1", frame.DeviceId);
        Assert.Equal(new[] { "phone1", "pc1" }, frame.Peers);
    }

    [Fact]
    public void PresenceCarriesTheDeviceAndTheState()
    {
        var frame = GatewayFrames.Parse(new JsonObject
        {
            ["type"] = "presence",
            ["body"] = new JsonObject { ["device"] = "phone1", ["online"] = true },
        });

        Assert.Equal(GatewayFrameKind.Presence, frame.Kind);
        Assert.Equal("phone1", frame.PresenceDevice);
        Assert.True(frame.PresenceOnline);
    }

    [Fact]
    public void PingKeepsTheSenderForThePong()
    {
        var frame = GatewayFrames.Parse(new JsonObject
        {
            ["type"] = "ping",
            ["from"] = "server",
            ["to"] = "pc1",
        });

        Assert.Equal(GatewayFrameKind.Ping, frame.Kind);
        Assert.Equal("server", frame.From);
        Assert.Equal("pc1", frame.To);
    }

    [Fact]
    public void TaskFramesReadTheTaskAndTheApprovalBody()
    {
        var ack = GatewayFrames.Parse(new JsonObject
        {
            ["type"] = "task.ack",
            ["body"] = new JsonObject { ["task"] = "t1" },
        });
        Assert.Equal(GatewayFrameKind.TaskAck, ack.Kind);
        Assert.Equal("t1", ack.TaskId);

        var result = GatewayFrames.Parse(new JsonObject
        {
            ["type"] = "task.result",
            ["from"] = "phone1",
            ["body"] = new JsonObject
            {
                ["task"] = "t1",
                ["approval"] = new JsonObject { ["allow"] = true },
            },
        });
        Assert.Equal(GatewayFrameKind.TaskResult, result.Kind);
        Assert.Equal("phone1", result.From);
        Assert.NotNull(result.Body?["approval"]);
    }

    [Fact]
    public void TheSmallFramesKeepTheirKind()
    {
        Assert.Equal(GatewayFrameKind.NeedsApproval, Kind("task.needs_approval"));
        Assert.Equal(GatewayFrameKind.TaskCreate, Kind("task.create"));
        Assert.Equal(GatewayFrameKind.Error, Kind("error"));
        Assert.Equal(GatewayFrameKind.Pong, Kind("pong"));
        Assert.Equal(GatewayFrameKind.Unknown, Kind("something.else"));
    }

    [Fact]
    public void ErrorKeepsTheServerMessageAndMissingFieldsAreNull()
    {
        var frame = GatewayFrames.Parse(new JsonObject
        {
            ["type"] = "error",
            ["body"] = new JsonObject { ["message"] = "E_AUTH" },
        });

        Assert.Equal("E_AUTH", frame.Error);

        var bare = GatewayFrames.Parse(new JsonObject { ["type"] = "presence" });
        Assert.Null(bare.PresenceDevice);
        Assert.Null(bare.TaskId);
        Assert.Null(bare.Error);
        Assert.False(bare.PresenceOnline);
    }

    private static GatewayFrameKind Kind(string type) =>
        GatewayFrames.Parse(new JsonObject { ["type"] = type }).Kind;
}
