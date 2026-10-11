param([Parameter(Mandatory=$true)][string]$InputJar, [string]$OutputJar)
$ErrorActionPreference = 'Stop'
$inputPath = (Resolve-Path -LiteralPath $InputJar).Path
if (-not $OutputJar) { $OutputJar = Join-Path (Split-Path $inputPath -Parent) ([IO.Path]::GetFileNameWithoutExtension($inputPath) + '-mintcraft-api-1.jar') }
$outputPath = [IO.Path]::GetFullPath($OutputJar)
if (Test-Path -LiteralPath $outputPath) { throw 'Output already exists; refusing overwrite.' }
$jdk = Join-Path $env:ProgramFiles 'Java/jdk-21/bin'
$javac = Join-Path $jdk 'javac.exe'
$java = Join-Path $jdk 'java.exe'
if (-not (Test-Path -LiteralPath $javac)) {
  $javac = (Get-Command javac -ErrorAction Stop).Source
  $java = (Get-Command java -ErrorAction Stop).Source
}
$root = Split-Path $PSScriptRoot -Parent
$classes = Join-Path $root '.tools/radar-api-patcher'
$source = Join-Path $PSScriptRoot 'radar-api-patch/RadarApiPatch.java'
$exports = @('--add-exports', 'java.base/jdk.internal.org.objectweb.asm=ALL-UNNAMED', '--add-exports', 'java.base/jdk.internal.org.objectweb.asm.tree=ALL-UNNAMED', '--add-exports', 'java.base/jdk.internal.org.objectweb.asm.tree.analysis=ALL-UNNAMED')
& $javac @exports -d $classes $source
if ($LASTEXITCODE -ne 0) { throw 'Patch compiler failed' }
& $java @exports -cp $classes RadarApiPatch $inputPath $outputPath
if ($LASTEXITCODE -ne 0) { throw 'Patch failed; original JAR was not modified' }
