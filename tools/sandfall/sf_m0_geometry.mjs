// Godot publishes logical Control rectangles; CDP takes viewport CSS pixels.
// Keep the canvas backing, CSS box and screenshot pixel spaces explicit.

const finite = (value, name) => {
  if (!Number.isFinite(value)) throw Error(name + " must be finite");
  return value;
};
const positive = (value, name) => {
  finite(value, name);
  if (value <= 0) throw Error(name + " must be positive");
  return value;
};
const size = (value, name) => {
  if (!value || typeof value !== "object") throw Error(name + " is required");
  return {width: positive(value.width, name + ".width"),
    height: positive(value.height, name + ".height")};
};
const rect = (value, name) => {
  if (!value || typeof value !== "object") throw Error(name + " is required");
  return {x: finite(value.x, name + ".x"), y: finite(value.y, name + ".y"),
    ...size(value, name)};
};

export function mapGodotRect(logicalRect, metrics, layout) {
  if (!Array.isArray(logicalRect) || logicalRect.length !== 4)
    throw Error("Godot rectangle must contain x, y, width, height");
  if (!metrics || !layout) throw Error("Browser metrics and Godot layout are required");
  if (layout.stretch_mode !== "canvas_items" || layout.stretch_aspect !== "keep")
    throw Error("Unsupported Godot stretch layout; do not guess its input transform");
  const logical = size(layout, "Godot layout");
  const source = rect({x: logicalRect[0], y: logicalRect[1],
    width: logicalRect[2], height: logicalRect[3]}, "Godot rectangle");
  const canvas = rect(metrics.canvas, "Canvas CSS rectangle");
  const backing = size(metrics.backing, "Canvas backing");
  const viewport = size(metrics.viewport, "CSS viewport");
  const devicePixelRatio = positive(metrics.devicePixelRatio, "devicePixelRatio");
  if (source.x < 0 || source.y < 0 || source.x + source.width > logical.width + 1e-6 ||
      source.y + source.height > logical.height + 1e-6)
    throw Error("Godot rectangle lies outside the source-bound logical viewport");

  // Fit in backing pixels first. A CSS-sized canvas and its backing resolution
  // need not equal devicePixelRatio; the export or CSS may size them separately.
  const backingScale = Math.min(backing.width / logical.width, backing.height / logical.height);
  const backingOffset = {x: (backing.width - logical.width * backingScale) / 2,
    y: (backing.height - logical.height * backingScale) / 2};
  const scale = {x: backingScale * canvas.width / backing.width,
    y: backingScale * canvas.height / backing.height};
  const offset = {x: canvas.x + backingOffset.x * canvas.width / backing.width,
    y: canvas.y + backingOffset.y * canvas.height / backing.height};
  const css = {x: offset.x + source.x * scale.x, y: offset.y + source.y * scale.y,
    width: source.width * scale.x, height: source.height * scale.y};
  const center = {x: css.x + css.width / 2, y: css.y + css.height / 2};
  if (center.x < 0 || center.y < 0 || center.x >= viewport.width || center.y >= viewport.height ||
      center.x < canvas.x || center.y < canvas.y ||
      center.x >= canvas.x + canvas.width || center.y >= canvas.y + canvas.height)
    throw Error("Mapped Godot rectangle center is outside the visible canvas");

  return {css, center, transform: {scale, offset, backingScale, backingOffset,
    logical, backing, devicePixelRatio,
    backingPerCssPixel: {x: backing.width / canvas.width, y: backing.height / canvas.height},
    contentCss: {x: offset.x, y: offset.y,
      width: logical.width * scale.x, height: logical.height * scale.y}}};
}

// Page.captureScreenshot output may be CSS-sized or backing-sized. Derive its
// mapping from the actual screenshot dimensions, never from a guessed DPR.
export function cssRectToScreenshotROI(cssRect, cssViewport, screenshotSize, insetCss = 0) {
  const source = rect(cssRect, "World CSS rectangle");
  const viewport = size(cssViewport, "CSS viewport");
  const screenshot = size(screenshotSize, "Screenshot");
  if (!Number.isInteger(screenshot.width) || !Number.isInteger(screenshot.height))
    throw Error("Screenshot dimensions must be integers");
  finite(insetCss, "World inset");
  if (insetCss < 0) throw Error("World inset must not be negative");
  const left = Math.max(0, source.x + insetCss);
  const top = Math.max(0, source.y + insetCss);
  const right = Math.min(viewport.width, source.x + source.width - insetCss);
  const bottom = Math.min(viewport.height, source.y + source.height - insetCss);
  if (left >= right || top >= bottom) throw Error("World rectangle has no visible interior");
  const sx = screenshot.width / viewport.width, sy = screenshot.height / viewport.height;
  const region = {x0: Math.ceil(left * sx), y0: Math.ceil(top * sy),
    x1: Math.floor(right * sx), y1: Math.floor(bottom * sy)};
  if (region.x0 >= region.x1 || region.y0 >= region.y1)
    throw Error("World rectangle has no complete screenshot pixels");
  return region;
}
