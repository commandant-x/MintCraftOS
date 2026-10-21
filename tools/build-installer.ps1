$ErrorActionPreference = 'Stop'
# One deterministic builder for Windows and Unix; includes lossless source packing.
$python = Get-Command python3, python -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $python) { throw 'Python 3 is required: run python tools/build-installer.py.' }
& $python.Source (Join-Path $PSScriptRoot 'build-installer.py')
if ($LASTEXITCODE -ne 0) { throw 'Installer generation failed.' }
