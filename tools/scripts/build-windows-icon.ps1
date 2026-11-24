param(
    [string]$Source = "apps/windows/Hopa.Windows/Assets/mascot.png",
    [string]$Output = "apps/windows/Hopa.Windows/Assets/hopa.ico"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$sourcePath = if ([System.IO.Path]::IsPathRooted($Source)) { $Source } else { Join-Path $root $Source }
$outputPath = if ([System.IO.Path]::IsPathRooted($Output)) { $Output } else { Join-Path $root $Output }

Add-Type -AssemblyName System.Drawing

$bitmapSource = [System.Drawing.Bitmap]::FromFile($sourcePath)
try {
    # 16-64 use the face so the icon still reads in the title bar and tray;
    # 128/256 use the full character where there is room.
    $frames = @()
    foreach ($size in @(16, 20, 24, 32, 40, 48, 64, 128, 256)) {
        $head = $size -le 64
        $cropX = if ($head) { 90 } else { 8 }
        $cropY = if ($head) { 20 } else { 0 }
        $cropSize = if ($head) { 332 } else { 496 }

        $bitmap = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        try {
            $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
            try {
                $graphics.Clear([System.Drawing.Color]::Transparent)
                $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

                $clip = New-Object System.Drawing.Drawing2D.GraphicsPath
                try {
                    $clip.AddEllipse(0, 0, $size - 1, $size - 1)
                    $graphics.SetClip($clip)
                    $destination = New-Object System.Drawing.Rectangle(0, 0, $size, $size)
                    $crop = New-Object System.Drawing.Rectangle($cropX, $cropY, $cropSize, $cropSize)
                    $graphics.DrawImage($bitmapSource, $destination, $crop, [System.Drawing.GraphicsUnit]::Pixel)
                }
                finally {
                    $clip.Dispose()
                }
            }
            finally {
                $graphics.Dispose()
            }

            $stream = New-Object System.IO.MemoryStream
            try {
                $bitmap.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
                $frames += [pscustomobject]@{
                    Size = $size
                    Bytes = $stream.ToArray()
                }
            }
            finally {
                $stream.Dispose()
            }
        }
        finally {
            $bitmap.Dispose()
        }
    }
}
finally {
    $bitmapSource.Dispose()
}

$file = [System.IO.File]::Create($outputPath)
try {
    $writer = New-Object System.IO.BinaryWriter($file)
    try {
        $writer.Write([uint16]0)             # reserved
        $writer.Write([uint16]1)             # icon
        $writer.Write([uint16]$frames.Count)

        $offset = 6 + 16 * $frames.Count
        foreach ($frame in $frames) {
            $dimension = if ($frame.Size -ge 256) { 0 } else { $frame.Size }
            $writer.Write([byte]$dimension)
            $writer.Write([byte]$dimension)
            $writer.Write([byte]0)           # palette size
            $writer.Write([byte]0)           # reserved
            $writer.Write([uint16]1)         # planes
            $writer.Write([uint16]32)        # bits per pixel
            $writer.Write([uint32]$frame.Bytes.Length)
            $writer.Write([uint32]$offset)
            $offset += $frame.Bytes.Length
        }

        foreach ($frame in $frames) {
            $writer.Write($frame.Bytes)
        }
    }
    finally {
        $writer.Dispose()
    }
}
finally {
    $file.Dispose()
}

Write-Host "icon: $outputPath ($($frames.Count) frames)"
