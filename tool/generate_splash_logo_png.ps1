$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$svgPath = Join-Path $repoRoot 'assets\gidar_logo_splash.svg'
$outputPath = Join-Path $repoRoot 'assets\gidar_logo_mark.png'
$androidSplashPath = Join-Path $repoRoot 'android\app\src\main\res\drawable-nodpi\splash_logo.png'
$android12SplashPath = Join-Path $repoRoot 'android\app\src\main\res\drawable-nodpi\splash_logo_android12_bitmap.png'
$chromePath = @(
  'C:\Program Files\Google\Chrome\Application\chrome.exe',
  'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',
  'C:\Program Files\Microsoft\Edge\Application\msedge.exe'
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $chromePath) {
  throw 'Chrome or Edge was not found for splash logo rendering.'
}

$tempDir = Join-Path $env:TEMP 'gidar_ai_splash_logo'
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
$android12SplashTempPath = Join-Path $tempDir 'splash_logo_android12_bitmap.png'

$svgMarkup = Get-Content -Raw -LiteralPath $svgPath
$htmlPath = Join-Path $tempDir 'splash_logo.html'
$canvasWidth = 1000
$canvasHeight = 1125

$html = @"
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <style>
      html, body {
        margin: 0;
        width: ${canvasWidth}px;
        height: ${canvasHeight}px;
        overflow: hidden;
        background: transparent;
      }

      body {
        display: grid;
        place-items: center;
      }

      svg {
        width: 100%;
        height: 100%;
        display: block;
      }
    </style>
  </head>
  <body>
    $svgMarkup
  </body>
</html>
"@

Set-Content -LiteralPath $htmlPath -Value $html -Encoding UTF8

& $chromePath `
  --headless=new `
  --disable-gpu `
  --hide-scrollbars `
  --default-background-color=00000000 `
  "--window-size=$canvasWidth,$canvasHeight" `
  "--screenshot=$outputPath" `
  $htmlPath | Out-Null

if (-not (Test-Path $outputPath)) {
  throw 'Failed to render splash logo PNG.'
}

Add-Type -AssemblyName System.Drawing
$image = [System.Drawing.Bitmap]::FromFile($outputPath)
try {
  $corner = $image.GetPixel(0, 0)
  if ($corner.A -ne 0) {
    throw "Splash PNG corner alpha is $($corner.A), expected 0 for transparency."
  }
} finally {
  $image.Dispose()
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $androidSplashPath) | Out-Null
Copy-Item -LiteralPath $outputPath -Destination $androidSplashPath -Force

$source = [System.Drawing.Image]::FromFile($outputPath)
try {
  $android12Canvas = 1024
  $android12DrawWidth = 480
  $android12DrawHeight = 540
  $android12DrawX = [int](($android12Canvas - $android12DrawWidth) / 2)
  $android12DrawY = [int](($android12Canvas - $android12DrawHeight) / 2)

  $bitmap = New-Object System.Drawing.Bitmap($android12Canvas, $android12Canvas)
  try {
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
      $graphics.Clear([System.Drawing.Color]::Transparent)
      $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
      $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
      $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
      $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
      $graphics.DrawImage(
        $source,
        $android12DrawX,
        $android12DrawY,
        $android12DrawWidth,
        $android12DrawHeight
      )
    } finally {
      $graphics.Dispose()
    }
    if (Test-Path $android12SplashTempPath) {
      Remove-Item -LiteralPath $android12SplashTempPath -Force
    }
    $bitmap.Save($android12SplashTempPath, [System.Drawing.Imaging.ImageFormat]::Png)
  } finally {
    $bitmap.Dispose()
  }
} finally {
  $source.Dispose()
}

Copy-Item -LiteralPath $android12SplashTempPath -Destination $android12SplashPath -Force

Write-Host 'Transparent splash logo PNG generated successfully.'
