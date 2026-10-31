// Exact material-cell targeting for genuine browser mouse input. Godot Web
// listens to pointermove but mousedown/up (see the verified index.js). Chromium
// preserves fractional PointerEvent client coordinates while legacy MouseEvent
// coordinates can be integer CSS pixels. Target an integer INSIDE the cell so
// both event paths select the same cell. Never round a centre into a neighbour.
import assert from 'node:assert/strict';
import {mapGodotRect} from './sf_m0_geometry.mjs';

export function mapWorldCell(cell, view, camera, metrics, layout) {
  assert.ok(Array.isArray(cell) && cell.length === 2 &&
    cell.every(n => Number.isSafeInteger(n) && n >= 0 && n < 1024),
  'Requested cell must be a valid integer coordinate');
  assert.ok(Array.isArray(view) && view.length === 4 && view.every(Number.isFinite) &&
    view[2] > 0 && view[3] > 0, 'Invalid observed world rectangle');
  const origin = camera?.camera_origin, dimensions = camera?.view_size;
  for (const pair of [origin, dimensions]) assert.ok(Array.isArray(pair) && pair.length === 2 &&
    pair.every(Number.isFinite), 'Invalid observed camera');
  assert.ok(dimensions.every(n => n > 0), 'Camera dimensions must be positive');
  const rect = [view[0] + (cell[0] - origin[0]) / dimensions[0] * view[2],
    view[1] + (cell[1] - origin[1]) / dimensions[1] * view[3],
    view[2] / dimensions[0], view[3] / dimensions[1]];
  assert.ok(rect[0] >= view[0] && rect[1] >= view[1] &&
    rect[0] + rect[2] <= view[0] + view[2] + 1e-7 &&
    rect[1] + rect[3] <= view[1] + view[3] + 1e-7,
  'Requested cell is outside the actual camera viewport');
  const mapped = mapGodotRect(rect, metrics, layout);
  const point = {};
  for (const [axis, span] of [['x', 'width'], ['y', 'height']]) {
    const lower = mapped.css[axis], upper = lower + mapped.css[span];
    // A strict interior avoids native float32 floor decisions at cell edges.
    const first = Math.ceil(lower + 1e-5), last = Math.floor(upper - 1e-5);
    assert.ok(first <= last,
      `Cell ${cell} has no interior integer CSS ${axis} pixel; zoom through real camera controls`);
    point[axis] = Math.max(first, Math.min(last, Math.round(mapped.center[axis])));
  }
  return {...mapped, point, cell: [...cell], logicalCell: rect};
}
