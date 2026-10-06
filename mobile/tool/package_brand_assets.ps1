# Rebuild launcher assets from the existing brand image; no artwork is changed.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$mobileRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$sourceImage = [Drawing.Image]::FromFile((Join-Path $mobileRoot 'assets\advise_logo.jpg'))

function Get-BrandPng([int]$size, [double]$fill = 0.94) {
    $bitmap = [Drawing.Bitmap]::new($size, $size)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    $stream = [IO.MemoryStream]::new()
    try {
        $graphics.Clear([Drawing.Color]::White)
        $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::HighQuality
        $side = [int]($size * $fill)
        $offset = [int](($size - $side) / 2)
        $graphics.DrawImage($sourceImage, $offset, $offset, $side, $side)
        $bitmap.Save($stream, [Drawing.Imaging.ImageFormat]::Png)
        return ,$stream.ToArray()
    } finally {
        $stream.Dispose()
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}

try {
    foreach ($size in @(192, 512)) {
        [IO.File]::WriteAllBytes((Join-Path $mobileRoot "web\icons\Icon-$size.png"), (Get-BrandPng $size))
        [IO.File]::WriteAllBytes((Join-Path $mobileRoot "web\icons\Icon-maskable-$size.png"), (Get-BrandPng $size 0.76))
    }
    [IO.File]::WriteAllBytes((Join-Path $mobileRoot 'web\favicon.png'), (Get-BrandPng 64))

    $densities = @{'mdpi' = 48; 'hdpi' = 72; 'xhdpi' = 96; 'xxhdpi' = 144; 'xxxhdpi' = 192}
    foreach ($density in $densities.Keys) {
        foreach ($filename in @('ic_launcher.png', 'ic_launcher_round.png')) {
            [IO.File]::WriteAllBytes((Join-Path $mobileRoot "android\app\src\main\res\mipmap-$density\$filename"), (Get-BrandPng $densities[$density]))
        }
    }

    # Windows supports PNG entries inside ICO. Supply multiple resolutions so
    # the icon remains crisp in the taskbar and Explorer at every scale.
    $iconSizes = @(32, 48, 64, 128, 256)
    $iconImages = @($iconSizes | ForEach-Object { ,(Get-BrandPng $_) })
    $iconStream = [IO.MemoryStream]::new()
    $writer = [IO.BinaryWriter]::new($iconStream)
    try {
        $writer.Write([UInt16]0)
        $writer.Write([UInt16]1)
        $writer.Write([UInt16]$iconSizes.Count)
        $offset = 6 + 16 * $iconSizes.Count
        for ($index = 0; $index -lt $iconSizes.Count; $index++) {
            $dimension = if ($iconSizes[$index] -eq 256) { 0 } else { $iconSizes[$index] }
            $writer.Write([Byte]$dimension)
            $writer.Write([Byte]$dimension)
            $writer.Write([Byte]0)
            $writer.Write([Byte]0)
            $writer.Write([UInt16]1)
            $writer.Write([UInt16]32)
            $writer.Write([UInt32]$iconImages[$index].Length)
            $writer.Write([UInt32]$offset)
            $offset += $iconImages[$index].Length
        }
        foreach ($png in $iconImages) { $writer.Write([Byte[]]$png) }
        $writer.Flush()
        [IO.File]::WriteAllBytes((Join-Path $mobileRoot 'windows\runner\resources\app_icon.ico'), $iconStream.ToArray())
    } finally {
        $writer.Dispose()
        $iconStream.Dispose()
    }
    Write-Output 'AdVise launcher assets generated from the existing logo.'
} finally {
    $sourceImage.Dispose()
}
