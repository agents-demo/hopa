using System.IO;
using System.Text;
using NAudio.Wave;

namespace Hopa.Windows.Voice;

/// <summary>PCM in, a 44-byte RIFF/WAVE container out.</summary>
internal static class WavFile
{
    public static byte[] FromPcm(byte[] pcm, WaveFormat format)
    {
        using var output = new MemoryStream();
        using var writer = new BinaryWriter(output, Encoding.ASCII, leaveOpen: true);
        var blockAlign = (short)(format.Channels * format.BitsPerSample / 8);
        var byteRate = format.SampleRate * blockAlign;
        writer.Write(Encoding.ASCII.GetBytes("RIFF"));
        writer.Write(36 + pcm.Length);
        writer.Write(Encoding.ASCII.GetBytes("WAVE"));
        writer.Write(Encoding.ASCII.GetBytes("fmt "));
        writer.Write(16);
        writer.Write((short)1);
        writer.Write((short)format.Channels);
        writer.Write(format.SampleRate);
        writer.Write(byteRate);
        writer.Write(blockAlign);
        writer.Write((short)format.BitsPerSample);
        writer.Write(Encoding.ASCII.GetBytes("data"));
        writer.Write(pcm.Length);
        writer.Write(pcm);
        writer.Flush();
        return output.ToArray();
    }
}
