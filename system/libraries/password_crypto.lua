-- MIT License
--
-- Copyright (c) 2023 Miguel Oliveira
-- Copyright (c) 2016 John Schember (HMAC adapter, lua-hashings/hashings/hmac.lua)
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
-- Vendored SHA256/PBKDF2 from CCryptolib, commit 14489aa1ec408f8a07e1292be5ef91dfe8567c74.
-- https://github.com/migeyel/ccryptolib/blob/14489aa1ec408f8a07e1292be5ef91dfe8567c74/ccryptolib/sha256.lua
-- Changes: standalone packing, fixed FIPS constants (portable Lua 5.2), no hardware path, credential wrapper.
local M = {}
assert(bit32, "CC bit32 API required for password hashing")

local expect = function(n, value, ...)
  for _, kind in ipairs({...}) do if type(value) == kind then return end end
  error("Invalid argument " .. n, 3)
end
local function lassert(value, message) assert(value, message) end
local rol, shr = bit32.lrotate, bit32.rshift
local bxor, bnot, band = bit32.bxor, bit32.bnot, bit32.band
local unpack = table.unpack or unpack
local function packWords(width, ...)
  local out = {}
  for _, value in ipairs({...}) do
    local bytes = {}
    for i = width, 1, -1 do bytes[i] = string.char(value % 256) value = math.floor(value / 256) end
    out[#out + 1] = table.concat(bytes)
  end
  return table.concat(out)
end
local function unpackWords(count, data, offset)
  local out = {}
  offset = offset or 1
  for i = 1, count do
    local a, b, c, d = data:byte(offset, offset + 3)
    out[i] = ((a * 256 + b) * 256 + c) * 256 + d
    offset = offset + 4
  end
  return unpack(out)
end
local fmt1x8, fmt16x4, fmt8x4 = 8, 16, 8
local function p1x8(_, value) return packWords(8, value) end
-- SHA compression appends its schedule to the input table. Fixed-width pack
-- formats must ignore those extra words, just like the upstream string.pack.
local function p16x4(_, ...) local words={...} return packWords(4,unpack(words,1,16)) end
local function p8x4(_, ...) local words={...} return packWords(4,unpack(words,1,8)) end
local function u16x4(_, data, offset) return unpackWords(16, data, offset) end
local function u8x4(_, data, offset) return unpackWords(8, data, offset) end
-- FIPS 180-4 section 4.2.2. Avoid upstream floating-point prime discovery:
-- stock Lua 5.2 '%' loses remainders for huge powers (unlike CC's runtime).
local K = {
    0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
    0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
    0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
    0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
    0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
    0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
    0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
    0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2,
}
local h0 = {0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19}

local function compress(h, w)
    local h0, h1, h2, h3, h4, h5, h6, h7 = unpack(h)
    local K = K

    -- Message schedule.
    for j = 17, 64 do
        local wf = w[j - 15]
        local w2 = w[j - 2]
        local s0 = bxor(rol(wf, 25), rol(wf, 14), shr(wf, 3))
        local s1 = bxor(rol(w2, 15), rol(w2, 13), shr(w2, 10))
        w[j] = w[j - 16] + s0 + w[j - 7] + s1
    end

    -- Block.
    local a, b, c, d, e, f, g, h = h0, h1, h2, h3, h4, h5, h6, h7
    for j = 1, 64 do
        local s1 = bxor(rol(e, 26), rol(e, 21), rol(e, 7))
        local ch = bxor(band(e, f), band(bnot(e), g))
        local temp1 = h + s1 + ch + K[j] + w[j]
        local s0 = bxor(rol(a, 30), rol(a, 19), rol(a, 10))
        local maj = bxor(band(a, b), band(a, c), band(b, c))
        local temp2 = s0 + maj

        h = g
        g = f
        f = e
        e = d + temp1
        d = c
        c = b
        b = a
        a = temp1 + temp2
    end

    return {
        (h0 + a) % 2 ^ 32,
        (h1 + b) % 2 ^ 32,
        (h2 + c) % 2 ^ 32,
        (h3 + d) % 2 ^ 32,
        (h4 + e) % 2 ^ 32,
        (h5 + f) % 2 ^ 32,
        (h6 + g) % 2 ^ 32,
        (h7 + h) % 2 ^ 32,
    }
end

--- Hashes data using SHA256.
--- @param data string Input bytes.
--- @return string hash The 32-byte hash value.
local function digest(data)
    expect(1, data, "string")

    -- Pad input.
    local bitlen = #data * 8
    local padlen = -(#data + 9) % 64
    data = data .. "\x80" .. ("\0"):rep(padlen) .. p1x8(fmt1x8, bitlen)

    -- Digest.
    local h = h0
    for i = 1, #data, 64 do
        h = compress(h, {u16x4(fmt16x4, data, i)})
    end

    return p8x4(fmt8x4, unpack(h))
end

-- Reports once every ~10ms on a standard CCEmuX emulator.
local PBKDF2_CB_ITERATIONS = 50

--- Hashes a password using PBKDF2-HMAC-SHA256.
--- @param password string The password to hash.
--- @param salt string The password's salt.
--- @param iter number The number of iterations to perform.
--- @param progress fun(iter: number)? An optional function to periodically call with the current iteration number as argument.
--- @return string dk The 32-byte derived key.
local function pbkdf2(password, salt, iter, progress)
    expect(1, password, "string")
    expect(2, salt, "string")
    expect(3, iter, "number")
    lassert(iter % 1 == 0, "iteration number must be an integer", 2)
    lassert(iter > 0, "iteration number must be positive", 2)
    expect(4, progress, "function", "nil")

    -- Pad password.
    if #password > 64 then password = digest(password) end
    password = {u16x4(fmt16x4, password .. ("\0"):rep(64), 1)}

    -- Compute password blocks.
    local ikp = {}
    local okp = {}
    for i = 1, 16 do
        ikp[i] = bxor(password[i], 0x36363636)
        okp[i] = bxor(password[i], 0x5c5c5c5c)
    end

    local hikp = compress(h0, ikp)
    local hokp = compress(h0, okp)

    -- 96-byte padding.
    local pad96 = {2 ^ 31, 0, 0, 0, 0, 0, 0, 0x300}

    -- First iteration.
    local pre = p16x4(fmt16x4, unpack(ikp))
    local hs = {u8x4(fmt8x4, digest(pre .. salt .. "\0\0\0\1"), 1)}
    for i = 1, 8 do hs[i + 8] = pad96[i] end
    hs = compress(hokp, hs)

    -- Second iteration onwards.
    local out = {unpack(hs)}
    for i = 2, iter do
        for j = 1, 8 do hs[j + 8] = pad96[j] end
        hs = compress(hikp, hs)
        for j = 1, 8 do hs[j + 8] = pad96[j] end
        hs = compress(hokp, hs)
        for j = 1, 8 do out[j] = bxor(out[j], hs[j]) end
        if progress and i % PBKDF2_CB_ITERATIONS == 0 then progress(i) end
    end

    return p8x4(fmt8x4, unpack(out))
end

M.digest = digest
M.pbkdf2 = pbkdf2

local sequence = 0
local function hex(value) return (value:gsub(".", function(c) return string.format("%02x", c:byte()) end)) end
-- HMAC construction from MIT-licensed user-none/lua-hashings/hashings/hmac.lua.
-- Adapter uses the vetted digest above instead of the upstream hash object.
function M.mac(key, payload)
  expect(1,key,"string") expect(2,payload,"string")
  if #key > 64 then key = digest(key) end
  key = key .. string.rep("\0",64-#key)
  local inner, outer = {}, {}
  for i=1,64 do
    inner[i]=string.char(bxor(key:byte(i),0x36))
    outer[i]=string.char(bxor(key:byte(i),0x5c))
  end
  return hex(digest(table.concat(outer)..digest(table.concat(inner)..payload)))
end
local function control(options, total)
  options = options or {}
  local function clock() return os.epoch and os.epoch("utc") / 1000 or os.clock() end
  local last = clock()
  return function(i)
    if options.cancelled and options.cancelled() then error("Authentication cancelled",0) end
    if options.progress and i % 5000 == 0 then options.progress(i,total or 600000) end
    if sleep and clock()-last >= 0.02 then sleep(0) last=clock() end
  end
end
local function create(password, options, iterations)
  assert(type(password) == "string" and #password <= 1024, "Invalid password")
  sequence = sequence + 1
  -- Salts need uniqueness, not secrecy. Do not use this source for keys/nonces.
  local source = tostring(os.epoch and os.epoch("utc") or os.clock()) .. ":" ..
    tostring(os.getComputerID and os.getComputerID() or 0) .. ":" .. sequence
  for _ = 1, 16 do source = source .. string.char(math.random(0,255)) end
  local salt = hex(digest(source):sub(1,16))
  return {algorithm="pbkdf2-hmac-sha256", salt=salt, iterations=iterations,
    digest=hex(pbkdf2(password,salt,iterations,control(options,iterations)))}
end
-- Keep the high-cost credential for compatibility with retained older releases.
function M.create(password,options) return create(password,options,600000) end
function M.createQuick(password,options) return create(password,options,15000) end
function M.verify(password, value, options)
  if type(password) ~= "string" or #password > 1024 or type(value) ~= "table"
    or value.algorithm ~= "pbkdf2-hmac-sha256" or type(value.salt) ~= "string"
    or #value.salt ~= 32 or not value.salt:match("^[0-9a-f]+$")
    or type(value.iterations) ~= "number" or value.iterations % 1 ~= 0
    or value.iterations < 15000 or value.iterations > 2000000
    or type(value.digest) ~= "string" or #value.digest ~= 64
    or not value.digest:match("^[0-9a-f]+$") then return false end
  local actual = hex(pbkdf2(password,value.salt,value.iterations,control(options,value.iterations)))
  local difference = 0
  for i = 1, 64 do difference = bit32.bor(difference, bxor(actual:byte(i),value.digest:byte(i))) end
  return difference == 0
end
return M

