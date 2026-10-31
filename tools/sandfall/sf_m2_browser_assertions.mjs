// Fail-closed oracles for the ordinary SF-M2 browser lane. These helpers never
// invoke application code or modify state. Their unit tests qualify the oracle,
// not Godot: only a source-matched browser run is application evidence.
import assert from "node:assert/strict";

const clone = value => structuredClone(value);
const integer = (value, label) => assert.ok(Number.isSafeInteger(value) && value >= 0,
  `${label} must be an actual nonnegative integer counter`);

export function samePhysicalValue(actual, expected, label = "physical value", tolerance = 1e-5) {
  if (typeof expected === "number") {
    assert.ok(Number.isFinite(expected) && typeof actual === "number" && Number.isFinite(actual),
      `${label} contains a missing/nonfinite number`);
    assert.ok(Math.abs(actual - expected) <= tolerance, `${label} differs: ${actual} != ${expected}`);
  } else if (Array.isArray(expected)) {
    assert.ok(Array.isArray(actual), `${label} must be an array`);
    assert.equal(actual.length, expected.length, `${label} has a different length`);
    expected.forEach((value, index) => samePhysicalValue(actual[index], value, `${label}[${index}]`, tolerance));
  } else if (expected && typeof expected === "object") {
    assert.ok(actual && typeof actual === "object", `${label} must be an object`);
    assert.deepEqual(Object.keys(actual).sort(), Object.keys(expected).sort(), `${label} has different fields`);
    for (const [key, value] of Object.entries(expected)) samePhysicalValue(actual[key], value, `${label}.${key}`, tolerance);
  } else assert.equal(actual, expected, `${label} differs`);
}

export function assertOrdinaryState(state, { requireReady = true } = {}) {
  assert.ok(state && typeof state === "object", "Missing ordinary application observation");
  assert.equal(state.schema, "sandfall-host-v1", "Unexpected host observation schema");
  assert.equal(state.app_ready, true, "Dedicated Sandfall application is not ready");
  assert.notEqual(state.mode, "fault", "Application entered fault mode");
  assert.equal(Boolean(state.fault), false, `Application fault: ${state.error ?? "unspecified"}`);
  assert.equal(state.actor_count, 0, "Inherited actor/controller is present");
  integer(state.paint_commands, "accepted mutation count");
  assert.equal(state.paint_commands, state.mutation_count, "Observer mutation counts disagree");
  assert.equal(state.render_rejections, 0, "Renderer rejected a native snapshot");
  assert.equal(Object.keys(state.rapier_test ?? {}).length, 0, "Special Rapier acceptance fixture is active");
  if (requireReady) {
    assert.equal(state.ready, true, "Session is not ready");
    assert.equal(state.workers, 1, "This receipt qualifies compatibility Web with exactly one native worker");
    integer(state.tick, "native tick");
    integer(state.rapier_steps, "Rapier step");
    integer(state.native?.native_revision, "live native revision");
    integer(state.generation, "session generation");
    assert.ok(state.simulation_interest && typeof state.simulation_interest === "object",
      "Camera-independent simulation interest was not observed");
    assert.ok(typeof state.initial_hash === "string" && /^[a-f0-9]{64}$/.test(state.initial_hash),
      "Initial native material SHA-256 is missing");
    assert.ok(typeof state.definition_hash === "string" && /^[a-f0-9]{64}$/.test(state.definition_hash),
      "Frozen initial definition SHA-256 is missing");
    assert.ok(Array.isArray(state.body_poses) && Array.isArray(state.initial_body_poses),
      "Actual and initial body poses were not observed");
  }
}

export function assertInputClear(state) {
  assert.ok(state.input && typeof state.input === "object", "Input ownership state is absent");
  assert.deepEqual(state.input.held_keys, [], "Held keys survived input retirement");
  assert.equal(state.input.pointer_buttons, 0, "Pointer buttons survived input retirement");
  assert.equal(state.input.gesture_active, false, "A gesture survived input retirement");
  assert.equal(state.input.pending_ui_gestures, 0, "A held UI gesture survived input retirement");
  integer(state.input.clear_serial, "input clear serial");
  assert.equal(state.pending_steps, 0, "A pending Step survived input retirement");
}

export function assertEdit(state) {
  assertOrdinaryState(state);
  assert.equal(state.entry, "sandbox", "Edit must have explicit Sandbox ownership");
  assert.equal(state.mode, "edit", "Session did not enter Edit");
  assert.equal(state.paused, true, "Edit is not paused");
  assert.equal(state.tick, 0, "Native simulation advanced in Edit");
  assert.equal(state.rapier_steps, 0, "Rapier advanced in Edit");
  assert.equal(state.current_hash, state.document?.cells_sha256, "Edit preview differs from authoritative authored cells");
  assert.equal(state.document.locked, false, "Edit document is locked");
  assert.equal(state.document.retired, false, "Retired history was exposed as editable");
  samePhysicalValue(state.body_poses, state.initial_body_poses, "Edit initial body poses");
}

export function physicalCheckpoint(state) {
  assertOrdinaryState(state);
  assert.equal(state.paused, true, "Physical checkpoints require actual pause");
  assert.match(state.current_hash ?? "", /^[a-f0-9]{64}$/, "Paused native material identity is missing");
  return clone(state);
}

export function assertPausedStable(before, after, { camera = false } = {}) {
  assertOrdinaryState(after);
  assert.equal(before.paused, true, "Baseline was not paused");
  assert.equal(after.paused, true, "Application resumed unexpectedly");
  assert.equal(after.generation, before.generation, "Paused comparison crossed a session boundary");
  assert.equal(after.mode, before.mode, "Paused comparison changed Edit/Run ownership");
  assert.equal(after.tick, before.tick, "Native ticks advanced during pause/camera/input-only work");
  assert.equal(after.rapier_steps, before.rapier_steps, "Rapier advanced during pause/camera/input-only work");
  assert.equal(after.current_hash, before.current_hash, "Material payload changed during pause/camera/input-only work");
  // Material hashes are cached at lifecycle boundaries. The independently
  // refreshed native revision rejects a mutation even if that cached hash did
  // not change between two paused browser observations.
  assert.equal(after.mutation_count, before.mutation_count, "Mutation occurred during a nonmutating operation");
  assert.deepEqual(after.document, before.document, "Authored document/history changed during a nonmutating operation");
  assert.equal(after.native.native_revision, before.native.native_revision,
    "Live native revision changed during pause/camera/input-only work");
  assert.equal(after.definition_hash, before.definition_hash, "Initial definition changed outside explicit selection");
  assert.equal(after.initial_hash, before.initial_hash, "Initial native payload changed outside explicit selection");
  samePhysicalValue(after.body_poses, before.body_poses, "paused body poses");
  assert.deepEqual(after.simulation_interest, before.simulation_interest, "Camera/input changed simulation interest");
  if (camera) samePhysicalValue(after.camera, before.camera, "camera without a fresh gesture");
}

export function assertStep(before, after, active) {
  assertOrdinaryState(before);
  assertOrdinaryState(after);
  assert.equal(before.mode, "run", "Step baseline is not Run");
  assert.equal(after.mode, "run", "Step left Run");
  assert.equal(before.paused, true, "Step baseline is not paused");
  assert.equal(after.paused, true, "Step did not remain paused");
  assert.equal(before.rapier_active, active, "Unexpected baseline bridge activity");
  assert.equal(after.rapier_active, active, "Step changed bridge activity");
  assert.equal(after.generation, before.generation, "Step changed session generation");
  assert.equal(after.tick - before.tick, 1, "One genuine Step must produce exactly one native tick");
  assert.equal(after.rapier_steps - before.rapier_steps, active ? 1 : 0,
    "Step must produce one Rapier step only when the bridge is active");
  assert.equal(after.definition_hash, before.definition_hash, "Step mutated the frozen initial definition");
  assert.equal(after.initial_hash, before.initial_hash, "Step mutated the initial material payload");
  assert.deepEqual(after.simulation_interest, before.simulation_interest, "Step changed simulation interest");
  assert.equal(after.pending_steps, 0, "Step left a queued repeat");
}

export function assertReset(initial, beforeReset, after, { mode = "run" } = {}) {
  assertOrdinaryState(after);
  assert.equal(after.entry, "sandbox", "This reset contract is the paused Sandbox policy");
  assert.equal(after.mode, mode, "Reset selected the wrong Edit/Run ownership");
  assert.equal(after.paused, true, "Sandbox Reset did not stay paused");
  assert.ok(after.generation > beforeReset.generation, "Reset reused a retired session generation");
  assert.equal(after.tick, 0, "Reset did not reconstruct native tick zero");
  assert.equal(after.rapier_steps, 0, "Reset did not reconstruct Rapier step zero");
  assert.equal(after.scene_id, initial.scene_id, "Reset changed the frozen initial scene");
  assert.equal(after.definition_hash, initial.definition_hash, "Reset changed the frozen initial definition");
  assert.equal(after.initial_hash, initial.initial_hash, "Reset changed the native initial material payload");
  assert.equal(after.current_hash, initial.initial_hash, "Reset retained evolved native material state");
  samePhysicalValue(after.body_poses, initial.initial_body_poses, "reset initial body poses");
  samePhysicalValue(after.initial_body_poses, initial.initial_body_poses, "reset initial body definition");
  assert.deepEqual(after.simulation_interest, initial.simulation_interest, "Reset changed authored simulation interest");
  assertInputClear(after);
}

export function assertGallery600(state) {
  assertOrdinaryState(state);
  assert.equal(state.entry, "gallery", "Coupled ordinary run did not use the Gallery entry");
  assert.equal(state.mode, "run", "Gallery did not enter Run");
  assert.equal(state.scene_id, "physics_pit", "Wrong ordinary Gallery scene");
  assert.equal(state.rapier_active, true, "Gallery has no active Rapier bridge");
  assert.equal(state.rapier_available, true, "Actual Rapier availability was not observed");
  assert.equal(state.body_poses.length, 3, "This fixture qualifies the retained three-body scope");
  assert.ok(state.tick >= 600, "Gallery did not complete 600 actual native ticks");
  assert.equal(state.rapier_steps, state.tick, "Gallery native and Rapier counters diverged");
  assert.ok(state.moves > 0, "No actual native material movement was observed");
  assert.ok(state.contacts_total > 0, "No positive native/Rapier contact was observed");
  assert.ok(state.displaced_total > 0, "No positive native/Rapier displacement was observed");
}

export function assertTrustedDelivery(events, expected) {
  for (const request of expected) {
    const candidates = events.slice(request.start_index, request.end_index);
    const match = candidates.find(event => event.type === request.type &&
      (request.code === undefined || event.code === request.code) &&
      (request.button === undefined || event.button === request.button));
    assert.ok(match, `Missing DOM ${request.type} for ${request.action}`);
    assert.equal(match.isTrusted, true, `Untrusted DOM input for ${request.action}`);
    if (match.target !== "CANVAS" && request.allow_godot_ime === true) {
      // The SHA-verified Godot runtime installs this contenteditable sibling
      // and routes its key callbacks to the same native input owner. Only
      // explicitly scoped text-field events may use it; not arbitrary DIVs.
      assert.ok(["keydown","keyup"].includes(request.type), "IME is keyboard-only");
      assert.equal(match.target, "DIV", "Text input missed Godot IME");
      assert.equal(match.targetClass, "ime", "Unexpected IME class");
      assert.equal(match.targetContentEditable, true, "IME must be contenteditable");
      assert.equal(match.targetIsActive, true, "IME must own keyboard focus");
      assert.equal(match.targetSharesCanvasParent, true, "IME must belong to the canvas host");
    } else {
      assert.equal(match.target, "CANVAS", `Input missed the Godot canvas for ${request.action}`);
    }
    assert.equal(match.focused, true, `Input reached an unfocused canvas for ${request.action}`);
    if (request.x !== undefined) {
      const tolerance = request.coordinate_tolerance ?? 1;
      assert.ok(Number.isFinite(tolerance) && tolerance >= 0 && tolerance <= 1, "Invalid input coordinate tolerance");
      assert.ok(Number.isFinite(match.x) && Math.abs(match.x - request.x) <= tolerance,
        `Trusted pointer X differs from the intended CSS coordinate for ${request.action}`);
      assert.ok(Number.isFinite(match.y) && Math.abs(match.y - request.y) <= tolerance,
        `Trusted pointer Y differs from the intended CSS coordinate for ${request.action}`);
    }
    if (request.repeat !== undefined) assert.equal(match.repeat, request.repeat,
      `Browser repeat flag differs for ${request.action}`);
  }
}

// An accepted complete Edit operation is one exact reversible transaction.
export function assertEditMutation(before, after, kind, cells) {
  assertEdit(after);
  assert.equal(after.generation, before.generation);
  assert.equal(after.document.revision, before.document.revision + 1);
  assert.equal(after.document.undo_depth, before.document.undo_depth + 1);
  assert.equal(after.document.redo_depth, 0);
  assert.equal(after.mutation_count, before.mutation_count + 1);
  assert.equal(after.last_edit.accepted, true);
  assert.equal(after.last_edit.mode, "edit");
  assert.equal(after.last_edit.kind, kind);
  if (cells !== undefined) assert.equal(after.last_edit.cells, cells);
  assert.notEqual(after.current_hash, before.current_hash);
  assert.ok(after.native.native_revision > before.native.native_revision);
  samePhysicalValue(after.body_poses, before.body_poses, "Edit operation body poses");
}

export function assertHistoryLocked(state) {
  assertOrdinaryState(state);
  assert.equal(state.mode, "run");
  assert.equal(state.document.locked, true);
  assert.equal(state.document.can_undo, false);
  assert.equal(state.document.can_redo, false);
  if (state.tick > 0 || state.rapier_steps > 0) {
    assert.equal(state.document.retired, true);
    assert.equal(state.document.undo_depth, 0);
    assert.equal(state.document.redo_depth, 0);
    assert.equal(state.document.history_bytes, 0);
    assert.equal(state.history_retired, true);
  }
}

export function assertRunIntervention(before, after, kind) {
  assertHistoryLocked(after);
  assert.equal(before.paused, true);
  assert.equal(after.paused, true);
  assert.equal(after.tick, before.tick);
  assert.equal(after.rapier_steps, before.rapier_steps);
  assert.equal(after.generation, before.generation);
  assert.equal(after.mutation_count, before.mutation_count + 1);
  assert.equal(after.intervention_count, before.intervention_count + 1);
  assert.equal(after.pristine, false);
  assert.equal(after.last_edit.accepted, true);
  assert.equal(after.last_edit.mode, "run");
  assert.equal(after.last_edit.kind, kind);
  assert.deepEqual(after.document, before.document);
  assert.equal(after.definition_hash, before.definition_hash);
  assert.equal(after.initial_hash, before.initial_hash);
  assert.notEqual(after.current_hash, before.current_hash);
  samePhysicalValue(after.body_poses, before.body_poses, "intervention body poses");
}

// A CDP acknowledgement and an unrelated frame count do not prove Godot has
// consumed the motion. Wait for the exact read-only gesture endpoints instead.
export function gestureAcknowledged(state, from, to, afterFrame) {
  return Number.isSafeInteger(state?.frame) && state.frame > afterFrame &&
    state.editor?.gesture_active === true &&
    JSON.stringify(state.editor.preview_first) === JSON.stringify(from) &&
    JSON.stringify(state.editor.preview_last) === JSON.stringify(to);
}
