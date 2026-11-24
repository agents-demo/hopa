namespace Hopa.Windows.Integrations.Engine;

/// <summary>The final screen's checkpoint result; null when none were requested.</summary>
public sealed record CheckpointVerification(bool Complete, IReadOnlyList<string> Missing);
