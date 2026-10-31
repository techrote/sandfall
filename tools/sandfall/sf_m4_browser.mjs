#!/usr/bin/env node
// Source-matched SF-M4 ordinary application acceptance. All application data is
// read-only. Every state transition below uses genuine CDP browser input; this
// harness cannot call a Godot command, edit a tick, or set acceptance success.
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { mkdirSync, readFileSync, writeFileSync, existsSync, renameSync } from "node:fs";
import { basename, dirname, resolve, join } from "node:path";
import { fileURLToPath } from "node:url";
import { analyzePng, pngDimensions } from "./sf_m0_png_stats.mjs";
import { mapGodotRect, cssRectToScreenshotROI } from "./sf_m0_geometry.mjs";
import {analyzeBodies,decodeRgb} from "./sf_m3_pixels.mjs";
import {assertRegistry,assertObjectEdit,assertObjectRefusal,authoredState,assertAuthoredState,
  assertObjectIntervention,assertObjectReset,assertPhysicalWorkload,objects,ids,
  sampleControlLayout,sameControlLayout,controlLayoutSettled} from "./sf_m3_browser_assertions.mjs";
import {mapWorldCell} from "./sf_m2_geometry.mjs";
import {assertRejectedImport,assertProjectInstalled,assertSameLogicalProject,assertFrozenSave,
  assertProjectSource,assertPromotionBoundary,assertBrowserFileDelivery,assertMassOnlyPhysicsPreserved,
  assertBodiesContainedInViewport,unexpectedConsoleErrors} from "./sf_m4_browser_assertions.mjs";
import {
  assertOrdinaryState, assertEdit, assertInputClear, physicalCheckpoint,
  assertPausedStable, assertStep, assertReset, assertGallery600, assertTrustedDelivery,
  assertEditMutation, assertHistoryLocked, assertRunIntervention, gestureAcknowledged,
  samePhysicalValue,
} from "./sf_m2_browser_assertions.mjs";

const argv = new Map();
for (let i = 2; i < process.argv.length; i += 2) argv.set(process.argv[i], process.argv[i + 1]);
const port = Number(argv.get("--port") || "9231");
const url = argv.get("--url") || "http://127.0.0.1:8040/?test=1";
const output = resolve(argv.get("--output") || "sf-m4-browser/browser.json");
const screenshotPath = resolve(argv.get("--screenshot") || "sf-m4-browser/browser.png");
const timeoutMs = Number(argv.get("--timeout-ms") || "1200000");
const width = Number(argv.get("--width") || "800");
const height = Number(argv.get("--height") || "450");
const dpr = Number(argv.get("--dpr") || "1");
const bodyCount = Number(argv.get("--bodies") ?? process.env.SF_M4_BODY_COUNT ?? "16");
if (![0,1,3,8,16].includes(bodyCount)) throw Error("SF-M4 workload must be one of 0,1,3,8,16");
const scenario = argv.get("--scenario") || "projects";
if(!["projects","gallery"].includes(scenario))throw Error("Unknown SF-M4 scenario");
const galleryEntries=[['gravity_cascade','Gravity Cascade',3],['fluid_messenger','Fluid Messenger',1],
  ['passive_subject_ride','Passive Subject Ride',3],['endless_kinetic_loop','Endless Kinetic Loop',3],
  ['intervention','Intervention Workshop',3],['time_controls','Time Controls',3],['sixteen_body','Sandfall 16-Body',16]];
const galleryEntry=argv.get('--gallery-entry')??null;
if(galleryEntry&&(scenario!=='gallery'||!galleryEntries.some(row=>row[0]===galleryEntry)))
  throw Error('An isolated Gallery capture requires a registered exhibition entry');
const downloadDir=resolve(argv.get("--download-dir")||join(dirname(output),"downloads"));
mkdirSync(downloadDir,{recursive:true});
const verificationPath = argv.get("--verification");
if (!verificationPath) throw Error("A SHA-verified SF-M4 export receipt is required (--verification)");
const verificationBytes = readFileSync(verificationPath);
const verification = JSON.parse(verificationBytes);
if (verification.status !== "passed" || !verification.logical_viewport)
  throw Error("Web export verification failed or lacks a source-bound viewport");
if (verification.application_entry !== "sandfall" || verification.entry_scene !== "res://sandfall_main.tscn")
  throw Error("Verified export is not the dedicated Sandfall application");
const layout = verification.logical_viewport;
const query = [...new URL(url).searchParams];
if (query.length !== 1 || query[0][0] !== "test" || query[0][1] !== "1")
  throw Error("Ordinary acceptance permits only the read-only ?test=1 observation mode");
if (![width, height, dpr, timeoutMs].every(x => Number.isFinite(x) && x > 0))
  throw Error("Invalid browser dimensions or timeout");
const sha256 = bytes => createHash("sha256").update(bytes).digest("hex");
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
const copy = value => structuredClone(value);
const harnessInputs = ["sf_m4_browser.mjs", "sf_m4_browser_assertions.mjs", "sf_m4_archive_fixture.py", "sf_m3_browser_assertions.mjs", "sf_m3_pixels.mjs", "sf_m2_browser_assertions.mjs", "sf_m2_geometry.mjs", "sf_m0_geometry.mjs", "sf_m0_png_stats.mjs"]
  .map(path => ({path, sha256:sha256(readFileSync(new URL(path, import.meta.url)))}));
const repoRoot = fileURLToPath(new URL("../../",import.meta.url));
const harnessHead = execFileSync("git",["-C",repoRoot,"rev-parse","HEAD"],{encoding:"utf8"}).trim();
const dirtyHarness = execFileSync("git",["-C",repoRoot,"status","--porcelain","--",
  ...harnessInputs.map(value=>"tools/sandfall/"+value.path)],{encoding:"utf8"}).trim().split("\n").filter(Boolean);
const harnessCheckout = {head_commit:harnessHead,
  identity_kind:dirtyHarness.length ? "working-tree-harness" : "committed-harness",dirty_paths:dirtyHarness};
const started = Date.now();
const observations = [], consoleEvents = [], inputEvents = [], expectedDOM = [];
const captures = [], transitions = [], checks = [], checkpoints = [], failures = [], servedIdentity = [];
const controlLayouts = [];
const downloads=[],fileChoosers=[],fileTransfers=[],archiveReceipts=[],runReceipts=[],galleryRuns=[];
const expectedDiagnostics=[];
let ws, nextId = 0, originalTarget, secondaryTarget;
let state = null, metrics = null, domInputEvents = [], browserVersion = null;
let phase = "startup", captureStarted = false, pollErrors = 0, lastLog = "", lastLogAt = 0;
const pending = new Map();

function cmd(method, params = {}, deadlineMs = 30000) {
  return new Promise((resolve, reject) => {
    const id = ++nextId;
    const timeout = setTimeout(() => {
      if (pending.delete(id)) reject(Error(method + " CDP deadline expired"));
    }, deadlineMs);
    pending.set(id, {
      resolve:value => { clearTimeout(timeout); resolve(value); },
      reject:error => { clearTimeout(timeout); reject(error); },
    });
    try { ws.send(JSON.stringify({id, method, params})); }
    catch (error) { pending.delete(id); clearTimeout(timeout); reject(error); }
  });
}

async function observe() {
  const result = await cmd("Runtime.evaluate", {
    // This expression has no application writes. The separate passive event
    // listener observes browser delivery, not Godot's exported test state.
    expression:`(() => {
      const canvas = document.querySelector('canvas');
      return {text:document.getElementById('sandfall-test-state')?.textContent ?? '',
        metrics:{canvas:canvas?.getBoundingClientRect().toJSON() ?? null,
          backing:canvas ? {width:canvas.width,height:canvas.height} : null,
          viewport:{width:innerWidth,height:innerHeight},devicePixelRatio,
          visualViewport:visualViewport ? {width:visualViewport.width,height:visualViewport.height,
            offsetLeft:visualViewport.offsetLeft,offsetTop:visualViewport.offsetTop,scale:visualViewport.scale} : null,
          documentFocused:document.hasFocus(),visibility:document.visibilityState,
          activeElement:{tag:document.activeElement?.tagName,id:document.activeElement?.id},
          canvasStyle:canvas ? {width:getComputedStyle(canvas).width,height:getComputedStyle(canvas).height,
            transform:getComputedStyle(canvas).transform,objectFit:getComputedStyle(canvas).objectFit} : null,
          title:document.title,userAgent:navigator.userAgent,isolated:crossOriginIsolated},
        input:window.__sandfallObservedInput ?? []};
    })()`, returnByValue:true,
  });
  if (result.exceptionDetails) throw Error("Browser state read failed: " + JSON.stringify(result.exceptionDetails));
  const value = result.result?.value;
  if (!value) throw Error("Browser state read returned no object");
  metrics = value.metrics;
  domInputEvents = value.input;
  if (!value.text) return null;
  state = JSON.parse(value.text);
  if (state.app_ready) assertOrdinaryState(state, {requireReady:false});
  const sample = {elapsed_ms:Date.now()-started,phase,frame:state.frame,app_ready:state.app_ready,
    ready:state.ready,entry:state.entry,scene_id:state.scene_id,mode:state.mode,
    generation:state.generation,menu:state.menu,paused:state.paused,tick:state.tick,
    native_revision:state.native?.native_revision,
    rapier_steps:state.rapier_steps,rapier_active:state.rapier_active,moves:state.moves,
    contacts_total:state.contacts_total,displaced_total:state.displaced_total,
    workers:state.workers,actor_count:state.actor_count,pending_steps:state.pending_steps,
    input:state.input,camera:state.camera,current_hash:state.current_hash,
    document:state.document,editor:state.editor,mutation_count:state.mutation_count,
    project_file:state.project_file,project_modal:state.project_modal,promotion:state.promotion,presentation:state.presentation,
    object_definitions:objects(state),body_ids:state.native?.body_ids,body_states:state.native?.body_states,
    body_sizes:state.native?.body_sizes,slot_mapping:state.native?.slot_mapping,
    object_feedback:state.native?.object_feedback,body_body_pairs:state.native?.body_body_pairs,
    pristine:state.pristine,intervention_count:state.intervention_count,last_edit:state.last_edit,
    last_refusal:state.last_refusal,render_rejections:state.render_rejections,document_focused:metrics.documentFocused,
    visibility:metrics.visibility};
  observations.push(sample);
  const logKey = JSON.stringify([phase,state.generation,state.mode,state.menu,state.paused]);
  if (logKey !== lastLog || Date.now()-lastLogAt > 10000) {
    console.log("SF_M4_BROWSER_OBSERVATION", JSON.stringify(sample));
    lastLog = logKey; lastLogAt = Date.now();
  }
  return state;
}

async function waitFor(label, predicate, budgetMs = 90000) {
  phase = label;
  const deadline = Math.min(started + timeoutMs, Date.now() + budgetMs);
  while (Date.now() < deadline) {
    try {
      const current = await observe();
      if (current && predicate(current)) {
        transitions.push({phase:label,elapsed_ms:Date.now()-started,frame:current.frame,
          generation:current.generation,tick:current.tick,rapier_steps:current.rapier_steps,
          mode:current.mode,menu:current.menu,paused:current.paused});
        return copy(current);
      }
    } catch (error) {
      if (!String(error).includes("CDP deadline expired")) throw error;
      pollErrors++;
      console.warn("SF_M4_BROWSER_POLL", String(error));
    }
    await sleep(250);
  }
  throw Error("Timed out waiting for " + label);
}

function check(name, callback) {
  try {
    callback();
    checks.push({name,status:"passed",elapsed_ms:Date.now()-started,frame:state?.frame,
      generation:state?.generation,tick:state?.tick,rapier_steps:state?.rapier_steps});
    console.log("SF_M4_BROWSER_CHECK", name);
  } catch (error) {
    checks.push({name,status:"failed",error:String(error),elapsed_ms:Date.now()-started});
    throw Error(name + ": " + error);
  }
}

function checkpoint(name) {
  const value = physicalCheckpoint(state);
  checkpoints.push({name,elapsed_ms:Date.now()-started,state:value,metrics:copy(metrics)});
  return value;
}

async function stable(label, before, options = {}) {
  assert.ok(Number.isSafeInteger(before.frame), "A monotonic application frame observation is required");
  const framesFrom = Math.max(before.frame,state?.frame ?? 0);
  // Require distinct normal Godot process frames, not repeated DOM reads of a
  // stale paused sample. Wall-clock delay is additional evidence, not the gate.
  await sleep(500);
  await waitFor(label, s => s.frame >= framesFrom + 3 && s.paused === true);
  check(label, () => assertPausedStable(before,state,options));
  return copy(state);
}

async function input(method, params) {
  if (captureStarted) throw Error("Browser input cannot follow terminal screenshot capture");
  const event = {elapsed_ms:Date.now()-started,phase,method,params,acknowledged:false};
  inputEvents.push(event);
  // Send once. A delayed acknowledgment cannot justify retrying a toggle.
  try { await cmd(method,params,18000); event.acknowledged = true; }
  catch (error) { event.error = String(error); }
}

async function click(name, {holdMs = 100, heldBaseline = null} = {}) {
  let baseline=null,confirmed=null;
  // Wait before the single input attempt. A semantic tool-group/tab change can
  // precede Godot's deferred Container reflow; neither a fixed delay nor a retry
  // of a missed toggle establishes the actual Control coordinates.
  await waitFor('control-'+name+'-layout-settled',s=>{
    const current=sampleControlLayout(s,metrics,layout,name);
    if(controlLayoutSettled(baseline,current)){confirmed=current;return true;}
    if(!sameControlLayout(baseline,current)||current.frame<baseline.frame)baseline=current;
    return false;
  },15000);
  assert.ok(controlLayoutSettled(baseline,confirmed),'Control geometry never settled on newer Godot frames');
  const rect=confirmed.geometry.rect,mapped=confirmed.mapped;
  controlLayouts.push({name,elapsed_ms:Date.now()-started,first_frame:baseline.frame,
    confirmed_frame:confirmed.frame,geometry:confirmed.geometry,mapped});
  const {x,y} = mapped.center;
  const startIndex = domInputEvents.length;
  inputEvents.push({action:name,elapsed_ms:Date.now()-started,godot:rect,mapped,metrics:copy(metrics)});
  await input("Input.dispatchMouseEvent",{type:"mouseMoved",x,y,buttons:0});
  await input("Input.dispatchMouseEvent",{type:"mousePressed",button:"left",buttons:1,x,y,clickCount:1});
  await sleep(holdMs);
  if (heldBaseline) {
    await observe();
    check("held-Step-does-not-repeat-before-release", () => {
      assert.equal(state.paused,true);
      assert.equal(state.generation,heldBaseline.generation);
      assert.ok(state.tick-heldBaseline.tick >= 0 && state.tick-heldBaseline.tick <= 1,
        "A held Step generated repeated native ticks");
      assert.ok(state.rapier_steps-heldBaseline.rapier_steps >= 0 &&
        state.rapier_steps-heldBaseline.rapier_steps <= (heldBaseline.rapier_active ? 1 : 0),
      "A held Step generated repeated or inactive Rapier work");
    });
  }
  await input("Input.dispatchMouseEvent",{type:"mouseReleased",button:"left",buttons:0,x,y,clickCount:1});
  await observe();
  for (const type of ["pointerdown","pointerup"])
    expectedDOM.push({action:name,type,button:0,x,y,start_index:startIndex,end_index:domInputEvents.length});
}

async function keyEvent(type, key, code, keyCode, {repeat = false, modifiers = 0, allowGodotIME = false} = {}) {
  await observe();
  const startIndex = domInputEvents.length;
  await input("Input.dispatchKeyEvent",{type,key,code,autoRepeat:repeat,
    windowsVirtualKeyCode:keyCode,nativeVirtualKeyCode:keyCode,modifiers});
  await observe();
  expectedDOM.push({action:`${code}-${type}${repeat ? "-repeat" : ""}`,
    type:type === "keyUp" ? "keyup" : "keydown",code,repeat,allow_godot_ime:allowGodotIME,
    start_index:startIndex,end_index:domInputEvents.length});
}

async function key(key, code, keyCode, options = {}) {
  await keyEvent("keyDown",key,code,keyCode,options);
  await keyEvent("keyUp",key,code,keyCode,options);
}

async function legacyKeys() {
  for (const [keyValue,code,keyCode] of [["w","KeyW",87],["a","KeyA",65],["s","KeyS",83],
      ["d","KeyD",68],[" ","Space",32],["e","KeyE",69],["q","KeyQ",81],["Shift","ShiftLeft",16]])
    await key(keyValue,code,keyCode);
}

async function worldClick(button) {
  await observe();
  const point = worldPoint();
  const startIndex = domInputEvents.length;
  const mask = button === "left" ? 1 : 2;
  const domButton = button === "left" ? 0 : 2;
  inputEvents.push({action:`world-${button}-no-tool`,elapsed_ms:Date.now()-started,
    world_godot:state.view,point,metrics:copy(metrics)});
  await input("Input.dispatchMouseEvent",{type:"mouseMoved",...point,buttons:0});
  await input("Input.dispatchMouseEvent",{type:"mousePressed",button,buttons:mask,...point,clickCount:1});
  await input("Input.dispatchMouseEvent",{type:"mouseReleased",button,buttons:0,...point,clickCount:1});
  await observe();
  for (const type of ["pointerdown","pointerup"])
    expectedDOM.push({action:`world-${button}-no-tool`,type,button:domButton,...point,
      start_index:startIndex,end_index:domInputEvents.length});
}

function worldPoint(dx = 0, dy = 0) {
  const mapped = mapGodotRect(state.view,metrics,layout);
  return {x:mapped.center.x+dx,y:mapped.center.y+dy};
}

async function beginDrag() {
  await observe();
  const point = worldPoint();
  const before = physicalCheckpoint(state);
  const startIndex = domInputEvents.length;
  await input("Input.dispatchMouseEvent",{type:"mouseMoved",...point,buttons:0});
  await input("Input.dispatchMouseEvent",{type:"mousePressed",button:"middle",buttons:4,...point,clickCount:1});
  // Drag left/up so the clamped initial origin actually moves into the world.
  // A right/down drag at origin zero could hide a stale-gesture defect.
  await input("Input.dispatchMouseEvent",{type:"mouseMoved",x:point.x-16,y:point.y-8,buttons:4});
  await waitFor("middle-camera-gesture-active",s => s.input?.gesture_active === true &&
    JSON.stringify(s.camera) !== JSON.stringify(before.camera));
  check("genuine-middle-drag-moves-only-camera",()=>assertPausedStable(before,state));
  expectedDOM.push({action:"camera-middle-drag",type:"pointerdown",button:1,...point,
    start_index:startIndex,end_index:domInputEvents.length});
  return {x:point.x-16,y:point.y-8};
}

async function releaseMiddle(point, {expectCanvas = true} = {}) {
  await observe();
  const startIndex = domInputEvents.length;
  await input("Input.dispatchMouseEvent",{type:"mouseReleased",button:"middle",buttons:0,...point,clickCount:1});
  await observe();
  if (expectCanvas) expectedDOM.push({action:"camera-middle-release",type:"pointerup",button:1,...point,
    start_index:startIndex,end_index:domInputEvents.length});
}

async function pausedStep(active) {
  const before = checkpoint(active ? "coupled-Step-before" : "native-Step-before");
  phase = active ? "coupled-held-Step" : "native-held-Step";
  await click("step",{holdMs:800,heldBaseline:before});
  await waitFor("single-Step-completed",s => s.paused && s.tick >= before.tick+1);
  check(active ? "exact-one-native-and-Rapier-Step" : "exact-one-native-zero-Rapier-Step",
    () => assertStep(before,state,active));
  const after = checkpoint(active ? "coupled-Step-after" : "native-Step-after");
  await stable("Step-remains-paused-with-no-repeat",after);
}

async function sandboxReset(initial, mode) {
  const before = checkpoint(mode === "edit" ? "before-Reset-and-Edit" : "before-Reset");
  await click(mode === "edit" ? "reset_edit" : "reset");
  await waitFor(mode === "edit" ? "Reset-and-Edit-reconstructed" : "Reset-reconstructed",
    s => s.ready && s.generation > before.generation && s.paused && s.tick === 0 && s.mode === mode);
  check(mode === "edit" ? "Reset-and-Edit-initial-identity" : "Reset-initial-identity",
    () => assertReset(initial,before,state,{mode}));
  await stable("reconstructed-session-stays-paused",checkpoint("reconstructed-"+mode));
}

async function capture(name, scoreWorld = false) {
  if (captureStarted) throw Error("A second capture cannot overlap or follow a timed-out capture");
  captureStarted = true;
  const snap = {name,phase,elapsed_ms:Date.now()-started,state:copy(state),metrics:copy(metrics),
    method:"Page.captureScreenshot",from_surface:false,capture_deadline_ms:150000};
  captures.push(snap);
  try {
    const result = await cmd("Page.captureScreenshot",{format:"png",fromSurface:false},150000);
    const bytes = Buffer.from(result.data,"base64");
    const path = name === "world" ? screenshotPath : screenshotPath.replace(/\.png$/,"-"+name+".png");
    mkdirSync(dirname(path),{recursive:true});
    writeFileSync(path,bytes);
    const dimensions = pngDimensions(bytes);
    Object.assign(snap,{path,sha256:sha256(bytes),size_bytes:bytes.length,screenshot:dimensions,
      completed_elapsed_ms:Date.now()-started});
    if (scoreWorld) {
      assert.equal(state.menu,false,"A modal cannot qualify world pixels");
      assert.equal(metrics.canvasStyle?.transform,"none","Unexpected CSS canvas transform");
      assert.equal(metrics.visualViewport?.scale,1,"Unexpected browser page zoom");
      const mapped = mapGodotRect(state.view,metrics,layout);
      const roi = cssRectToScreenshotROI(mapped.css,metrics.viewport,dimensions,2);
      Object.assign(snap,{world_godot:state.view,world_css:mapped.css,transform:mapped.transform,
        pixels:analyzePng(bytes,roi),object_pixels:analyzeBodies(bytes,state,metrics,layout)});
    }
    return snap;
  } catch (error) {
    snap.error = String(error);
    if (scoreWorld) throw error;
    console.warn("SF_M4_BROWSER_CAPTURE", String(error));
    return snap;
  }
}

function cellPoint(cell) {
  return mapWorldCell(cell,state.view,state.camera,metrics,layout).point;
}

async function tool(name) {
  await click("tool_"+name);
  await waitFor("tool-"+name,s=>s.editor.tool === name);
}
async function material(name,id) {
  await click("material_"+name);
  await waitFor("material-"+name,s=>s.editor.primary.id === id);
}
async function field(name,text,predicate) {
  await click(name);
  await keyEvent("keyDown","a","KeyA",65,{modifiers:2,allowGodotIME:true});
  await keyEvent("keyUp","a","KeyA",65,{modifiers:2,allowGodotIME:true});
  for (const ch of String(text)) {
    const code = ch === "-" ? "Minus" : ch === "." ? "Period" : "Digit"+ch;
    const keyCode = ch === "-" ? 189 : ch === "." ? 190 : ch.charCodeAt(0);
    await observe();
    const startIndex=domInputEvents.length;
    await input("Input.dispatchKeyEvent",{type:"keyDown",key:ch,code,
      windowsVirtualKeyCode:keyCode,nativeVirtualKeyCode:keyCode,text:ch,unmodifiedText:ch});
    await input("Input.dispatchKeyEvent",{type:"keyUp",key:ch,code,
      windowsVirtualKeyCode:keyCode,nativeVirtualKeyCode:keyCode});
    await observe();
    for (const type of ["keydown","keyup"]) expectedDOM.push({action:name+"-text-"+ch,type,code,
      repeat:false,allow_godot_ime:true,start_index:startIndex,end_index:domInputEvents.length});
  }
  await key("Enter","Enter",13,{allowGodotIME:true});
  await waitFor("field-"+name+"-"+text,predicate);
}
async function stroke(a,b,{button="left",preview=false,label="stroke"}={}) {
  await observe();
  const before=copy(state),start=cellPoint(a),end=cellPoint(b);
  const startIndex=domInputEvents.length,mask=button === "left" ? 1 : 2,domButton=button === "left" ? 0 : 2;
  inputEvents.push({action:label,cells:{from:a,to:b},points:{from:start,to:end},
    actual_view:state.view,camera:copy(state.camera),metrics:copy(metrics),elapsed_ms:Date.now()-started});
  await input("Input.dispatchMouseEvent",{type:"mouseMoved",...start,buttons:0});
  await input("Input.dispatchMouseEvent",{type:"mousePressed",button,buttons:mask,...start,clickCount:1});
  await sleep(120);
  await observe();
  const pressedFrame=state.frame;
  await input("Input.dispatchMouseEvent",{type:"mouseMoved",...end,buttons:mask});
  if (preview) {
    // Observe a processed motion, then assert the exact cells independently of
    // the changed-cell count. A one-cell shift must not pass as an equal-size edit.
    await waitFor(label+"-preview",s=>gestureAcknowledged(s,a,b,pressedFrame),30000);
    check(label+"-exact-gesture-cells",()=>{
      assert.deepEqual(state.editor.preview_first,a);
      assert.deepEqual(state.editor.preview_last,b);
    });
    check(label+"-preview-does-not-mutate-or-step",()=>assertPausedStable(before,state));
  }
  await input("Input.dispatchMouseEvent",{type:"mouseReleased",button,buttons:0,...end,clickCount:1});
  await sleep(140);
  await observe();
  for (const type of ["pointerdown","mousedown"])
    expectedDOM.push({action:label,type,button:domButton,...start,coordinate_tolerance:1e-4,start_index:startIndex,end_index:domInputEvents.length});
  for (const type of ["pointerup","mouseup"])
    expectedDOM.push({action:label,type,button:domButton,...end,coordinate_tolerance:1e-4,start_index:startIndex,end_index:domInputEvents.length});
  return before;
}
async function editStroke(a,b,kind,cells,label=kind) {
  const before=await stroke(a,b,{preview:kind!=="flood_fill",label});
  await waitFor(label+"-committed",s=>s.document.revision>before.document.revision && !s.editor.fill_active);
  check(label+"-one-exact-Edit-transaction",()=>assertEditMutation(before,state,kind,cells));
  return checkpoint(label+"-after");
}
async function history(direction,expectedHash) {
  await observe();
  const before=copy(state);
  await click(direction);
  await waitFor(direction+"-committed",s=>s.document.revision>before.document.revision);
  check(direction+"-exact-bytes-zero-ticks",()=>{
    assertEdit(state);
    assert.equal(state.current_hash,expectedHash);
    assert.equal(state.document.revision,before.document.revision+1);
    assert.equal(state.document.undo_depth,before.document.undo_depth+(direction==="undo"?-1:1));
    assert.equal(state.document.redo_depth,before.document.redo_depth+(direction==="undo"?1:-1));
  });
  return checkpoint(direction+"-after");
}
async function pick(cell,expected) {
  await tool("picker");
  await stroke(cell,cell,{label:"inspect-"+cell.join("-")});
  await waitFor("actual-cell-inspected",s=>s.editor.inspected.x===cell[0] && s.editor.inspected.y===cell[1]);
  check("picker-reads-full-native-tuple-"+cell.join("-"),()=>{
    for (const [key,value] of Object.entries(expected)) assert.equal(state.editor.inspected[key],value,"picker "+key);
  });
}

async function group(name) {
  await click('mode_'+name);
  await waitFor('tool-group-'+name,s=>s.editor.tool_group===name);
}
async function objectTool(name) {
  await click('object_'+name);
  await waitFor('object-tool-'+name,s=>s.editor.object_tool===name&&s.editor.tool_group==='objects');
}
function physicalPoint(position) {
  const view=mapGodotRect(state.view,metrics,layout).css;
  const origin=state.camera.camera_origin,size=state.camera.view_size;
  const point={x:Math.round(view.x+(position[0]-origin[0])/size[0]*view.width),
    y:Math.round(view.y+(position[1]-origin[1])/size[1]*view.height)};
  assert.ok(point.x>view.x&&point.x<view.x+view.width&&point.y>view.y&&point.y<view.y+view.height,
    'Physical point must lie inside the measured world viewport');
  return {point,world:[origin[0]+(point.x-view.x)/view.width*size[0],
    origin[1]+(point.y-view.y)/view.height*size[1]]};
}
const closePair=(a,b)=>Array.isArray(a)&&a.length===2&&a.every((n,i)=>Number.isFinite(n)&&Math.abs(n-b[i])<.02);
async function objectGesture(from,to,{label='object-gesture',preview=true}={}) {
  await observe();
  const before=copy(state),a=physicalPoint(from),b=physicalPoint(to),startIndex=domInputEvents.length;
  inputEvents.push({action:label,requested_world:{from,to},measured_world:{from:a.world,to:b.world},
    points:{from:a.point,to:b.point},view:copy(state.view),camera:copy(state.camera),metrics:copy(metrics),elapsed_ms:Date.now()-started});
  await input('Input.dispatchMouseEvent',{type:'mouseMoved',...a.point,buttons:0});
  await input('Input.dispatchMouseEvent',{type:'mousePressed',button:'left',buttons:1,...a.point,clickCount:1});
  await sleep(150);await observe();const pressedFrame=state.frame;
  await input('Input.dispatchMouseEvent',{type:'mouseMoved',...b.point,buttons:1});
  if(preview) {
    const selected=objects(before)?.find(x=>x.id===before.editor.selected_object_id);
    let expectedPosition;
    if(before.editor.object_tool==='box') expectedPosition=Math.hypot(b.world[0]-a.world[0],b.world[1]-a.world[1])<2?a.world:a.world.map((n,i)=>(n+b.world[i])*.5);
    else if(before.editor.object_tool==='move'&&selected)expectedPosition=selected.position.map((n,i)=>n+b.world[i]-a.world[i]);
    await waitFor(label+'-genuine-motion-preview',v=>v.frame>pressedFrame&&v.editor.object_gesture_active&&
      (!expectedPosition||closePair(v.editor.object_preview.position,expectedPosition)));
    check(label+'-preview-does-not-mutate',()=>assertObjectRefusal(before,state));
  }
  await input('Input.dispatchMouseEvent',{type:'mouseReleased',button:'left',buttons:0,...b.point,clickCount:1});
  await sleep(160);await observe();
  for(const type of ['pointerdown','mousedown'])expectedDOM.push({action:label,type,button:0,...a.point,
    coordinate_tolerance:1e-4,start_index:startIndex,end_index:domInputEvents.length});
  for(const type of ['pointerup','mouseup'])expectedDOM.push({action:label,type,button:0,...b.point,
    coordinate_tolerance:1e-4,start_index:startIndex,end_index:domInputEvents.length});
  return before;
}
async function selectObject(id) {
  await objectTool('select');await observe();
  const slot=ids(state).indexOf(id);assert.ok(slot>=0,'Cannot select an absent object');
  const point=state.native.body_states[slot].slice(0,2);
  await objectGesture(point,point,{label:'select-stable-'+id,preview:false});
  await waitFor('selected-stable-'+id,s=>s.editor.selected_object_id===id&&s.editor.object_inspector?.selected_id===id);
  check('selection-preserves-stable-id-'+id,()=>assert.equal(state.editor.selected_object.id,id));
}
async function inspector(tab,values) {
  const before=checkpoint('before-inspector-'+tab);
  await click('object_tab_'+tab);
  await waitFor('inspector-page-'+tab,s=>s.editor.object_inspector.tab===tab);
  for(const [name,value] of Object.entries(values))await field('object_'+name,String(value),
    s=>Math.abs(s.editor.object_inspector.values[name]-value)<1e-6);
  check('inspector-'+tab+'-is-staged-and-cannot-paint-through',()=>assertObjectRefusal(before,state));
}
async function applyInspector(expectedCount,{run=false,label='object-properties'}={}) {
  const before=checkpoint('before-'+label);
  await click('object_apply');
  await waitFor(label+'-accepted',s=>s.mutation_count>before.mutation_count);
  check(label+'-one-transaction',()=>run?assertObjectIntervention(before,state,expectedCount):assertObjectEdit(before,state,expectedCount));
  return authoredState(state);
}
async function objectCommand(name,expectedCount,{run=false,label=name}={}) {
  const before=checkpoint('before-'+label);
  await click('object_'+name);
  await waitFor(label+'-accepted',s=>s.mutation_count>before.mutation_count);
  check(label+'-one-transaction',()=>run?assertObjectIntervention(before,state,expectedCount):assertObjectEdit(before,state,expectedCount));
  return before;
}
async function exactHistory(direction,expected) {
  const before=copy(state);await click(direction);
  await waitFor('mixed-'+direction+'-committed',s=>s.document.revision>before.document.revision);
  check('mixed-'+direction+'-exact-tuples-identities-poses-properties',()=>{
    assertAuthoredState(state,expected);
    assert.equal(state.document.revision,before.document.revision+1);
    assert.equal(state.document.undo_depth,before.document.undo_depth+(direction==='undo'?-1:1));
    assert.equal(state.document.redo_depth,before.document.redo_depth+(direction==='undo'?1:-1));
  });
}
async function runWorkload(initial,label) {
  await observe();
  const beforeProbe=copy(state.native.rapier_probe),probeDeferred=state.native.rapier_probe_deferred;
  await click('run');
  const target=bodyCount?600:60;
  await waitFor(label+'-actual-physics',s=>s.mode==='run'&&s.tick>=target,300000);
  await click('pause');await waitFor(label+'-paused',s=>s.paused);
  check(label+'-independent-live-physics',()=>assertPhysicalWorkload(initial,state,bodyCount,
    {minimumTicks:target,bodyContacts:bodyCount===16}));
  if(bodyCount===0)check(label+'-zero-body-workload-performs-no-capability-probe',()=>{
    assert.equal(state.native.rapier_probe_deferred,probeDeferred);
    assert.deepEqual(state.native.rapier_probe,beforeProbe);
  });
  checkpoints.push({name:label+'-physical-result',elapsed_ms:Date.now()-started,state:copy(state),metrics:copy(metrics)});
}
async function resetObjects(initial,edit) {
  const before=checkpoint(edit?'before-object-Reset-and-Edit':'before-object-Reset');
  await click(edit?'reset_edit':'reset');
  await waitFor(edit?'object-Reset-and-Edit':'object-Reset',s=>s.ready&&s.generation>before.generation&&s.paused&&s.tick===0&&s.mode===(edit?'edit':'run'));
  check(edit?'objects-reconstruct-exactly-with-fresh-history':'objects-reconstruct-exactly-with-Run-locked',()=>assertObjectReset(initial,before,state,{edit}));
}
async function cancelledObjectGesture() {
  await objectTool('box');const before=checkpoint('before-object-blur');const a=physicalPoint([430,40]);
  await input('Input.dispatchMouseEvent',{type:'mouseMoved',...a.point,buttons:0});
  const startIndex=domInputEvents.length;
  await input('Input.dispatchMouseEvent',{type:'mousePressed',button:'left',buttons:1,...a.point,clickCount:1});
  await waitFor('object-drag-held-before-blur',s=>s.editor.object_gesture_active);
  expectedDOM.push({action:'object-drag-before-blur',type:'pointerdown',button:0,...a.point,
    coordinate_tolerance:1e-4,start_index:startIndex,end_index:domInputEvents.length});
  secondaryTarget=(await cmd('Target.createTarget',{url:'about:blank'})).targetId;
  await cmd('Target.activateTarget',{targetId:secondaryTarget});
  await waitFor('object-drag-retired-by-actual-blur',s=>metrics.documentFocused===false&&!s.editor.object_gesture_active&&s.input.pointer_buttons===0);
  check('object-blur-refuses-physical-mutation',()=>assertObjectRefusal(before,state));
  await cmd('Target.activateTarget',{targetId:originalTarget});await cmd('Page.bringToFront');
  await waitFor('object-canvas-refocused',()=>metrics.documentFocused===true);
  const b=physicalPoint([438,48]);
  const staleStart=domInputEvents.length;
  inputEvents.push({action:'stale-object-release-after-refocus',requested_world:[438,48],
    measured_world:b.world,point:b.point,view:copy(state.view),camera:copy(state.camera),
    metrics:copy(metrics),elapsed_ms:Date.now()-started});
  await input('Input.dispatchMouseEvent',{type:'mouseMoved',...b.point,buttons:1});
  await input('Input.dispatchMouseEvent',{type:'mouseReleased',button:'left',buttons:0,...b.point,clickCount:1});
  await observe();
  for(const type of ['pointermove','mousemove','pointerup','mouseup'])expectedDOM.push({
    action:'stale-object-release-after-refocus',type,...b.point,...(type.endsWith('up')?{button:0}:{}),
    coordinate_tolerance:1e-4,start_index:staleStart,end_index:domInputEvents.length});
  await stable('stale-object-release-cannot-create-body',before);
  check('stale-object-release-preserves-object-graph',()=>assertObjectRefusal(before,state));
  await cmd('Target.closeTarget',{targetId:secondaryTarget});secondaryTarget=null;
  await key('Escape','Escape',27);await waitFor('object-modal-entered',s=>s.menu);
  const modal=checkpoint('object-modal');
  await objectGesture([430,40],[438,48],{label:'object-modal-world-click',preview:false});
  await stable('modal-object-click-is-inert',modal);
  check('modal-preserves-object-graph',()=>assertObjectRefusal(modal,state));
  await click('continue');await waitFor('object-modal-closed',s=>!s.menu);
}

function externalFixture(command,source,{destination=null,kind=null,label='archive'}={}) {
  const receiptPath=join(downloadDir,label+'.json');
  const args=[join(repoRoot,'tools/sandfall/sf_m4_archive_fixture.py'),command,source,'--output',receiptPath];
  if(destination)args.push('--destination',destination);
  if(kind)args.push('--kind',kind);
  execFileSync('python3',args,{timeout:120000,stdio:'pipe'});
  const receipt=JSON.parse(readFileSync(receiptPath));
  archiveReceipts.push({label,receipt_path:receiptPath,receipt_sha256:sha256(readFileSync(receiptPath)),...receipt});
  return receipt;
}

async function waitForBrowserEvent(label,predicate,budget=30000) {
  phase=label;const deadline=Math.min(started+timeoutMs,Date.now()+budget);
  while(Date.now()<deadline){const result=predicate();if(result)return result;await sleep(100);}
  throw Error('Timed out waiting for browser event '+label);
}

async function download(name,kind='authored_initial') {
  const index=downloads.length,before=copy(state),serial=state.project_file.export_count;
  await click(kind==='run_evidence'?'file_evidence':'file_save');
  await waitFor(name+'-actual-download-request',s=>s.project_file.export_count>serial);
  const event=await waitForBrowserEvent(name+'-download-will-begin',()=>downloads[index]);
  assert.ok(event.url.startsWith('blob:'),'The file did not originate from the application Blob download');
  await waitForBrowserEvent(name+'-download-completed',()=>event.status==='completed'&&existsSync(join(downloadDir,event.guid)),60000);
  const extension=kind==='run_evidence'?'.sandfall-run.json':'.sandfall';
  assert.ok(event.suggestedFilename.endsWith(extension),'Download is labelled as the wrong artifact type');
  const path=join(downloadDir,name+extension);
  renameSync(join(downloadDir,event.guid),path);
  const bytes=readFileSync(path),record=state.project_file.last_export;
  check(name+'-delivered-bytes-match-owner-receipt',()=>{
    assert.equal(record.kind,kind);assert.equal(record.sha256,sha256(bytes));assert.equal(record.bytes,bytes.length);
    assert.equal(record.filename,event.suggestedFilename);assert.equal(state.tick,before.tick);
    assert.equal(state.rapier_steps,before.rapier_steps);assert.equal(state.generation,before.generation);
    assert.deepEqual(state.document,before.document,'Export mutated authored state/history');
  });
  Object.assign(event,{path,sha256:sha256(bytes),bytes:bytes.length,owner_receipt:copy(record)});
  if(kind==='run_evidence') {
    const evidence=JSON.parse(bytes);
    runReceipts.push({name,path,sha256:sha256(bytes),evidence});
    return {path,evidence,record:copy(record)};
  }
  const inspection=externalFixture('inspect',path,{label:name+'-inspection'});
  check(name+'-logical-identity-is-independent-manifest-digest',()=>{
    assert.equal(record.logical_sha256,inspection.manifest_bytes_sha256);
    assert.equal(record.initial_cells_sha256,inspection.world_sha256);
  });
  return {path,inspection,record:copy(record)};
}

async function upload(path,{accept=true,label='project-import',expectedCRC=false}={}) {
  const before=copy(state),chooserIndex=fileChoosers.length,serial=state.project_file.operation_serial;
  await click('file_open');
  const chooser=await waitForBrowserEvent(label+'-genuine-file-chooser',()=>fileChoosers[chooserIndex]);
  assert.equal(chooser.mode,'selectSingle','Unexpected file chooser mode');
  assert.ok(Number.isSafeInteger(chooser.backendNodeId),'No native chooser DOM node was observed');
  const bytes=readFileSync(path),transfer={label,path,sha256:sha256(bytes),bytes:bytes.length,
    chooser:copy(chooser),method:'DOM.setFileInputFiles',elapsed_ms:Date.now()-started};
  fileTransfers.push(transfer);
  const consoleStart=consoleEvents.length;
  await observe();
  transfer.dom_delivery={start_index:domInputEvents.length,name:basename(path),bytes:bytes.length};
  await cmd('DOM.setFileInputFiles',{files:[resolve(path)],backendNodeId:chooser.backendNodeId});
  transfer.acknowledged=true;
  await cmd('Page.bringToFront');
  await waitFor(label+'-staged-or-refused',s=>s.project_file.operation_serial>serial&&
    (s.project_file.staged||s.project_file.status==='refused'),90000);
  transfer.dom_delivery.end_index=domInputEvents.length;
  check(label+'-trusted-browser-file-delivery',()=>{
    transfer.dom_delivery.event=assertBrowserFileDelivery(domInputEvents,transfer.dom_delivery);
  });
  if(!accept) {
    check(label+'-refused-before-replacement',()=>{
      assert.equal(state.project_file.status,'refused');assert.equal(state.project_file.staged,false);
      assert.ok(state.project_file.error.length>0,'Refusal omitted a precise reason');
      assertRejectedImport(before,state);
    });
    transfer.refusal=state.project_file.error;
    if(expectedCRC) {
      const witness={case:'external_crc',fixture_sha256:sha256(bytes),refusal:transfer.refusal,
        old_world_preserved:true,start_index:consoleStart,end_index:consoleEvents.length};
      check('CRC-only-engine-diagnostic-is-witnessed-and-retained',()=>unexpectedConsoleErrors(consoleEvents,[witness]));
      expectedDiagnostics.push(witness);
    }
    await click('project_cancel');await waitFor(label+'-refusal-dismissed',s=>!s.menu&&s.project_modal==='');
    check(label+'-dismissal-preserves-old-world',()=>assertRejectedImport(before,state));
    return before;
  }
  check(label+'-staging-does-not-replace-session',()=>{
    assert.equal(state.project_file.staged,true);assert.equal(state.project_modal,'open');
    assertRejectedImport(before,state);
    assert.match(state.project_file.staged_digest,/^[0-9a-f]{64}$/);
  });
  const count=state.project_file.import_count;
  await click('project_confirm');
  await waitFor(label+'-installed',s=>s.project_file.import_count===count+1&&s.ready&&s.generation>before.generation&&
    s.project_modal===''&&!s.menu,120000);
  transfer.installed_generation=state.generation;transfer.logical_digest=state.project_file.imported_digest;
  return before;
}

async function textField(name,value,predicate) {
  await click(name);
  await keyEvent('keyDown','a','KeyA',65,{modifiers:2,allowGodotIME:true});
  await keyEvent('keyUp','a','KeyA',65,{modifiers:2,allowGodotIME:true});
  for(const ch of value) {
    const code=/[a-zA-Z]/.test(ch)?'Key'+ch.toUpperCase():/\d/.test(ch)?'Digit'+ch:ch===' '?'Space':ch==='-'?'Minus':ch==='.'?'Period':null;
    assert.ok(code,'The genuine input harness only types its registered ASCII text');
    const keyCode=ch===' '?32:ch==='-'?189:ch==='.'?190:ch.toUpperCase().charCodeAt(0);
    await observe();const first=domInputEvents.length;
    await input('Input.dispatchKeyEvent',{type:'keyDown',key:ch,code,windowsVirtualKeyCode:keyCode,
      nativeVirtualKeyCode:keyCode,text:ch,unmodifiedText:ch});
    await input('Input.dispatchKeyEvent',{type:'keyUp',key:ch,code,windowsVirtualKeyCode:keyCode,nativeVirtualKeyCode:keyCode});
    await observe();
    for(const type of ['keydown','keyup'])expectedDOM.push({action:name+'-text-'+ch,type,code,
      repeat:false,allow_godot_ime:true,start_index:first,end_index:domInputEvents.length});
  }
  await key('Enter','Enter',13,{allowGodotIME:true});
  await waitFor(name+'-text-committed',predicate);
}

function assertRunReceipt(receipt,observed,initialArchive) {
  const e=receipt.evidence;
  assert.equal(e.type,'sandfall-run-evidence');assert.equal(e.schema_version,1);
  assert.deepEqual(e.source,verification.project_source_identity);
  assert.equal(e.project.identity_valid,true,e.project.identity_error);
  assert.match(e.project.logical_sha256,/^[0-9a-f]{64}$/);
  assert.match(e.project.physical_sha256,/^[0-9a-f]{64}$/);
  assert.match(e.project.initial_cells_sha256,/^[0-9a-f]{64}$/);
  if(initialArchive) {
    assert.equal(e.project.initial_cells_sha256,initialArchive.inspection.world_sha256);
    assert.deepEqual(e.project.initial_objects,initialArchive.inspection.objects.objects);
    assert.equal(e.project.logical_sha256,initialArchive.record.logical_sha256);
  }
  for(const k of ['generation','tick','rapier_steps','paused','pristine','mode'])assert.equal(e.session[k],observed[k]);
  assert.ok(Math.abs(e.session.fixed_delta-1/60)<1e-15);
  assert.deepEqual(e.actor_control_trace,{mode:'absent',locomotion_commands:0,action_commands:0});
  assert.equal(e.application.actor_count,0);assert.equal(e.application.input.actor_controls,'absent');
  assert.deepEqual(e.physical.body_ids,ids(observed));
  assert.deepEqual(e.physical.body_poses,observed.native.body_states);
  assert.equal(e.physical.moves,observed.moves);assert.equal(e.physical.contacts,observed.contacts_total);
  assert.equal(e.physical.displacements,observed.displaced_total);
  assert.deepEqual(e.physical.per_object_feedback,observed.native.object_feedback);
  assert.deepEqual(e.physical.body_body_pairs,observed.native.body_body_pairs);
  assert.equal(e.physical.pending_colliders,0);assert.equal(e.physical.workers,1);
  assert.equal(e.interventions.length,observed.intervention_count);
  assert.ok(e.interventions.length<=256&&e.intervention_bytes<=32*1024*1024);
  let sequence=0;
  for(const entry of e.interventions) {
    assert.ok(Number.isSafeInteger(entry.sequence)&&entry.sequence>sequence);sequence=entry.sequence;
    assert.equal(entry.generation,observed.generation);assert.equal(entry.accepted,true);
    assert.ok(entry.tick>=0&&entry.tick<=e.session.tick);assert.deepEqual(entry.source,e.source);
  }
  let eventSequence=0;
  for(const event of e.events){assert.ok(event.sequence>eventSequence);eventSequence=event.sequence;assert.equal(typeof event.accepted,'boolean');}
  assert.deepEqual(e.qualification,{human_exhibition_accepted:false,threaded_web_qualified:false,cross_platform_bitwise_replay:false});
}

async function terminalWorld({annotation=false}={}) {
  if(state.editor.presentation_active){await group('objects');}
  else if(state.editor.tool_group!=='objects'){await group('objects');}
  await click('object_clear');await waitFor('terminal-selection-cleared',s=>!s.editor.selected_object_id&&!s.editor.object_gesture_active);
  if(state.editor.tools_visible){await click('tools');await waitFor('terminal-tools-hidden',s=>!s.editor.tools_visible);}
  await click('fit');await observe();
  const terminal=checkpoint('terminal-project-world');
  await stable('terminal-world-stays-paused',terminal,{camera:true});
  check('all-real-browser-input-has-trusted-coordinate-matched-delivery',()=>assertTrustedDelivery(domInputEvents,expectedDOM));
  check('no-unexpected-browser-console-errors',()=>assert.deepEqual(unexpectedConsoleErrors(consoleEvents,expectedDiagnostics),[]));
  let bodyContainment;
  check('every-complete-rotated-body-is-inside-the-observed-world-viewport',()=>{
    bodyContainment=assertBodiesContainedInViewport(state);
  });
  await capture('world',true);await observe();
  check('terminal-capture-cannot-advance-or-replace-world',()=>assertPausedStable(terminal,state,{camera:true}));
  check('world-and-all-physical-bodies-are-visible',()=>{
    const frame=captures.find(x=>x.name==='world');frame.body_viewport_containment=bodyContainment;
    assert.ok(frame.pixels.bright_fraction>=.008&&frame.pixels.unique_4bit_rgb>=8);
    assert.equal(frame.object_pixels.body_count,objects(state).length);
    assert.equal(frame.object_pixels.bodies.length,objects(state).length);
    if(annotation) {
      const decoded=decodeRgb(readFileSync(frame.path)),a=mapWorldCell([44,15],state.view,state.camera,metrics,layout).point;
      const b=mapWorldCell([150,36],state.view,state.camera,metrics,layout).point;
      const sx=decoded.width/metrics.viewport.width,sy=decoded.height/metrics.viewport.height;
      const region={x0:Math.ceil(a.x*sx),y0:Math.ceil(a.y*sy),x1:Math.floor(b.x*sx),y1:Math.floor(b.y*sy)};
      let mint=0;
      for(let y=region.y0;y<region.y1;y++)for(let x=region.x0;x<region.x1;x++){
        const offset=(y*decoded.width+x)*3,[r,g,b]=decoded.pixels.subarray(offset,offset+3);
        if(r>=100&&r<=175&&g>=185&&g<=245&&b>=175&&b<=240&&g-r>=35&&b-r>=25)mint++;
      }
      frame.presentation_pixels={region,mint_pixels:mint,annotation_text:'SF M4'};
      assert.ok(mint>=6,'No actual mint annotation pixels appeared at the source-mapped world label');
    }
  });
}

async function addPresentationLabel({history=false}={}) {
  if(!state.editor.tools_visible){await click('tools');await waitFor('presentation-tools-panel-open',s=>s.editor.tools_visible);}
  await click('mode_presentation');await waitFor('presentation-tools-visible',s=>s.editor.presentation_active);
  await textField('annotation_text','SF M4',s=>s.project_controls?.annotation_text);
  await click('presentation_label');await observe();
  const physical=copy(state),count=state.presentation.annotations.length,start=domInputEvents.length,p=cellPoint([45,32]);
  await input('Input.dispatchMouseEvent',{type:'mouseMoved',x:p.x,y:p.y,buttons:0});
  await input('Input.dispatchMouseEvent',{type:'mousePressed',button:'left',buttons:1,x:p.x,y:p.y,clickCount:1});
  await sleep(100);
  await input('Input.dispatchMouseEvent',{type:'mouseReleased',button:'left',buttons:0,x:p.x,y:p.y,clickCount:1});
  await waitFor('presentation-label-created',s=>s.presentation.annotations.length===count+1&&s.presentation.annotations.at(-1).text==='SF M4');
  for(const type of ['pointerdown','mousedown','pointerup','mouseup'])expectedDOM.push({action:'presentation-world-label',type,x:p.x,y:p.y,button:0,
    start_index:start,end_index:domInputEvents.length});
  check('presentation-does-not-change-physical-world-or-Modified',()=>{
    for(const key of ['tick','rapier_steps','generation','pristine','current_hash','intervention_count'])assert.deepEqual(state[key],physical[key]);
    assert.deepEqual(state.native.body_states,physical.native.body_states);assert.deepEqual(objects(state),objects(physical));
    assert.equal(state.pristine,true);assert.equal(state.presentation.annotations.at(-1).type,'label');
    if(history){assert.equal(state.document.revision,physical.document.revision+1);assert.equal(state.document.undo_depth,physical.document.undo_depth+1);}
    else assert.deepEqual(state.document,physical.document);
  });
  if(history) {
    const expected=copy(state.presentation);
    await click('undo');await waitFor('presentation-in-shared-history-undone',s=>s.presentation.annotations.length===count);
    check('presentation-Undo-preserves-material-and-object-initial-state',()=>{
      assertEdit(state);assert.deepEqual(state.presentation,physical.presentation);assert.equal(state.current_hash,physical.current_hash);
      assert.deepEqual(objects(state),objects(physical));
    });
    await click('redo');await waitFor('presentation-in-shared-history-redone',s=>s.presentation.annotations.length===count+1);
    check('presentation-Redo-is-exact',()=>assert.deepEqual(state.presentation,expected));
  }
  await group('objects');await waitFor('presentation-input-mode-retired',s=>!s.editor.presentation_active);
}

async function projectScenario() {
  await click('sandbox');await waitFor('fresh-Sandbox',s=>s.ready&&s.entry==='sandbox'&&s.mode==='edit'&&s.paused);
  check('fresh-Sandbox-project-source-and-zero-ticks',()=>{assertEdit(state);assertRegistry(state,0);assertProjectSource(state.project_file.source_identity,verification);});
  await field('brush_width','1',s=>s.editor.brush_size[0]===1&&s.editor.brush_size[1]===1);
  await material('wall',1);await tool('rectangle');
  if(!state.editor.filled){await click('filled');await waitFor('filled',s=>s.editor.filled);}
  await editStroke([20,220],[460,225],'rectangle',441*6,'project-hard-floor');
  await editStroke([20,20],[24,219],'rectangle',1000,'project-left-wall');
  await editStroke([456,20],[460,219],'rectangle',1000,'project-right-wall');
  await material('water',3);await editStroke([28,180],[452,215],'rectangle',425*36,'project-native-water');
  await group('objects');
  for(let i=0;i<bodyCount;i++) {
    await objectTool('box');
    const x=bodyCount===1?240:bodyCount===3?[100,240,380][i]:48+(i%8)*52,y=bodyCount===16&&i>=8?65:110;
    const before=await objectGesture([x-8,y-9],[x+8,y+9],{label:'authored-project-box-'+i});
    await waitFor('project-box-'+i+'-accepted',s=>s.mutation_count>before.mutation_count);
    check('project-box-'+i+'-stable-ID',()=>assertObjectEdit(before,state,i+1));
  }
  if(bodyCount>0) {
    await selectObject(ids(state)[0]);
    await inspector('motion',{vx:12,vy:-7,angular_velocity:60});
    await applyInspector(bodyCount,{label:'authored-nonzero-initial-velocities'});
    check('nonzero-initial-velocities-exist-in-logical-and-live-physics',()=>{
      assert.deepEqual(objects(state)[0].linear_velocity,[12,-7]);
      assert.ok(Math.abs(objects(state)[0].angular_velocity-Math.PI/3)<1e-6);
      samePhysicalValue(state.native.body_states[0].slice(3,6),[12,-7,Math.PI/3],
        'Authored initial linear/angular velocity in actual physics');
    });
  }
  await addPresentationLabel({history:true});
  const initial=authoredState(state),original=await download('original-'+bodyCount);
  check('ordinary-ZIP-contains-exact-initial-object-graph',()=>{
    assert.deepEqual(original.inspection.objects.objects,initial.definitions);
    assert.deepEqual(original.inspection.manifest.source,verification.project_source_identity);
    assert.equal(original.inspection.world_sha256,original.record.initial_cells_sha256);
  });
  // Change the active draft before loading: successful import must really
  // replace it, while validation/staging keeps this different draft intact.
  await group('materials');await material('wall',1);await tool('pencil');
  await editStroke([35,28],[35,28],'pencil_stroke',1,'temporary-draft-before-import');
  const beforeImport=await upload(original.path,{label:'original-'+bodyCount});
  check('all-authored-fields-reconstruct-at-zero',()=>assertProjectInstalled(beforeImport,state,initial));
  const roundtrip=await download('roundtrip-'+bodyCount);
  check('Godot-ZIP-roundtrip-has-exact-logical-file-identities',()=>assertSameLogicalProject(original.inspection,roundtrip.inspection));
  const externalPath=join(downloadDir,'external-edited-'+bodyCount+'.sandfall');
  externalFixture('mutate',original.path,{destination:externalPath,kind:'editable-folder',label:'external-edit-'+bodyCount});
  const externalInspect=externalFixture('inspect',externalPath,{label:'external-inspection-'+bodyCount});
  const beforeExternal=await upload(externalPath,{label:'ordinary-tools-edited-project'});
  check('ordinary-extracted-JSON-edit-is-observed',()=>{
    assertProjectInstalled(beforeExternal,state,{...initial,definitions:externalInspect.objects.objects});
  });
  const canonical=await download('canonical-external-'+bodyCount),baseline=authoredState(state);
  await group('objects');await click('object_clear');await waitFor('project-clear-selection',s=>!s.editor.selected_object_id);
  await runWorkload(baseline,'imported-'+bodyCount+'-body-physical-workload');
  const frozen=await download('pristine-Run-frozen-'+bodyCount);
  check('Run-save-is-the-frozen-authored-initial-scene',()=>assertFrozenSave(canonical.inspection,frozen.inspection));
  const negatives=bodyCount===16?['body17','bad-mass','duplicate-id','bad-shape','bad-material','unsupported-solver',
    'unsupported-schema','traversal','symlink','case-duplicate','wrong-digest','crc','local-name','declared-bomb']:['wrong-digest'];
  for(const kind of negatives) {
    const path=join(downloadDir,'refused-'+kind+'.sandfall');
    externalFixture('mutate',canonical.path,{destination:path,kind,label:'negative-'+kind});
    await upload(path,{accept:false,label:'hostile-'+kind,expectedCRC:kind==='crc'});
  }
  // Safe live edits become a journal, then an explicitly confirmed new draft.
  await group('objects');
  let expectedDefinitions=copy(baseline.definitions);
  if(bodyCount>0) {
    await selectObject(ids(state)[0]);
    await inspector('physics',{mass:objects(state)[0].mass+1});
    const beforeMass=checkpoint('evolved-live-physics-before-mass-only-change');
    await applyInspector(bodyCount,{run:true,label:'promotable-exact-mass-change'});
    const acceptedFrame=state.frame;
    await waitFor('mass-only-change-observed-after-fresh-idle-frames',s=>s.frame>=acceptedFrame+3&&s.paused);
    check('mass-only-change-preserves-every-live-pose-and-velocity-after-idle',()=>
      assertMassOnlyPhysicsPreserved(beforeMass,state,ids(beforeMass)[0],objects(beforeMass)[0].mass+1));
    expectedDefinitions[0].mass+=1;
  } else {
    await objectTool('box');const before=await objectGesture([220,60],[236,78],{label:'promotable-live-spawn'});
    await waitFor('promotable-spawn-accepted',s=>s.mutation_count>before.mutation_count);
    check('zero-to-one-promotable-spawn',()=>assertObjectIntervention(before,state,1));
    expectedDefinitions=copy(objects(state));
  }
  await group('materials');await material('wall',1);await tool('pencil');
  const paintBefore=await stroke([35,28],[35,28],{label:'promotable-declarative-paint'});
  await waitFor('promotable-paint-accepted',s=>s.mutation_count>paintBefore.mutation_count);
  check('Run-paint-journalled-and-Modified',()=>{assertRunIntervention(paintBefore,state,'pencil_stroke');assert.equal(state.last_edit.cells,1);});
  const modifiedSave=await download('Modified-Run-frozen-'+bodyCount);
  check('Modified-Run-save-excludes-all-interventions-and-evolution',()=>assertFrozenSave(canonical.inspection,modifiedSave.inspection));
  const evidence=await download('Modified-Run-evidence-'+bodyCount,'run_evidence');
  check('run-evidence-binds-source-initial-scene-and-real-physical-outcomes',()=>assertRunReceipt(evidence,state,canonical));
  const beforePreview=copy(state);
  await click('file_promote');await waitFor('promotion-preview-ready',s=>s.project_modal==='promotion'&&s.promotion.accepted===true);
  check('promotion-shows-a-new-candidate-without-changing-live-state',()=>{
    assertRejectedImport(beforePreview,state);assert.match(state.promotion.candidate_hash,/^[0-9a-f]{64}$/);
    assert.ok(state.promotion.eligible>=2);assert.equal(state.promotion.skipped,0);assert.deepEqual(state.promotion.conflicts,[]);
  });
  await click('promotion_cancel');await waitFor('promotion-cancelled',s=>s.project_modal===''&&!s.menu);
  check('cancelled-promotion-preserves-the-current-run',()=>assertRejectedImport(beforePreview,state));
  await click('file_promote');await waitFor('promotion-confirmable',s=>s.project_modal==='promotion'&&s.promotion.accepted===true);
  await click('promotion_confirm');await waitFor('new-promoted-Edit-draft',s=>s.generation>beforePreview.generation&&s.mode==='edit'&&s.tick===0&&s.ready&&!s.menu);
  check('explicit-confirmation-creates-a-fresh-tick-zero-draft',()=>{
    assertPromotionBoundary(beforePreview,state);assert.deepEqual(objects(state),expectedDefinitions);
    samePhysicalValue(state.native.body_states,expectedDefinitions.map(d=>[
      ...d.position,d.rotation,...d.linear_velocity,d.angular_velocity,false]),
      'Promoted initial live poses and nonzero velocities');
    for(let i=0;i<baseline.definitions.length;i++)assert.deepEqual(objects(state)[i].position,baseline.definitions[i].position,
      'Promotion copied a fallen live pose instead of the initial authored transform');
  });
  const promoted=await download('promoted-initial-'+bodyCount);
  const cellDiff=externalFixture('diff-cells',canonical.path,{destination:promoted.path,label:'promotion-cell-diff-'+bodyCount});
  check('promotion-copies-only-approved-declarative-cell-command',()=>{
    assert.equal(cellDiff.changed_cells,1);assert.deepEqual(cellDiff.indices,[28*1024+35]);
    assert.equal(cellDiff.tuples[0].after[0],1);assert.equal(cellDiff.truncated,false);
  });
  const beforeRestore=await upload(canonical.path,{label:'restore-original-capacity-for-terminal-physics'});
  check('reimport-restores-initial-live-poses-and-velocities',()=>assertProjectInstalled(beforeRestore,state,baseline));
  await group('objects');await click('object_clear');await waitFor('terminal-import-selection-clear',s=>!s.editor.selected_object_id);
  await runWorkload(baseline,'reimported-'+bodyCount+'-body-physical-workload');
  await terminalWorld({annotation:true});
}

async function galleryScenario() {
  // Each optional isolated entry gets its own browser process and terminal
  // capture. The full navigation workload remains a separate matrix case.
  // Never resume input in this process after any screenshot has begun.
  const entries=galleryEntry?galleryEntries.filter(row=>row[0]===galleryEntry):galleryEntries;
  for(const [id,title,count] of entries) {
    await click('gallery_browse');await waitFor('Gallery-browser-open',s=>s.project_modal==='gallery'&&s.menu);
    await textField('gallery_search',title,s=>s.gallery.query===title&&s.gallery.visible_ids.length===1&&s.gallery.visible_ids[0]===id);
    const generation=state.generation;
    await click('gallery_launch_'+id);
    await waitFor(id+'-autoplay-after-readiness',s=>s.ready&&s.scene_id===id&&s.mode==='run'&&!s.paused&&s.generation>generation&&s.tick>0,120000);
    const startedScene=copy(state);
    check(id+'-has-no-actor-or-motor-and-fixed-interest',()=>{
      assertRegistry(state,count);assert.equal(state.actor_count,0);assert.equal(state.pristine,true);
      assert.equal(state.pending_colliders,0);assert.equal(state.intervention_count,0);
    });
    await waitFor(id+'-actual-six-hundred-ticks',s=>s.tick>=600,300000);
    await click('pause');await waitFor(id+'-paused',s=>s.paused);
    check(id+'-physical-outcome',()=>{
      assertRegistry(state,count);assert.equal(state.rapier_steps,state.tick);assert.equal(state.actor_count,0);
      assert.equal(state.pristine,true);assert.equal(state.intervention_count,0);
      assert.deepEqual(state.native.simulation_interest,startedScene.native.simulation_interest);
      assert.deepEqual(Object.keys(state.native.object_feedback).sort(),ids(state).toSorted(),
        'Gallery feedback omitted or misattributed a stable project ID');
      if(id==='endless_kinetic_loop') {
        for(let i=0;i<count;i++) {
          assert.ok(Math.abs(state.native.body_states[i][5])>0.1,'Inertial loop lost its actual angular velocity');
          assert.ok(Math.abs(state.native.body_states[i][2]-startedScene.native.body_states[i][2])>0.1,'Inertial loop did not visibly rotate');
          assert.ok(Math.hypot(state.native.body_states[i][0]-startedScene.native.body_states[i][0],state.native.body_states[i][1]-startedScene.native.body_states[i][1])<1,
            'Idealized bounded loop drifted outside its declared fixed positions');
        }
      } else {
        assert.ok(state.moves>0,'Gallery scene has no native physical movement');
        assert.ok(state.contacts_total>0,'Gallery scene has no real material/body contacts');
        const feedback=state.native.object_feedback;
        assert.ok(Object.values(feedback).some(v=>v.applications>0&&(Math.abs(v.accepted_impulse_x)+Math.abs(v.accepted_impulse_y)>0)),
          'Gallery scene has no applied native-material feedback');
        if(['fluid_messenger','passive_subject_ride'].includes(id)) {
          const passive=objects(state).filter(d=>d.passive_subject);
          assert.equal(passive.length,1);const index=ids(state).indexOf(passive[0].id),f=feedback[passive[0].id];
          assert.equal(passive[0].gravity_scale,0);assert.deepEqual(passive[0].linear_velocity,[0,0]);
          assert.ok(f.applications>0&&Math.abs(f.accepted_impulse_x)+Math.abs(f.accepted_impulse_y)>0,'Passive subject received no native feedback');
          assert.ok(Math.hypot(state.native.body_states[index][0]-passive[0].position[0],state.native.body_states[index][1]-passive[0].position[1])>2,
            'Passive subject never physically moved');
        }
        if(id==='sixteen_body') {
          assert.ok(state.native.body_body_pairs.length>0,'Sixteen-body Gallery has no real body/body contact');
          for(const value of Object.values(feedback)){assert.equal(value.samples,state.tick);assert.ok(value.contacts>0&&value.applications>0);}
        }
      }
    });
    if(id==='time_controls') {
      await stable('Gallery-pause-zero-steps',checkpoint('gallery-time-paused'));
      await pausedStep(true);
      for(const speed of ['0.25','0.5','1','2','4']){
        const before=checkpoint('gallery-speed-'+speed);await click('speed_'+speed);await waitFor('gallery-speed-selected',s=>s.speed===Number(speed));
        check('Gallery-speed-'+speed+'-keeps-paused-fixed-step',()=>assertPausedStable(before,state));
      }
    }
    const record=await download('gallery-'+id,'run_evidence');
    check(id+'-source-bound-Golden-Run-receipt',()=>assertRunReceipt(record,state));
    galleryRuns.push({id,initial:startedScene,final:copy(state),evidence:record.path});
  }
  // Add a real, authored presentation mark in Run. Its pixels are inspected
  // inside the world viewport; it must not enter the physical intervention log.
  await addPresentationLabel();
  await terminalWorld({annotation:true});
}

async function executeScenario() {
  if(scenario==='projects')await projectScenario();else await galleryScenario();
}


try {
  // Bind HTTP bytes to the independent artifact verifier before running them.
  for (const artifact of [...verification.artifacts,{path:"SHA256SUMS",sha256:verification.manifest_sha256}]) {
    const address = new URL(artifact.path,url).href;
    const response = await fetch(address,{signal:AbortSignal.timeout(30000)});
    if (!response.ok) throw Error("Cannot verify served artifact: " + address + " HTTP " + response.status);
    const bytes = Buffer.from(await response.arrayBuffer());
    const actual = sha256(bytes);
    servedIdentity.push({url:address,sha256:actual,expected_sha256:artifact.sha256,size:bytes.length});
    if (actual !== artifact.sha256 || (artifact.size !== undefined && bytes.length !== artifact.size))
      throw Error("Served export differs from verified artifact: " + artifact.path);
  }
  let tab;
  const discoveryDeadline = Date.now()+30000;
  while (Date.now() < discoveryDeadline) {
    try { tab = (await fetch("http://127.0.0.1:"+port+"/json/list",
      {signal:AbortSignal.timeout(2000)}).then(response=>response.json())).find(value=>value.type === "page"); }
    catch { /* Bounded Chrome startup discovery. */ }
    if (tab) break;
    await sleep(250);
  }
  if (!tab) throw Error("Chromium CDP page never appeared");
  originalTarget = tab.id;
  ws = new WebSocket(tab.webSocketDebuggerUrl);
  await new Promise((resolve,reject)=>{
    const timer=setTimeout(()=>reject(Error("CDP WebSocket connection deadline expired")),10000);
    ws.addEventListener("open",()=>{clearTimeout(timer);resolve();},{once:true});
    ws.addEventListener("error",error=>{clearTimeout(timer);reject(error);},{once:true});
  });
  ws.addEventListener("message",event=>{
    const message = JSON.parse(event.data);
    if (message.method === "Runtime.consoleAPICalled") {
      consoleEvents.push({type:message.params.type,
        text:(message.params.args??[]).map(value=>value.value??value.description??"").join(" ").slice(0,2400)});
    } else if(message.method === "Browser.downloadWillBegin") {
      downloads.push({...message.params,started_elapsed_ms:Date.now()-started,status:"in-progress"});
    } else if(message.method === "Browser.downloadProgress") {
      const download=downloads.find(x=>x.guid===message.params.guid);
      if(download)Object.assign(download,message.params,{status:message.params.state});
    } else if(message.method === "Page.fileChooserOpened") {
      fileChoosers.push({...message.params,elapsed_ms:Date.now()-started});
    } else if (message.method === "Runtime.exceptionThrown") {
      consoleEvents.push({type:"exception",text:JSON.stringify(message.params.exceptionDetails)});
    } else {
      const callback = pending.get(message.id);
      if (callback) { pending.delete(message.id); message.error ? callback.reject(Error(JSON.stringify(message.error))) : callback.resolve(message.result); }
    }
  });
  browserVersion = await cmd("Browser.getVersion");
  await cmd("Page.enable");
  await cmd("Runtime.enable");
  await cmd("Browser.setDownloadBehavior",{behavior:"allowAndName",downloadPath:downloadDir,eventsEnabled:true});
  await cmd("Page.setInterceptFileChooserDialog",{enabled:true});
  await cmd("Page.bringToFront");
  await cmd("Emulation.setDeviceMetricsOverride",{width,height,deviceScaleFactor:dpr,mobile:false});
  await cmd("Page.addScriptToEvaluateOnNewDocument",{source:`
    window.__sandfallObservedInput=[];
    for (const type of ['pointerdown','pointermove','pointerup','pointercancel','mousedown','mousemove','mouseup','keydown','keyup','wheel','change','input']) {
      addEventListener(type,event=>{
        window.__sandfallObservedInput.push({type,isTrusted:event.isTrusted,
          key:event.key??null,code:event.code??null,repeat:event.repeat??false,files:event.target?.files?[...event.target.files].map(f=>({name:f.name,size:f.size})):null,
          button:event.button??null,buttons:event.buttons??null,x:event.clientX??null,y:event.clientY??null,
          target:event.target?.tagName,targetId:event.target?.id,
          targetClass:event.target?.className,targetContentEditable:event.target?.isContentEditable===true,
          targetIsActive:event.target===document.activeElement,
          targetSharesCanvasParent:event.target?.parentElement===document.querySelector("canvas")?.parentElement,
          focused:document.hasFocus(),time_ms:performance.now()});
      },{capture:true,passive:true});
    }
    for (const type of ['blur','focus','visibilitychange']) {
      addEventListener(type,event=>window.__sandfallObservedInput.push({type,isTrusted:event.isTrusted,
        focused:document.hasFocus(),visibility:document.visibilityState,time_ms:performance.now()}),
        {capture:true,passive:true});
    }`});
  await cmd("Page.navigate",{url});
  await waitFor("dedicated-home-ready",s=>s.app_ready && s.entry === "home",150000);
  check("dedicated-home-has-no-session-or-actor",()=>{
    assertOrdinaryState(state,{requireReady:false});
    assert.equal(state.ready,false);
    assert.equal(state.tick,0);
    assert.equal(state.rapier_steps,0);
    assert.equal(state.source_commit,verification.build_source_commit,
      "Runtime source identity differs from the verified application export");
    const native = verification.artifacts.find(value=>value.path === "libcybersand_native.web.nothreads.wasm");
    assert.ok(native,"Verified native compatibility WASM receipt is absent");
    assert.equal(state.native_sha256,native.sha256,"Observed native digest differs from verified/served WASM");
  });
  await executeScenario();

} catch (error) {
  failures.push(String(error));
  console.error("SF_M4_BROWSER_FAILURE",String(error));
  if (ws?.readyState === WebSocket.OPEN && !captureStarted) await capture("failure");
} finally {
  const evidence = {schema:"sandfall-sf-m4-browser-v1",url,observed_at:new Date().toISOString(),
    duration_ms:Date.now()-started,status:failures.length ? "failed" : "passed",failures,
    deadlines_ms:{phase_wait_total:timeoutMs,capture:150000,post_capture_observation:30000,cleanup:5000},
    requested_viewport:{width,height,dpr},browser_version:browserVersion,logical_viewport:layout,
    served_identity:servedIdentity,harness_inputs:harnessInputs,harness_checkout:harnessCheckout,
    verification:{path:verificationPath,sha256:sha256(verificationBytes),
      build_source_commit:verification.build_source_commit,harness_source_commit:verification.harness_source_commit,
      source_equivalence:verification.source_equivalence},
    acceptance_mode:"ordinary dedicated Sandfall application; read-only test=1; genuine CDP input only",
    scope:{compatibility_web:true,threaded_web:false,human_visual_acceptance:false,scenario,gallery_entry:galleryEntry,
      coupled_body_count:scenario==='projects'?bodyCount:null,capacity_refusal:scenario==='projects'&&bodyCount===16,
      archive_delivery:"real browser chooser/upload and observed Blob download bytes",
      physical_save_restore_and_partial_fault:"Separate Godot backend/session gates; not claimed by this browser receipt"},
    downloads,file_choosers:fileChoosers,file_transfers:fileTransfers,archive_receipts:archiveReceipts,run_receipts:runReceipts,gallery_runs:galleryRuns,
    expected_engine_diagnostics:expectedDiagnostics,
    final_state:state,final_metrics:metrics,checks,checkpoints,transitions,control_layouts:controlLayouts,input_events:inputEvents,
    expected_dom_delivery:expectedDOM,dom_input_events:domInputEvents,cdp_poll_errors:pollErrors,
    captures,observations,console_events:consoleEvents};
  mkdirSync(dirname(output),{recursive:true});
  writeFileSync(output,JSON.stringify(evidence,null,2)+"\n");
  console.log("SF_M4_BROWSER_RESULT",JSON.stringify({status:evidence.status,failures,
    build_source:verification.build_source_commit,final_tick:state?.tick,rapier_steps:state?.rapier_steps,
    checks:checks.length,pixels:captures.find(value=>value.name === "world")?.pixels}));
  process.exitCode = failures.length ? 1 : 0;
  const cleanupDeadline = setTimeout(()=>{
    failures.push("CDP transport cleanup exceeded five seconds");
    evidence.status = "failed"; evidence.cleanup_timeout = true;
    writeFileSync(output,JSON.stringify(evidence,null,2)+"\n");
    console.error("SF_M4_BROWSER_CLEANUP_FAILURE",failures.at(-1));
    process.exit(1);
  },5000);
  cleanupDeadline.unref();
  if (ws?.readyState === WebSocket.OPEN) {
    try { await cmd("Browser.close",{},3000); } catch { /* Transport closes below. */ }
  }
  if (ws && ws.readyState !== WebSocket.CLOSED) {
    ws.addEventListener("close",()=>clearTimeout(cleanupDeadline),{once:true});
    try { ws.close(); } catch { /* The deadline records unresolved transport. */ }
  } else clearTimeout(cleanupDeadline);
}
