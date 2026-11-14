using System.IO;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;

namespace Hopa.Windows;

public static class WindowShot
{
    public static void Save(Window window, string path)
    {
        window.UpdateLayout();
        var width = (int)Math.Max(window.ActualWidth, 1);
        var height = (int)Math.Max(window.ActualHeight, 1);
        var bitmap = new RenderTargetBitmap(width, height, 96, 96, PixelFormats.Pbgra32);
        bitmap.Render(window);
        var encoder = new PngBitmapEncoder();
        encoder.Frames.Add(BitmapFrame.Create(bitmap));
        using var stream = File.Create(path);
        encoder.Save(stream);
    }
}
