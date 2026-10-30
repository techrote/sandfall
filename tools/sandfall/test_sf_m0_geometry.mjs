import test from "node:test";
import assert from "node:assert/strict";
import {mapGodotRect, cssRectToScreenshotROI} from "./sf_m0_geometry.mjs";

const layout = {width: 1280, height: 800, stretch_mode: "canvas_items", stretch_aspect: "keep"};
const metrics = {canvas: {x: 0, y: 0, width: 800, height: 450},
  backing: {width: 800, height: 450}, viewport: {width: 800, height: 450}, devicePixelRatio: 1};
const button = [286, 579, 233, 42];
const close = (actual, expected) => assert.ok(Math.abs(actual - expected) < 1e-4,
  `${actual} differs from ${expected}`);

test("retained 800x450 failure maps Continue onto its visible screenshot button", () => {
  const mapped = mapGodotRect(button, metrics, layout);
  assert.deepEqual(mapped.css, {x: 200.875, y: 325.6875, width: 131.0625, height: 23.625});
  assert.deepEqual(mapped.center, {x: 266.40625, y: 337.5});
  assert.deepEqual(mapped.transform.contentCss, {x: 40, y: 0, width: 720, height: 450});
  assert.ok(button[1] + button[3] / 2 > metrics.viewport.height,
    "the original unmapped y=600 click was outside the browser");
});

test("retained world rectangle maps independently of the menu and generic screenshot crop", () => {
  const {css} = mapGodotRect([152.888854980469, 190, 974.222290039062, 548], metrics, layout);
  close(css.x, 126); close(css.y, 106.875);
  close(css.width, 548); close(css.height, 308.25);
});

test("canvas DOM offset and vertical letterboxing are included", () => {
  const shifted = mapGodotRect(button, {...metrics,
    canvas: {...metrics.canvas, x: 70, y: 35}, viewport: {width: 1000, height: 700}}, layout);
  assert.deepEqual(shifted.center, {x: 336.40625, y: 372.5});
  const square = mapGodotRect(button, {...metrics,
    canvas: {x: 0, y: 0, width: 800, height: 800},
    backing: {width: 800, height: 800}, viewport: {width: 800, height: 800}}, layout);
  assert.deepEqual(square.center, {x: 251.5625, y: 525});
  assert.deepEqual(square.transform.contentCss, {x: 0, y: 150, width: 800, height: 500});
});

test("DPR=2 does not double CSS pointer coordinates, with either backing policy", () => {
  for (const backing of [{width: 1600, height: 900}, metrics.backing]) {
    const result = mapGodotRect(button, {...metrics, backing, devicePixelRatio: 2}, layout);
    assert.deepEqual(result.center, {x: 266.40625, y: 337.5});
    assert.equal(result.transform.devicePixelRatio, 2);
  }
});

test("different CSS and backing aspect ratios use the measured two-axis conversion", () => {
  const result = mapGodotRect(button, {...metrics,
    backing: {width: 1280, height: 800},
    canvas: {x: 0, y: 0, width: 640, height: 450}}, layout);
  assert.deepEqual(result.center, {x: 201.25, y: 337.5});
});

test("unknown stretch, invalid geometry and offscreen hit centers fail closed", () => {
  assert.throws(() => mapGodotRect(button, metrics, {...layout, stretch_aspect: "expand"}), /Unsupported/);
  assert.throws(() => mapGodotRect(button, metrics, {...layout, stretch_mode: "viewport"}), /Unsupported/);
  for (const bad of [[0, 0, 0, 20], [0, 0, 20, -1], [NaN, 0, 20, 20],
    [-1, 0, 20, 20], [1260, 0, 40, 20], [0, 790, 20, 20], [0, 0, 20]])
    assert.throws(() => mapGodotRect(bad, metrics, layout));
  assert.throws(() => mapGodotRect(button, {...metrics, devicePixelRatio: 0}, layout), /positive/);
  assert.throws(() => mapGodotRect(button, {...metrics,
    canvas: {...metrics.canvas, x: 900}, viewport: {width: 1000, height: 450}}, layout), /outside/);
});

test("screenshot ROI uses observed image-to-CSS size instead of DPR", () => {
  const css = {x: 10.25, y: 20.75, width: 100.5, height: 50.5};
  assert.deepEqual(cssRectToScreenshotROI(css, metrics.viewport, {width: 1600, height: 900}),
    {x0: 21, y0: 42, x1: 221, y1: 142});
  assert.deepEqual(cssRectToScreenshotROI(css, metrics.viewport, {width: 800, height: 450}),
    {x0: 11, y0: 21, x1: 110, y1: 71});
});

test("ROI clips to the visible viewport, rounds inward and excludes an optional border", () => {
  assert.deepEqual(cssRectToScreenshotROI({x: -10.25, y: -5.25, width: 30.5, height: 20.5},
    metrics.viewport, {width: 1600, height: 900}), {x0: 0, y0: 0, x1: 40, y1: 30});
  assert.deepEqual(cssRectToScreenshotROI({x: 790, y: 440, width: 30, height: 30},
    metrics.viewport, {width: 1600, height: 900}), {x0: 1580, y0: 880, x1: 1600, y1: 900});
  assert.deepEqual(cssRectToScreenshotROI({x: 126, y: 106.875, width: 548, height: 308.25},
    metrics.viewport, {width: 800, height: 450}, 2), {x0: 128, y0: 109, x1: 672, y1: 413});
});

test("empty, wholly clipped, subpixel and invalid screenshot ROIs are refused", () => {
  for (const bad of [{x: 900, y: 10, width: 20, height: 20},
    {x: -20, y: -20, width: 10, height: 10}, {x: 10.2, y: 10.2, width: .1, height: .1},
    {x: 0, y: 0, width: 0, height: 5}])
    assert.throws(() => cssRectToScreenshotROI(bad, metrics.viewport, metrics.viewport));
  assert.throws(() => cssRectToScreenshotROI({x: 0, y: 0, width: 5, height: 5},
    metrics.viewport, metrics.viewport, 3), /no visible interior/);
  assert.throws(() => cssRectToScreenshotROI({x: 0, y: 0, width: 5, height: 5},
    metrics.viewport, {width: 800.5, height: 450}), /integers/);
});
