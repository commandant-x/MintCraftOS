"use strict";

const http = require("node:http");
const { spawn } = require("node:child_process");

const PORT = Number(process.env.PORT || 8787);
const HOST = process.env.HOST || "127.0.0.1";
const DEFAULT_SECONDS = Number(process.env.MAX_SECONDS || 240);
const YT_DLP_BIN = process.env.YT_DLP_BIN || "yt-dlp";
const FFMPEG_BIN = process.env.FFMPEG_BIN || "ffmpeg";

function send(res, code, body, type = "text/plain; charset=utf-8") {
  if (res.destroyed || res.writableEnded) return;
  const data = Buffer.isBuffer(body) ? body : Buffer.from(String(body));
  res.writeHead(code, {
    "Content-Type": type,
    "Content-Length": data.length,
    "Access-Control-Allow-Origin": "*",
    "Cache-Control": "no-store",
  });
  res.end(data);
}

function clampSeconds(value) {
  const parsed = Number(value || DEFAULT_SECONDS);
  if (!Number.isFinite(parsed)) return 240;
  return Math.max(1, Math.min(600, Math.floor(parsed)));
}

function youtubeUrl(id) {
  id = String(id || "").trim();
  if (!id || id.length > 2048) return null;
  if (/^https?:\/\//i.test(id)) {
    let parsed;
    try { parsed = new URL(id); } catch { return null; }
    if (parsed.username || parsed.password || parsed.port) return null;
    if (parsed.hostname === "youtu.be") {
      if (!/^\/[A-Za-z0-9_-]{11}$/.test(parsed.pathname)) return null;
      id = parsed.pathname.slice(1);
    } else if (["youtube.com", "www.youtube.com", "m.youtube.com", "music.youtube.com"].includes(parsed.hostname)) {
      if (parsed.pathname === "/watch") id = parsed.searchParams.get("v") || "";
      else {
        const match = parsed.pathname.match(/^\/(?:shorts|embed|live)\/([A-Za-z0-9_-]{11})$/);
        if (!match) return null;
        id = match[1];
      }
    } else return null;
  }
  if (!/^[A-Za-z0-9_-]{11}$/.test(id)) return null;
  return `https://www.youtube.com/watch?v=${id}`;
}

function audioToPcm(url, seconds, { spawnFn = spawn, signal, timeoutMs = 120000 } = {}) {
  seconds = clampSeconds(seconds);
  if (!youtubeUrl(url)) return Promise.reject(new Error("Invalid YouTube URL"));
  url = youtubeUrl(url);
  return new Promise((resolve, reject) => {
    const children = [];
    let done = false, size = 0, inputBytes = 0, sourceCode = null;
    const pcm = Buffer.alloc(seconds * 48000);
    const finish = (err) => {
      if (done) return;
      done = true;
      clearTimeout(timer);
      signal?.removeEventListener("abort", abort);
      for (const child of children) {
        child.stdout?.unpipe();
        child.stdin?.destroy();
        child.stdout?.destroy();
        child.stderr?.destroy();
        if (child.exitCode == null && !child.killed) child.kill("SIGKILL");
      }
      if (err) reject(err); else resolve(pcm.subarray(0, size));
    };
    const abort = () => finish(new Error("Conversion aborted"));
    const timer = setTimeout(() => finish(new Error("Conversion timed out")), timeoutMs);
    signal?.addEventListener("abort", abort, { once: true });
    if (signal?.aborted) { abort(); return; }
    try {
      const ytdlp = spawnFn(YT_DLP_BIN, ["--ignore-config", "--no-playlist", "--quiet", "--no-warnings",
        "--socket-timeout", "20", "--retries", "1", "-f", "bestaudio/best", "-o", "-", "--", url],
      { stdio: ["ignore", "pipe", "pipe"], windowsHide: true });
      children.push(ytdlp);
      ytdlp.on("error", () => finish(new Error("Downloader failed to start")));
      const ffmpeg = spawnFn(FFMPEG_BIN, ["-hide_banner", "-loglevel", "error", "-protocol_whitelist", "pipe",
        "-i", "pipe:0", "-t", String(seconds), "-ac", "1", "-ar", "48000", "-f", "s8", "pipe:1"],
      { stdio: ["pipe", "pipe", "pipe"], windowsHide: true });
      children.push(ffmpeg);
      ffmpeg.on("error", () => finish(new Error("Converter failed to start")));
      for (const child of children) {
        // Drain diagnostics without retaining attacker-controlled output in memory.
        child.stderr.on("data", () => {});
        child.stderr.on("error", () => finish(new Error("Diagnostic stream failed")));
        child.stdout.on("error", () => finish(new Error("Output stream failed")));
      }
      ytdlp.on("close", code => { sourceCode = code; });
      ytdlp.stdout.on("data", chunk => {
        inputBytes += chunk.length;
        if (inputBytes > 64 * 1024 * 1024) finish(new Error("Download byte limit exceeded"));
      });
      ffmpeg.stdin.on("error", err => {
        // ffmpeg may close its input after reaching -t. Its exit code decides success.
        if (err.code !== "EPIPE") finish(new Error("Converter input failed"));
      });
      ffmpeg.stdout.on("data", chunk => {
        if (done) return;
        if (size + chunk.length > pcm.length) { finish(new Error("PCM byte limit exceeded")); return; }
        chunk.copy(pcm, size);
        size += chunk.length;
      });
      ffmpeg.on("close", code => {
        if (code !== 0 || !size || (sourceCode !== null && sourceCode !== 0 && size < pcm.length)) {
          finish(new Error("Audio conversion failed"));
        } else finish();
      });
      ytdlp.stdout.pipe(ffmpeg.stdin);
    } catch (err) { finish(err); }
  });
}

function clampByte(value) {
  if (value < -128) return -128;
  if (value > 127) return 127;
  return value;
}

function encodeDfpwm(pcm) {
  let charge = 0;
  let strength = 2;
  let previousBit = false;
  let outByte = 0;
  let outBits = 0;
  const out = Buffer.alloc(Math.ceil(pcm.length / 8));
  let outputIndex = 0;

  for (let i = 0; i < pcm.length; i += 1) {
    const sample = pcm.readInt8(i);
    const bit = sample > charge || (sample === charge && charge === 127);
    const target = bit ? 127 : -128;
    const nextCharge = clampByte(charge + Math.trunc((strength * (target - charge) + 128) / 256));

    if (nextCharge === charge && nextCharge !== target) {
      charge += bit ? 1 : -1;
    } else {
      charge = nextCharge;
    }

    const z = bit === previousBit ? 255 : 0;
    strength += Math.trunc((z - strength + 128) / 256);
    if (strength < 2) strength = 2;
    previousBit = bit;

    if (bit) outByte |= (1 << outBits);
    outBits += 1;
    if (outBits === 8) {
      out[outputIndex++] = outByte;
      outByte = 0;
      outBits = 0;
    }
  }

  if (outBits > 0) out[outputIndex] = outByte;
  return out;
}

async function handleAudio(req, res, url, options) {
  const id = url.searchParams.get("id") || url.searchParams.get("url");
  const target = youtubeUrl(id);
  if (!target) {
    send(res, 400, "Missing or invalid id/url");
    return;
  }

  const seconds = clampSeconds(url.searchParams.get("seconds"));
  const controller = new AbortController();
  const abort = () => controller.abort();
  const close = () => { if (!res.writableEnded) abort(); };
  req.once("aborted", abort);
  res.once("close", close);
  try {
    const pcm = await audioToPcm(target, seconds, { ...options, signal: controller.signal });
    if (controller.signal.aborted) return;
    const dfpwm = encodeDfpwm(pcm);
    // Keep the concurrency slot until a slow client's output is flushed or closed.
    const flushed = new Promise(resolve => {
      const complete = () => {
        res.removeListener("finish", complete);
        res.removeListener("close", complete);
        resolve();
      };
      res.once("finish", complete);
      res.once("close", complete);
    });
    send(res, 200, dfpwm, "audio/dfpwm");
    await flushed;
  } catch (err) {
    send(res, 500, `DFPWM conversion failed: ${err.message}`);
  } finally {
    req.removeListener("aborted", abort);
    res.removeListener("close", close);
  }
}

function createServer(options = {}) {
  let active = 0;
  const server = http.createServer((req, res) => {
  if (req.method !== "GET") { send(res, 405, "GET required"); return; }
  let url;
  try { url = new URL(req.url, "http://localhost"); } catch { send(res, 400, "Invalid URL"); return; }
  if (url.pathname === "/health") {
    send(res, 200, JSON.stringify({ ok: true, service: "crafttube-dfpwm-proxy" }), "application/json");
    return;
  }
  if (url.pathname === "/crafttube/audio") {
    if (active >= 2) { send(res, 503, "Conversion capacity reached"); return; }
    active += 1;
    handleAudio(req, res, url, options).catch(() => send(res, 500, "Conversion failed")).finally(() => { active -= 1; });
    return;
  }
  send(res, 404, "Not found");
});
  server.requestTimeout = 15000;
  server.headersTimeout = 10000;
  server.timeout = 135000;
  return server;
}

if (require.main === module) createServer().listen(PORT, HOST, () => {
  console.log(`CraftTube DFPWM proxy listening on http://${HOST}:${PORT}`);
});

module.exports = { createServer, youtubeUrl, clampSeconds, audioToPcm, encodeDfpwm };
