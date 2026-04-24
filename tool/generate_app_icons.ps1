$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$svgPath = Join-Path $repoRoot 'assets\gidar_logo.svg'
$chromePath = @(
  'C:\Program Files\Google\Chrome\Application\chrome.exe',
  'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',
  'C:\Program Files\Microsoft\Edge\Application\msedge.exe'
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $chromePath) {
  throw 'Chrome or Edge was not found for icon rendering.'
}

$tempDir = Join-Path $env:TEMP 'gidar_ai_icon_build'
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

$svgMarkup = Get-Content -Raw -LiteralPath $svgPath
$htmlPath = Join-Path $tempDir 'icon_canvas.html'
$basePngPath = Join-Path $tempDir 'icon_1024.png'
$foregroundHtmlPath = Join-Path $tempDir 'icon_foreground_canvas.html'
$foregroundPngPath = Join-Path $tempDir 'icon_foreground_432.png'
$monochromeHtmlPath = Join-Path $tempDir 'icon_monochrome_canvas.html'
$monochromePngPath = Join-Path $tempDir 'icon_monochrome_432.png'

$html = @"
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <style>
      html, body {
        margin: 0;
        width: 1024px;
        height: 1024px;
        overflow: hidden;
        background: #F6F8FC;
      }

      body {
        display: grid;
        place-items: center;
      }

      .icon-shell {
        width: 1024px;
        height: 1024px;
        display: grid;
        place-items: center;
      }

      .icon-shell > svg {
        width: 54%;
        height: 54%;
        display: block;
      }
    </style>
  </head>
  <body>
    <div class="icon-shell">
      $svgMarkup
    </div>
  </body>
</html>
"@

Set-Content -LiteralPath $htmlPath -Value $html -Encoding UTF8

$foregroundHtml = @"
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <style>
      html, body {
        margin: 0;
        width: 432px;
        height: 432px;
        overflow: hidden;
        background: transparent;
      }

      body {
        display: grid;
        place-items: center;
      }

      svg {
        width: 56%;
        height: 56%;
        display: block;
      }
    </style>
  </head>
  <body>
    $svgMarkup
  </body>
</html>
"@

Set-Content -LiteralPath $foregroundHtmlPath -Value $foregroundHtml -Encoding UTF8

$monochromeHtml = @"
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <style>
      html, body {
        margin: 0;
        width: 432px;
        height: 432px;
        overflow: hidden;
        background: transparent;
      }

      body {
        display: grid;
        place-items: center;
      }

      svg {
        width: 56%;
        height: 56%;
        display: block;
        filter: brightness(0) saturate(100%);
      }
    </style>
  </head>
  <body>
    $svgMarkup
  </body>
</html>
"@

Set-Content -LiteralPath $monochromeHtmlPath -Value $monochromeHtml -Encoding UTF8

& $chromePath `
  --headless=new `
  --disable-gpu `
  --hide-scrollbars `
  --force-device-scale-factor=1 `
  --window-size=1024,1024 `
  "--screenshot=$basePngPath" `
  $htmlPath | Out-Null

& $chromePath `
  --headless=new `
  --disable-gpu `
  --hide-scrollbars `
  --default-background-color=00000000 `
  --force-device-scale-factor=1 `
  --window-size=432,432 `
  "--screenshot=$foregroundPngPath" `
  $foregroundHtmlPath | Out-Null

& $chromePath `
  --headless=new `
  --disable-gpu `
  --hide-scrollbars `
  --default-background-color=00000000 `
  --force-device-scale-factor=1 `
  --window-size=432,432 `
  "--screenshot=$monochromePngPath" `
  $monochromeHtmlPath | Out-Null

if (-not (Test-Path $basePngPath) -or
    -not (Test-Path $foregroundPngPath) -or
    -not (Test-Path $monochromePngPath)) {
  throw 'Failed to render icon assets.'
}

Add-Type -AssemblyName System.Drawing

function Save-ScaledPng {
  param(
    [string]$SourcePath,
    [string]$DestinationPath,
    [int]$Size
  )

  $source = [System.Drawing.Image]::FromFile($SourcePath)
  try {
    $bitmap = New-Object System.Drawing.Bitmap($Size, $Size)
    try {
      $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
      try {
        $graphics.Clear([System.Drawing.Color]::FromArgb(246, 248, 252))
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.DrawImage($source, 0, 0, $Size, $Size)
      } finally {
        $graphics.Dispose()
      }

      $directory = Split-Path -Parent $DestinationPath
      if (-not (Test-Path $directory)) {
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
      }
      $bitmap.Save($DestinationPath, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
      $bitmap.Dispose()
    }
  } finally {
    $source.Dispose()
  }
}

$androidTargets = @{
  'android\app\src\main\res\mipmap-mdpi\ic_launcher.png' = 48
  'android\app\src\main\res\mipmap-hdpi\ic_launcher.png' = 72
  'android\app\src\main\res\mipmap-xhdpi\ic_launcher.png' = 96
  'android\app\src\main\res\mipmap-xxhdpi\ic_launcher.png' = 144
  'android\app\src\main\res\mipmap-xxxhdpi\ic_launcher.png' = 192
}

foreach ($target in $androidTargets.GetEnumerator()) {
  Save-ScaledPng -SourcePath $basePngPath -DestinationPath (Join-Path $repoRoot $target.Key) -Size $target.Value
}

$androidForegroundDir = Join-Path $repoRoot 'android\app\src\main\res\drawable-nodpi'
New-Item -ItemType Directory -Force -Path $androidForegroundDir | Out-Null
Copy-Item -LiteralPath $foregroundPngPath -Destination (Join-Path $androidForegroundDir 'ic_launcher_foreground.png') -Force
Copy-Item -LiteralPath $monochromePngPath -Destination (Join-Path $androidForegroundDir 'ic_launcher_monochrome.png') -Force

$iosTargets = @{
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

$iosIconDir = Join-Path $repoRoot 'ios\Runner\Assets.xcassets\AppIcon.appiconset'
foreach ($target in $iosTargets.GetEnumerator()) {
  Save-ScaledPng -SourcePath $basePngPath -DestinationPath (Join-Path $iosIconDir $target.Key) -Size $target.Value
}

Write-Host 'App icons generated successfully.'
