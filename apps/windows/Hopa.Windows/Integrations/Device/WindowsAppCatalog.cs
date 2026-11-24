using System.IO;

namespace Hopa.Windows.Integrations.Device;

/// <summary>
/// The apps a person can actually start, read from the Start menu shortcuts. A
/// shortcut is only offered when its target exists and is an executable; the
/// list is cached for a minute because the shell walk is not free.
/// </summary>
internal sealed class WindowsAppCatalog : IAppCatalog
{
    private List<DeviceApp>? cache;
    private DateTime cachedAt;

    public List<DeviceApp> Apps()
    {
        if (cache != null && DateTime.UtcNow - cachedAt < TimeSpan.FromMinutes(1))
        {
            return cache;
        }

        var found = new Dictionary<string, DeviceApp>(StringComparer.OrdinalIgnoreCase);
        object? shell = null;
        try
        {
            var type = System.Type.GetTypeFromProgID("WScript.Shell");
            shell = type == null ? null : Activator.CreateInstance(type);
            foreach (var root in StartMenuRoots())
            {
                if (!Directory.Exists(root))
                {
                    continue;
                }

                IEnumerable<string> files;
                try
                {
                    files = Directory.GetFiles(root, "*.lnk", SearchOption.AllDirectories);
                }
                catch
                {
                    continue;
                }

                foreach (var file in files)
                {
                    try
                    {
                        var label = Path.GetFileNameWithoutExtension(file);
                        if (label.Length == 0 ||
                            label.Contains("uninstall", StringComparison.OrdinalIgnoreCase))
                        {
                            continue;
                        }

                        var target = ShortcutTarget(shell, file);
                        if (target.Length == 0 ||
                            !target.EndsWith(".exe", StringComparison.OrdinalIgnoreCase) ||
                            !File.Exists(target))
                        {
                            continue;
                        }

                        found.TryAdd(target, new DeviceApp(target, label));
                    }
                    catch
                    {
                        // One broken shortcut is not a reason to lose the list.
                    }
                }
            }
        }
        finally
        {
            if (shell != null)
            {
                System.Runtime.InteropServices.Marshal.ReleaseComObject(shell);
            }
        }

        cache = found.Values
            .OrderBy(entry => entry.Label, StringComparer.CurrentCultureIgnoreCase)
            .Take(200)
            .ToList();
        cachedAt = DateTime.UtcNow;
        return cache;
    }

    private static IEnumerable<string> StartMenuRoots()
    {
        yield return Environment.GetFolderPath(Environment.SpecialFolder.CommonStartMenu);
        yield return Environment.GetFolderPath(Environment.SpecialFolder.StartMenu);
    }

    private static string ShortcutTarget(object? shell, string path)
    {
        if (shell == null)
        {
            return "";
        }

        try
        {
            // dynamic, not reflection: a shortcut is a COM object reached through
            // IDispatch, and InvokeMember on the RCW does not dispatch it.
            dynamic dynamicShell = shell;
            dynamic shortcut = dynamicShell.CreateShortcut(path);
            var target = (string)(shortcut.TargetPath ?? "");
            System.Runtime.InteropServices.Marshal.ReleaseComObject(shortcut);
            return target;
        }
        catch
        {
            return "";
        }
    }
}
