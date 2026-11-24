namespace Hopa.Windows.Integrations.Engine;

/// <summary>The usage counters the Android usage screen shows.</summary>
public sealed record UsageSummary(
    int Total,
    int Executed,
    int Failed,
    int Payments,
    int LastSevenDays,
    IReadOnlyList<UsageAction> TopActions);
