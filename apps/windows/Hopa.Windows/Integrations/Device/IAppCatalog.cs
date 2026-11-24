namespace Hopa.Windows.Integrations.Device;

/// <summary>The Start-menu app list an engine request can read.</summary>
public interface IAppCatalog
{
    List<DeviceApp> Apps();
}
