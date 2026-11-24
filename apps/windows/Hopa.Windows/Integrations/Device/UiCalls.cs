using System.Runtime.ExceptionServices;

namespace Hopa.Windows.Integrations.Device;

/// <summary>
/// UI Automation is a cross-process call: a provider can hang. Every read and
/// action gets a deadline so the turn reports a timeout instead of freezing.
/// </summary>
internal static class UiCalls
{
    public static readonly TimeSpan CallTimeout = TimeSpan.FromMilliseconds(1500);
    public static readonly TimeSpan PropertyTimeout = TimeSpan.FromMilliseconds(700);

    public static T Call<T>(Func<T> work, string what, TimeSpan? timeout = null)
    {
        var task = Task.Run(work);
        try
        {
            if (!task.Wait(timeout ?? CallTimeout))
            {
                throw new TimeoutException(
                    $"UI Automation did not answer '{what}' within {(timeout ?? CallTimeout).TotalMilliseconds:0} ms");
            }
        }
        catch (AggregateException error) when (error.InnerException != null)
        {
            // A provider failure is the caller's answer, not an AggregateException
            // it would have to unwrap (the input fallback depends on this).
            ExceptionDispatchInfo.Capture(error.InnerException).Throw();
            throw;
        }

        return task.GetAwaiter().GetResult();
    }

    public static void Call(Action work, string what, TimeSpan? timeout = null) =>
        Call(() =>
        {
            work();
            return true;
        }, what, timeout);

    public static T Property<T>(Func<T> read, T fallback) =>
        Call(read, "a property read", PropertyTimeout) is { } value ? value : fallback;
}
