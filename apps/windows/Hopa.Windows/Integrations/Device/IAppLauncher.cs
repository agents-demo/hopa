namespace Hopa.Windows.Integrations.Device;

/// <summary>Opening links and starting or stopping apps, without the device rules.</summary>
public interface IAppLauncher
{
    string OpenLink(string url);

    string Launch(string app);

    string Stop(string app);
}
