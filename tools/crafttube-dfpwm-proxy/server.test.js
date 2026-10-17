"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const { EventEmitter } = require("node:events");
const { PassThrough } = require("node:stream");
const http = require("node:http");
const { youtubeUrl, clampSeconds, audioToPcm, encodeDfpwm, createServer } = require("./server");

function processes() {
  const children = [];
  const spawnFn = (bin, args, options) => {
    const child = new EventEmitter();
    Object.assign(child, { bin, args, options, stdin: new PassThrough(), stdout: new PassThrough(), stderr: new PassThrough(), killed: false, exitCode: null });
    child.kill = () => { child.killed = true; return true; };
    children.push(child);
    return child;
  };
  return { children, spawnFn };
}
test("allowlist canonicalizes only YouTube video IDs/URLs", () => {
  for (const value of ["abcdefghijk", "https://youtu.be/abcdefghijk?t=20", "https://youtube.com/watch?v=abcdefghijk", "https://m.youtube.com/shorts/abcdefghijk"]) {
    assert.equal(youtubeUrl(value), "https://www.youtube.com/watch?v=abcdefghijk");
  }
  for (const value of ["https://evil.test/abcdefghijk", "https://youtube.com.evil/watch?v=abcdefghijk", "https://youtube.com@127.0.0.1/watch?v=abcdefghijk", "http://127.0.0.1", "file:///etc/passwd", "--exec=bad", "https://youtube.com:123/watch?v=abcdefghijk", "https://youtube.com/redirect?q=evil", "short"]) assert.equal(youtubeUrl(value), null);
  assert.equal(clampSeconds("Infinity"), 240);
  assert.equal(clampSeconds(9999), 600);
  assert.equal(encodeDfpwm(Buffer.alloc(9)).length, 2);
});
test("successful conversion bounds memory and cleans up producer", async () => {
  const p = processes();
  const result = audioToPcm("https://www.youtube.com/watch?v=abcdefghijk", 1, p);
  p.children[1].stdout.write(Buffer.from([0, 1, 2, 3]));
  for (let i = 0; i < 100; i++) p.children[0].stderr.write(Buffer.alloc(65536));
  p.children[1].emit("close", 0);
  assert.deepEqual(await result, Buffer.from([0, 1, 2, 3]));
  assert(p.children.every(child => child.killed));
  assert(p.children[0].args.includes("--ignore-config"));
  assert(p.children[1].args.includes("-protocol_whitelist"));
  assert(p.children.every(child => child.options.windowsHide));
});
test("child errors, output limits, timeout and abort kill both children", async () => {
  for (const mode of ["source-error", "converter-error", "stdin-error", "output-limit", "input-limit", "bad-exit", "source-exit", "timeout", "abort"]) {
    const p = processes(), controller = new AbortController();
    const result = audioToPcm("abcdefghijk", 1, { ...p, signal: controller.signal, timeoutMs: 10 });
    if (mode === "source-error") p.children[0].emit("error", new Error("ENOENT"));
    if (mode === "converter-error") p.children[1].emit("error", new Error("ENOENT"));
    if (mode === "stdin-error") p.children[1].stdin.emit("error", new Error("input failed"));
    if (mode === "output-limit") p.children[1].stdout.write(Buffer.alloc(48001));
    if (mode === "input-limit") p.children[0].stdout.emit("data", { length: 64 * 1024 * 1024 + 1 });
    if (mode === "bad-exit") p.children[1].emit("close", 1);
    if (mode === "source-exit") {
      p.children[0].emit("close", 1);
      p.children[1].stdout.write(Buffer.from([1]));
      p.children[1].emit("close", 0);
    }
    if (mode === "abort") controller.abort();
    await assert.rejects(result);
    assert(p.children.every(child => child.killed), mode);
    // Late process errors must remain handled after cleanup.
    p.children[0].emit("error", new Error("late error"));
  }
});
test("synchronous spawn failure cleans already-started downloader", async () => {
  const p = processes();
  await assert.rejects(audioToPcm("abcdefghijk", 1, { spawnFn: (...args) => {
    if (p.children.length) throw new Error("spawn failed");
    return p.spawnFn(...args);
  } }));
  assert(p.children[0].killed);
});
function request(port, path) {
  return new Promise((resolve, reject) => {
    const req = http.get({ host: "127.0.0.1", port, path }, res => {
      res.resume(); res.on("end", () => resolve(res.statusCode));
    });
    req.on("error", reject);
  });
}
test("HTTP concurrency cap rejects excess work; abort frees capacity", async () => {
  const p = processes();
  const server = createServer({ spawnFn: p.spawnFn, timeoutMs: 1000 });
  await new Promise(resolve => server.listen(0, "127.0.0.1", resolve));
  const port = server.address().port;
  const url = "/crafttube/audio?id=abcdefghijk&seconds=1";
  const clients = [];
  try {
    assert.equal(await request(port, "/crafttube/audio?id=https://evil.test"), 400);
    for (let i = 0; i < 2; i++) {
      const req = http.get({ host: "127.0.0.1", port, path: url });
      req.on("error", () => {}); clients.push(req);
    }
    while (p.children.length < 4) await new Promise(resolve => setTimeout(resolve, 5));
    assert.equal(await request(port, url), 503);
    clients.forEach(req => req.destroy());
    while (!p.children.every(child => child.killed)) await new Promise(resolve => setTimeout(resolve, 5));
    assert.equal(await request(port, "/health"), 200);
    assert.equal(await request(port, "/crafttube/audio?id=invalid"), 400);
  } finally {
    clients.forEach(req => req.destroy());
    await new Promise(resolve => server.close(resolve));
  }
});
