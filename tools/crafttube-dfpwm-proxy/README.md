# CraftTube DFPWM Proxy

This local proxy lets MintCraft OS play CraftTube audio on a CC:Tweaked speaker.

CC:Tweaked cannot decode YouTube audio streams directly. This proxy runs on your PC, uses `yt-dlp` and `ffmpeg` to fetch/convert audio, then returns DFPWM bytes to CraftTube.

## Requirements

- Node.js 18+
- `yt-dlp` in PATH
- `ffmpeg` in PATH

Quick checks:

```powershell
node --version
yt-dlp --version
ffmpeg -version
```

## Start

From this folder:

```powershell
.\start.ps1
```

Or directly:

```powershell
npm start
```

The default URL is:

```text
http://127.0.0.1:8787
```

In Minecraft, open CraftTube, tap `Audio`, enter that URL, press Enter, then select a video and tap `Play`.

If Minecraft runs on another machine/server, replace `127.0.0.1` with the IP address of the PC running this proxy.

## API

Health:

```text
GET /health
```

DFPWM audio:

```text
GET /crafttube/audio?id=<youtube-id-or-url>
```

Optional:

```text
GET /crafttube/audio?id=<id>&seconds=180
```

`seconds` is clamped to 1-600 to avoid huge downloads.

## Custom binaries

If `yt-dlp` or `ffmpeg` are not in PATH, set:

```powershell
$env:YT_DLP_BIN="C:\path\to\yt-dlp.exe"
$env:FFMPEG_BIN="C:\path\to\ffmpeg.exe"
npm start
```
