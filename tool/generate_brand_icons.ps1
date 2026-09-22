# Generate launcher / favicon / splash bitmaps from the uploaded company logo.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$root = Split-Path $PSScriptRoot -Parent
$src = 'C:\Users\hp\.cursor\projects\c-Users-hp-Downloads-united-kites-main-united-kites-main\assets\c__Users_hp_AppData_Roaming_Cursor_User_workspaceStorage_90dce0389114acffdbca8aff7faa6d21_images_logo.jpg-834e001c-6ce6-4739-8ac4-b71b7a332950.jpg'
if (-not (Test-Path $src)) { throw "Source logo not found: $src" }

$assets = Join-Path $root 'assets'
New-Item -ItemType Directory -Force -Path $assets | Out-Null
Copy-Item -Force $src (Join-Path $assets 'logo.jpg')

$srcImg = [System.Drawing.Image]::FromFile($src)
$side = [Math]::Max($srcImg.Width, $srcImg.Height)
$master = New-Object System.Drawing.Bitmap $side, $side
$mg = [System.Drawing.Graphics]::FromImage($master)
$mg.Clear([System.Drawing.Color]::White)
$mg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$mg.DrawImage($srcImg, [int](($side - $srcImg.Width) / 2), [int](($side - $srcImg.Height) / 2), $srcImg.Width, $srcImg.Height)
$mg.Dispose()
$srcImg.Dispose()

function Save-Png([System.Drawing.Bitmap]$srcBmp, [string]$path, [int]$size, [switch]$Maskable) {
    New-Item -ItemType Directory -Force -Path (Split-Path $path) | Out-Null
    $bmp = New-Object System.Drawing.Bitmap $size, $size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear([System.Drawing.Color]::White)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    if ($Maskable) {
        $inner = [int]($size * 0.72)
        $off = [int](($size - $inner) / 2)
        $g.DrawImage($srcBmp, $off, $off, $inner, $inner)
    } else {
        $g.DrawImage($srcBmp, 0, 0, $size, $size)
    }
    $g.Dispose()
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}

function Save-Ico([System.Drawing.Bitmap]$srcBmp, [string]$path, [int[]]$sizes) {
    New-Item -ItemType Directory -Force -Path (Split-Path $path) | Out-Null
    $pngs = @()
    foreach ($s in $sizes) {
        $ms = New-Object System.IO.MemoryStream
        $bmp = New-Object System.Drawing.Bitmap $s, $s
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.Clear([System.Drawing.Color]::White)
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.DrawImage($srcBmp, 0, 0, $s, $s)
        $g.Dispose()
        $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
        $bmp.Dispose()
        $pngs += , $ms.ToArray()
        $ms.Dispose()
    }
    $count = $pngs.Count
    $offset = 6 + (16 * $count)
    $fs = [System.IO.File]::Open($path, [System.IO.FileMode]::Create)
    $bw = New-Object System.IO.BinaryWriter $fs
    $bw.Write([uint16]0)
    $bw.Write([uint16]1)
    $bw.Write([uint16]$count)
    foreach ($i in 0..($count - 1)) {
        $s = $sizes[$i]
        $dim = 0
        if ($s -lt 256) { $dim = $s }
        $bw.Write([byte]$dim)
        $bw.Write([byte]$dim)
        $bw.Write([byte]0)
        $bw.Write([byte]0)
        $bw.Write([uint16]1)
        $bw.Write([uint16]32)
        $bw.Write([uint32]$pngs[$i].Length)
        $bw.Write([uint32]$offset)
        $offset += $pngs[$i].Length
    }
    foreach ($bytes in $pngs) { $bw.Write($bytes) }
    $bw.Flush()
    $fs.Close()
}

$android = Join-Path $root 'android\app\src\main\res'
$map = @{
    'mipmap-mdpi' = 48
    'mipmap-hdpi' = 72
    'mipmap-xhdpi' = 96
    'mipmap-xxhdpi' = 144
    'mipmap-xxxhdpi' = 192
}
foreach ($folder in $map.Keys) {
    $size = $map[$folder]
    Save-Png $master (Join-Path $android "$folder\ic_launcher.png") $size
    Save-Png $master (Join-Path $android "$folder\ic_launcher_foreground.png") $size
}
Save-Png $master (Join-Path $android 'mipmap-xxxhdpi\ic_launcher_foreground.png') 432
Save-Png $master (Join-Path $android 'drawable\splash_logo.png') 320

$web = Join-Path $root 'web'
Save-Png $master (Join-Path $web 'favicon.png') 32
Save-Png $master (Join-Path $web 'icons\Icon-192.png') 192
Save-Png $master (Join-Path $web 'icons\Icon-512.png') 512
Save-Png $master (Join-Path $web 'icons\Icon-maskable-192.png') 192 -Maskable
Save-Png $master (Join-Path $web 'icons\Icon-maskable-512.png') 512 -Maskable

$ios = Join-Path $root 'ios\Runner\Assets.xcassets\AppIcon.appiconset'
$iosSizes = @{
    'Icon-App-20x20@1x.png' = 20
    'Icon-App-20x20@2x.png' = 40
    'Icon-App-20x20@3x.png' = 60
    'Icon-App-29x29@1x.png' = 29
    'Icon-App-29x29@2x.png' = 58
    'Icon-App-29x29@3x.png' = 87
    'Icon-App-40x40@1x.png' = 40
    'Icon-App-40x40@2x.png' = 80
    'Icon-App-40x40@3x.png' = 120
    'Icon-App-60x60@2x.png' = 120
    'Icon-App-60x60@3x.png' = 180
    'Icon-App-76x76@1x.png' = 76
    'Icon-App-76x76@2x.png' = 152
    'Icon-App-83.5x83.5@2x.png' = 167
    'Icon-App-1024x1024@1x.png' = 1024
}
foreach ($name in $iosSizes.Keys) {
    Save-Png $master (Join-Path $ios $name) $iosSizes[$name]
}

$launch = Join-Path $root 'ios\Runner\Assets.xcassets\LaunchImage.imageset'
Save-Png $master (Join-Path $launch 'LaunchImage.png') 200
Save-Png $master (Join-Path $launch 'LaunchImage@2x.png') 400
Save-Png $master (Join-Path $launch 'LaunchImage@3x.png') 600

$mac = Join-Path $root 'macos\Runner\Assets.xcassets\AppIcon.appiconset'
foreach ($size in 16, 32, 64, 128, 256, 512, 1024) {
    Save-Png $master (Join-Path $mac "app_icon_$size.png") $size
}

Save-Ico $master (Join-Path $root 'windows\runner\resources\app_icon.ico') @(16, 24, 32, 48, 64, 128, 256)
$master.Dispose()
Write-Output 'Wrote brand icons'
