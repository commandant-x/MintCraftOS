$ErrorActionPreference = "Stop"

function Test-Command($Name) {
  $cmd = Get-Command $Name -ErrorAction SilentlyContinue
  return $null -ne $cmd
}

if (-not (Test-Command "node")) {
  Write-Host "Node.js is missing. Install Node.js 18+ first." -ForegroundColor Red
  exit 1
}

if (-not (Test-Command "ffmpeg")) {
  Write-Host "ffmpeg is missing. Install ffmpeg and make sure it is in PATH." -ForegroundColor Red
  exit 1
}

if (-not (Test-Command "yt-dlp")) {
  Write-Host "yt-dlp is missing." -ForegroundColor Yellow
  Write-Host "Install it with:" -ForegroundColor Yellow
  Write-Host "  py -m pip install -U yt-dlp" -ForegroundColor Cyan
  Write-Host "Then restart this script." -ForegroundColor Yellow
  exit 1
}

npm start
