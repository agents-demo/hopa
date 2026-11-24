using System.Text.Json.Nodes;

namespace Hopa.Windows.Gateway;

/// <summary>The phone half of approval, as the router needs it.</summary>
public interface IApprovalPhone
{
    bool IsLive { get; }

    string PhoneDeviceId { get; }

    Task<JsonObject?> RequestApprovalAsync(
        JsonObject approval,
        string phoneDeviceId,
        TimeSpan timeout);
}
