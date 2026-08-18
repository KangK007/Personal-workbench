Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

$projectRoot = Split-Path -Parent $PSScriptRoot
$brandingDir = Join-Path $projectRoot 'assets/branding'
$androidResDir = Join-Path $projectRoot 'android/app/src/main/res'
$windowsIconPath = Join-Path $projectRoot 'windows/runner/resources/app_icon.ico'

function New-IconBitmap([int]$size) {
    $bitmap = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.Clear([System.Drawing.Color]::Transparent)

    $scale = $size / 1024.0
    $radius = [int](224 * $scale)
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $rect = New-Object System.Drawing.Rectangle(0, 0, $size, $size)
    $diameter = $radius * 2
    $path.AddArc($rect.X, $rect.Y, $diameter, $diameter, 180, 90)
    $path.AddArc($rect.Right - $diameter, $rect.Y, $diameter, $diameter, 270, 90)
    $path.AddArc($rect.Right - $diameter, $rect.Bottom - $diameter, $diameter, $diameter, 0, 90)
    $path.AddArc($rect.X, $rect.Bottom - $diameter, $diameter, $diameter, 90, 90)
    $path.CloseFigure()
    $graphics.FillPath((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 23, 36, 35))), $path)

    $tickBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 236, 243, 240))
    foreach ($x in @(204, 354, 504)) {
        $tickRect = New-Object System.Drawing.Rectangle([int]($x * $scale), [int](248 * $scale), [int](92 * $scale), [int](280 * $scale))
        Fill-RoundedRectangle $graphics $tickBrush $tickRect ([int](46 * $scale))
    }

    $checkPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 216, 183, 94), [int](56 * $scale))
    $checkPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $checkPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $checkPen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    [System.Drawing.PointF[]]$points = @(
        (New-Object System.Drawing.PointF([float](652 * $scale), [float](650 * $scale))),
        (New-Object System.Drawing.PointF([float](720 * $scale), [float](718 * $scale))),
        (New-Object System.Drawing.PointF([float](844 * $scale), [float](578 * $scale)))
    )
    $graphics.DrawLines($checkPen, $points)

    $checkPen.Dispose(); $tickBrush.Dispose(); $path.Dispose(); $graphics.Dispose()
    return $bitmap
}

function Fill-RoundedRectangle($graphics, $brush, $rectangle, [int]$cornerRadius) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $diameter = $cornerRadius * 2
    $path.AddArc($rectangle.X, $rectangle.Y, $diameter, $diameter, 180, 90)
    $path.AddArc($rectangle.Right - $diameter, $rectangle.Y, $diameter, $diameter, 270, 90)
    $path.AddArc($rectangle.Right - $diameter, $rectangle.Bottom - $diameter, $diameter, $diameter, 0, 90)
    $path.AddArc($rectangle.X, $rectangle.Bottom - $diameter, $diameter, $diameter, 90, 90)
    $path.CloseFigure()
    $graphics.FillPath($brush, $path)
    $path.Dispose()
}

New-Item -ItemType Directory -Force $brandingDir | Out-Null
New-Item -ItemType Directory -Force $androidResDir | Out-Null

$master = New-IconBitmap 1024
$master.Save((Join-Path $brandingDir 'app_icon.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$master.Dispose()

$sizes = @{
    'mipmap-mdpi' = 48
    'mipmap-hdpi' = 72
    'mipmap-xhdpi' = 96
    'mipmap-xxhdpi' = 144
    'mipmap-xxxhdpi' = 192
}
foreach ($folder in $sizes.Keys) {
    $dir = Join-Path $androidResDir $folder
    New-Item -ItemType Directory -Force $dir | Out-Null
    $bitmap = New-IconBitmap $sizes[$folder]
    $bitmap.Save((Join-Path $dir 'ic_launcher.png'), [System.Drawing.Imaging.ImageFormat]::Png)
    $bitmap.Dispose()
}

$windowsBitmap = New-IconBitmap 256
$icon = [System.Drawing.Icon]::FromHandle($windowsBitmap.GetHicon())
$stream = [System.IO.File]::Create($windowsIconPath)
$icon.Save($stream)
$stream.Dispose(); $icon.Dispose(); $windowsBitmap.Dispose()

Write-Output "Generated app icon assets from assets/branding/app_icon_source.svg"
