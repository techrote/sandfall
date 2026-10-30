#!/usr/bin/env node
// SF-M0: standard-library PNG/ROI brightness proof. Not a substitute for human
// visual inspection. CI can distinguish an all-black world from colored output.
// Uses full PNG filter reconstruction; fails closed on unsupported layouts.
import { readFileSync } from "node:fs";
import { inflateSync } from "node:zlib";

export function analyzePng(buffer) {
  const signature = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  if (!buffer.subarray(0, 8).equals(signature)) throw Error("PNG signature mismatch");
  let width = 0, height = 0, bitDepth = 0, kind = 0, interlace = 0, channels = 0;
  const dataChunks = [];
  for (let p = 8; p + 12 <= buffer.length;) {
    const count = buffer.readUInt32BE(p);
    const type = buffer.toString("ascii", p + 4, p + 8);
    const chunk = buffer.subarray(p + 8, p + 8 + count);
    if (type === "IHDR") {
      width = chunk.readUInt32BE(0); height = chunk.readUInt32BE(4);
      bitDepth = chunk[8]; kind = chunk[9]; interlace = chunk[12];
      channels = ({0: 1, 2: 3, 4: 2, 6: 4})[kind];
    }
    if (type === "IDAT") dataChunks.push(chunk);
    p += count + 12;
    if (type === "IEND") break;
  }
  if (bitDepth !== 8 || !channels || interlace !== 0 || width < 320 ||
      height < 240 || width > 8192 || height > 8192)
    throw Error("Unsupported screenshot PNG layout " +
      JSON.stringify({width, height, bitDepth, kind, interlace}));

  const stride = width * channels;
  const rowBytes = stride + 1;
  const inflated = inflateSync(Buffer.concat(dataChunks));
  if (inflated.length !== rowBytes * height) throw Error("PNG scanline length mismatch");
  const prev = Buffer.alloc(stride), row = Buffer.alloc(stride);
  const x0 = Math.floor(width * .20), x1 = Math.ceil(width * .80);
  const y0 = Math.floor(height * .29), y1 = Math.ceil(height * .79);
  let samples = 0, bright = 0, colourful = 0;
  const unique = new Set();

  for (let y = 0; y < height; y++) {
    const off = y * rowBytes;
    const filter = inflated[off];
    if (filter > 4) throw Error("Unsupported PNG scanline filter");
    for (let x = 0; x < stride; x++) {
      let v = inflated[off + x + 1];
      const a = x >= channels ? row[x - channels] : 0;
      const b = prev[x], c = x >= channels ? prev[x - channels] : 0;
      if (filter === 1) v += a;
      else if (filter === 2) v += b;
      else if (filter === 3) v += Math.floor((a + b) / 2);
      else if (filter === 4) {
        const p = a + b - c, da = Math.abs(p - a), db = Math.abs(p - b), dc = Math.abs(p - c);
        v += da <= db && da <= dc ? a : db <= dc ? b : c;
      }
      row[x] = v & 255;
    }
    if (y >= y0 && y < y1) {
      for (let x = x0; x < x1; x += 3) {
        const i = x * channels;
        const r = row[i], g = kind === 0 || kind === 4 ? r : row[i + 1];
        const b = kind === 0 || kind === 4 ? r : row[i + 2];
        const max = Math.max(r, g, b), min = Math.min(r, g, b);
        samples++;
        if (max > 30) bright++;
        if (max > 35 && max - min > 20) colourful++;
        unique.add(((r >> 4) << 8) | ((g >> 4) << 4) | (b >> 4));
      }
    }
    row.copy(prev);
  }
  return {
    width, height, region: {x0, x1, y0, y1}, samples, bright, colourful,
    bright_fraction: bright / samples, colourful_fraction: colourful / samples,
    unique_4bit_rgb: unique.size,
  };
}

if (process.argv[1] && process.argv[1].endsWith("/sf_m0_png_stats.mjs")) {
  for (const name of process.argv.slice(2))
    console.log(JSON.stringify({file: name, stats: analyzePng(readFileSync(name))}));
}
