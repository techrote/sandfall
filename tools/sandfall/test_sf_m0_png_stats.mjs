import test from "node:test";
import assert from "node:assert/strict";
import {deflateSync} from "node:zlib";
import {analyzePng, pngDimensions} from "./sf_m0_png_stats.mjs";

// Generate actual PNG byte streams, including CRCs and each standard scanline
// filter. The oracle is the known source pixels, not another decoder's answer.
function chunk(type, payload) {
  const name = Buffer.from(type), bytes = Buffer.concat([name, payload]);
  let crc = 0xffffffff;
  for (const byte of bytes) {
    crc ^= byte;
    for (let i = 0; i < 8; i++) crc = crc & 1 ? (crc >>> 1) ^ 0xedb88320 : crc >>> 1;
  }
  const out = Buffer.alloc(payload.length + 12);
  out.writeUInt32BE(payload.length); bytes.copy(out, 4);
  out.writeUInt32BE((crc ^ 0xffffffff) >>> 0, out.length - 4);
  return out;
}
function png(width, height, pixel, filters = [0], kind = 2) {
  const channels = {0: 1, 2: 3, 4: 2, 6: 4}[kind];
  const rows = [], previous = Buffer.alloc(width * channels);
  for (let y = 0; y < height; y++) {
    const raw = Buffer.alloc(width * channels), filtered = Buffer.alloc(raw.length + 1);
    for (let x = 0; x < width; x++) Buffer.from(pixel(x, y)).copy(raw, x * channels, 0, channels);
    const filter = filters[y % filters.length]; filtered[0] = filter;
    for (let i = 0; i < raw.length; i++) {
      const left = i >= channels ? raw[i - channels] : 0, up = previous[i];
      const upperLeft = i >= channels ? previous[i - channels] : 0;
      let predictor = 0;
      if (filter === 1) predictor = left;
      if (filter === 2) predictor = up;
      if (filter === 3) predictor = Math.floor((left + up) / 2);
      if (filter === 4) {
        const prediction = left + up - upperLeft;
        const distances = [left, up, upperLeft].map(value => Math.abs(value - prediction));
        predictor = [left, up, upperLeft][distances.indexOf(Math.min(...distances))];
      }
      filtered[i + 1] = (raw[i] - predictor + 256) % 256;
    }
    rows.push(filtered); raw.copy(previous);
  }
  const header = Buffer.alloc(13);
  header.writeUInt32BE(width); header.writeUInt32BE(height, 4); header[8] = 8; header[9] = kind;
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk("IHDR", header), chunk("IDAT", deflateSync(Buffer.concat(rows))), chunk("IEND", Buffer.alloc(0))]);
}
const region = {x0: 80, y0: 90, x1: 320, y1: 240};

test("bright colorful UI cannot qualify an all-black actual world ROI", () => {
  const data = png(400, 300, (x, y) => x >= 80 && x < 320 && y >= 90 && y < 240 ?
    [0, 0, 0] : [255, (x * 17) % 256, (y * 23) % 256], [0, 1, 2, 3, 4]);
  const world = analyzePng(data, region);
  assert.equal(world.bright_fraction, 0); assert.equal(world.colourful_fraction, 0);
  assert.equal(world.unique_4bit_rgb, 1); assert.equal(world.samples, 12000);
  const whole = analyzePng(data, {x0: 0, y0: 0, x1: 400, y1: 300});
  assert.ok(whole.bright_fraction > .5); assert.ok(whole.unique_4bit_rgb > 100);
  assert.throws(() => analyzePng(data), /explicit integer world screenshot ROI/);
});

test("all five PNG filters reconstruct the same known world colors", () => {
  const expected = analyzePng(png(400, 300, (x, y) => [32 + x % 224, y % 256, (x + y) % 256]), region);
  for (const filters of [[1], [2], [3], [4], [0, 1, 2, 3, 4]]) {
    const actual = analyzePng(png(400, 300, (x, y) => [32 + x % 224, y % 256, (x + y) % 256], filters), region);
    assert.deepEqual(actual, expected);
  }
  assert.equal(expected.bright_fraction, 1); assert.ok(expected.colourful_fraction > .9);
  assert.ok(expected.unique_4bit_rgb > 100);
});

test("alpha cannot turn invisible bright pixel values into visible material evidence", () => {
  for (const [kind, pixel] of [[6, () => [255, 120, 60, 0]], [4, () => [255, 0]]]) {
    const result = analyzePng(png(400, 300, pixel, [4, 3, 2, 1, 0], kind), region);
    assert.equal(result.bright_fraction, 0); assert.equal(result.unique_4bit_rgb, 1);
  }
  const gray = analyzePng(png(400, 300, () => [120], [4], 0), region);
  assert.equal(gray.bright_fraction, 1); assert.equal(gray.colourful_fraction, 0);
});

test("invalid, empty or out-of-image ROIs fail rather than silently widening the crop", () => {
  const data = png(400, 300, () => [120, 0, 80]);
  for (const invalid of [{x0: -1, y0: 0, x1: 10, y1: 10},
    {x0: 0, y0: 0, x1: 401, y1: 10}, {x0: 0, y0: 0, x1: 10, y1: 301},
    {x0: 10, y0: 0, x1: 10, y1: 10}, {x0: .5, y0: 0, x1: 10, y1: 10},
    {x0: 0, y0: NaN, x1: 10, y1: 10}])
    assert.throws(() => analyzePng(data, invalid), /ROI/);
});

test("truncated or malformed PNG cannot produce a passing pixel observation", () => {
  const data = png(400, 300, () => [120, 0, 80]);
  assert.deepEqual(pngDimensions(data), {width: 400, height: 300});
  for (const length of [0, 8, 32, 40, data.length - 1, data.length - 12])
    assert.throws(() => analyzePng(data.subarray(0, length), region), /Truncated/);
  const invalidLength = Buffer.from(data); invalidLength.writeUInt32BE(0x7fffffff, 33);
  assert.throws(() => analyzePng(invalidLength, region), /Truncated PNG chunk payload/);
  const invalidFilter = png(400, 300, () => [120, 0, 80], [5]);
  assert.throws(() => analyzePng(invalidFilter, region), /Unsupported PNG scanline filter/);
});
