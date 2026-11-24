namespace Hopa.Windows.Integrations.Engine;

/// <summary>One action kind and how often it ran.</summary>
public sealed record UsageAction(string Kind, int Count);
