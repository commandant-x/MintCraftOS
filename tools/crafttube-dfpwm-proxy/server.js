"use strict";

const http = require("node:http");
const { spawn } = require("node:child_process");

const PORT = Number(process.env.PORT || 8787);
const HOST = process.env.HOST || "127.0.0.1";
const DEFAULT_SECONDS = Number(process.env.MAX_SECONDS || 240);
const YT_DLP_BIN = process.env.YT_DLP_BIN || "yt-dlp";
const FFMPEG_BIN = process.env.FFMPEG_BIN || "ffmpeg";

function send(res, code, body, type = "text/plain; charset=utf-8") {
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
  if (!Number.isFinite(parsed)) return DEFAULT_SECONDS;
  return Math.max(1, Math.min(600, Math.floor(parsed)));
}

function youtubeUrl(id) {
  id = String(id || "").trim();
  if (!id) return null;
  if (/^https?:\/\//i.test(id)) return id;
  if (!/^[A-Za-z0-9_-]{6,}$/.test(id)) return null;
  return `https://www.youtube.com/watch?v=${id}`;
}

function collectProcess(proc, inputStream) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    const errors = [];

    proc.stdout.on("data", chunk => chunks.push(chunk));
    proc.stderr.on("data", chunk => errors.push(chunk));
    proc.on("error", reject);
    proc.on("close", code => {
      if (code === 0) resolve(Buffer.concat(chunks));
      else reject(new Error(Buffer.concat(errors).toString("utf8") || `process exited ${code}`));
    });

    if (inputStream) inputStream.pipe(proc.stdin);
  });
}

async function audioToPcm(url, seconds) {
  const ytdlp = spawn(YT_DLP_BIN, [
    "--no-playlist",
    "--quiet",
    "--no-warnings",
    "-f",
    "bestaudio/best",
    "-o",
    "-",
    url,
  ], { stdio: ["ignore", "pipe", "pipe"] });

  const ffmpeg = spawn(FFMPEG_BIN, [
    "-hide_banner",
    "-loglevel",
    "error",
    "-i",
    "pipe:0",
    "-t",
    String(seconds),
    "-ac",
    "1",
    "-ar",
    "48000",
    "-f",
    "s8",
    "pipe:1",
  ], { stdio: ["pipe", "pipe", "pipe"] });

  ytdlp.stderr.on("data", chunk => {
    if (!ffmpeg.killed) ffmpeg.stderr.emit("data", chunk);
  });
  ytdlp.stdout.pipe(ffmpeg.stdin);

  const pcm = await collectProcess(ffmpeg);
  return pcm;
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
  const out = [];

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
      out.push(outByte);
      outByte = 0;
      outBits = 0;
    }
  }

  if (outBits > 0) out.push(outByte);
  return Buffer.from(out);
}

async function handleAudio(req, res, url) {
  const id = url.searchParams.get("id") || url.searchParams.get("url");
  const target = youtubeUrl(id);
  if (!target) {
    send(res, 400, "Missing or invalid id/url");
    return;
  }

  const seconds = clampSeconds(url.searchParams.get("seconds"));
  console.log(`[audio] ${target} ${seconds}s`);
  try {
    const pcm = await audioToPcm(target, seconds);
    const dfpwm = encodeDfpwm(pcm);
    send(res, 200, dfpwm, "audio/dfpwm");
  } catch (err) {
    console.error(err);
    send(res, 500, `DFPWM conversion failed: ${err.message}`);
  }
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://${req.headers.host || `${HOST}:${PORT}`}`);
  if (url.pathname === "/health") {
    send(res, 200, JSON.stringify({ ok: true, service: "crafttube-dfpwm-proxy" }), "application/json");
    return;
  }
  if (url.pathname === "/crafttube/audio") {
    handleAudio(req, res, url);
    return;
  }
  send(res, 404, "Not found");
});

server.listen(PORT, HOST, () => {
  console.log(`CraftTube DFPWM proxy listening on http://${HOST}:${PORT}`);
});
