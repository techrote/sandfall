#!/usr/bin/env node
// Source-matched SF-M3 ordinary application acceptance. All application data is
// read-only. Every state transition below uses genuine CDP browser input; this
// harness cannot call a Godot command, edit a tick, or set acceptance success.
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { analyzePng, pngDimensions } from "./sf_m0_png_stats.mjs";
import { mapGodotRect, cssRectToScreenshotROI } from "./sf_m0_geometry.mjs";
import {analyzeBodies} from "./sf_m3_pixels.mjs";
import {assertRegistry,assertObjectEdit,assertObjectRefusal,authoredState,assertAuthoredState,
  assertObjectIntervention,assertObjectReset,assertPhysicalWorkload,objects,ids,
  sampleControlLayout,sameControlLayout,controlLayoutSettled} from "./sf_m3_browser_assertions.mjs";
import {mapWorldCell} from "./sf_m2_geometry.mjs";
import {
  assertOrdinaryState, assertEdit, assertInputClear, physicalCheckpoint,
  assertPausedStable, assertStep, assertReset, assertGallery600, assertTrustedDelivery,
  assertEditMutation, assertHistoryLocked, assertRunIntervention, gestureAcknowledged,
} from "./sf_m2_browser_assertions.mjs";

const argv = new Map();
for (let i = 2; i < process.argv.length; i += 2) argv.set(process.argv[i], process.argv[i + 1]);
const port = Number(argv.get("--port") || "9231");
const url = argv.get("--url") || "http://127.0.0.1:8040/?test=1";
const output = resolve(argv.get("--output") || "sf-m3-browser/browser.json");
const screenshotPath = resolve(argv.get("--screenshot") || "sf-m3-browser/browser.png");
const timeoutMs = Number(argv.get("--timeout-ms") || "1200000");
const width = Number(argv.get("--width") || "800");
const height = Number(argv.get("--height") || "450");
const dpr = Number(argv.get("--dpr") || "1");
const bodyCount = Number(argv.get("--bodies") ?? process.env.SF_M3_BODY_COUNT ?? "16");
if (![0,1,3,8,16].includes(bodyCount)) throw Error("SF-M3 workload must be one of 0,1,3,8,16");
const verificationPath = argv.get("--verification");
if (!verificationPath) throw Error("A SHA-verified SF-M3 export receipt is required (--verification)");
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
const harnessInputs = ["sf_m3_browser.mjs", "sf_m3_browser_assertions.mjs", "sf_m3_pixels.mjs", "sf_m2_browser_assertions.mjs", "sf_m2_geometry.mjs", "sf_m0_geometry.mjs", "sf_m0_png_stats.mjs"]
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
    object_definitions:objects(state),body_ids:state.native?.body_ids,body_states:state.native?.body_states,
    body_sizes:state.native?.body_sizes,slot_mapping:state.native?.slot_mapping,
    object_feedback:state.native?.object_feedback,body_body_pairs:state.native?.body_body_pairs,
    pristine:state.pristine,intervention_count:state.intervention_count,last_edit:state.last_edit,
    last_refusal:state.last_refusal,render_rejections:state.render_rejections,document_focused:metrics.documentFocused,
    visibility:metrics.visibility};
  observations.push(sample);
  const logKey = JSON.stringify([phase,state.generation,state.mode,state.menu,state.paused]);
  if (logKey !== lastLog || Date.now()-lastLogAt > 10000) {
    console.log("SF_M3_BROWSER_OBSERVATION", JSON.stringify(sample));
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
      console.warn("SF_M3_BROWSER_POLL", String(error));
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
    console.log("SF_M3_BROWSER_CHECK", name);
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
    console.warn("SF_M3_BROWSER_CAPTURE", String(error));
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
  await cmd("Page.bringToFront");
  await cmd("Emulation.setDeviceMetricsOverride",{width,height,deviceScaleFactor:dpr,mobile:false});
  await cmd("Page.addScriptToEvaluateOnNewDocument",{source:`
    window.__sandfallObservedInput=[];
    for (const type of ['pointerdown','pointermove','pointerup','pointercancel','mousedown','mousemove','mouseup','keydown','keyup','wheel']) {
      addEventListener(type,event=>{
        window.__sandfallObservedInput.push({type,isTrusted:event.isTrusted,
          key:event.key??null,code:event.code??null,repeat:event.repeat??false,
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


  await click('sandbox');
  await waitFor('Sandbox-workshop-visible',s=>s.ready&&s.entry==='sandbox'&&s.scene_id==='blank'&&s.buttons?.mode_objects);
  check('Sandbox-discovers-editing-and-zero-object-ownership',()=>{
    assertEdit(state);assertRegistry(state,0);assert.equal(state.document.undo_depth,0);
    assert.equal(state.editor.tools_visible,true,'Sandbox did not visibly expose authoring tools');
    assert.equal(state.native.rapier_probe_deferred,true,'Fresh zero-body Sandbox executed a Rapier capability probe');
  });
  await field('brush_width','1',s=>s.editor.brush_size[0]===1&&s.editor.brush_size[1]===1);
  await material('wall',1);await tool('rectangle');
  if(!state.editor.filled){await click('filled');await waitFor('filled-workshop-wall',s=>s.editor.filled);}
  await editStroke([20,220],[460,225],'rectangle',441*6,'authored-hard-floor');
  await editStroke([20,20],[24,219],'rectangle',5*200,'authored-left-wall');
  await editStroke([456,20],[460,219],'rectangle',5*200,'authored-right-wall');
  await material('water',3);await editStroke([28,180],[452,215],'rectangle',425*36,'native-material-feedback-pool');
  const materialBaseline=authoredState(state);
  await group('objects');
  check('objects-are-distinct-from-material-tools',()=>{
    assert.equal(state.editor.tool_group,'objects');assert.ok(state.buttons.object_box&&state.buttons.object_select);
    assert.equal(state.editor.object_inspector.visible,true);
  });
  const created=[];
  for(let i=0;i<bodyCount;i++) {
    await objectTool('box');
    const x=bodyCount===1?240:bodyCount===3?[100,240,380][i]:48+(i%8)*52;
    const y=bodyCount===16&&i>=8?65:110;
    const before=await objectGesture([x-8,y-9],[x+8,y+9],{label:'create-box-'+(i+1)});
    await waitFor('box-'+(i+1)+'-accepted',s=>s.mutation_count>before.mutation_count);
    check('box-'+(i+1)+'-stable-one-transaction',()=>assertObjectEdit(before,state,i+1));
    const id=ids(state).at(-1);created.push(id);
    assert.equal(state.editor.selected_object_id,id,'Spawn did not identify the created stable ID');
  }
  if(bodyCount>0) {
    const selected=created[0];await selectObject(selected);
    // Mixed material/object history is exercised against copied exact values,
    // including a multi-page inspector operation that is one transaction.
    if(bodyCount===1) {
      const baseline=authoredState(state),position=objects(state)[0].position;
      await objectTool('move');
      const before=await objectGesture(position,[position[0]+12,position[1]-8],{label:'one-completed-object-move'});
      await waitFor('move-accepted',s=>s.mutation_count>before.mutation_count);
      check('move-is-one-history-entry',()=>assertObjectEdit(before,state,1));
      const moved=authoredState(state);
      await inspector('shape',{x:242,y:100,width:20,height:22,rotation:15});
      await inspector('physics',{mass:2.5,friction:.65,restitution:.25,linear_damping:.2,angular_damping:.4});
      await inspector('motion',{vx:3,vy:0,angular_velocity:20});
      const configured=await applyInspector(1,{label:'precise-size-transform-mass-material-damping-velocities'});
      check('precise-inspector-properties-and-units',()=>{
        const d=objects(state)[0];assert.deepEqual(d.position,[242,100]);assert.deepEqual(d.size,[20,22]);
        assert.ok(Math.abs(d.rotation-Math.PI/12)<1e-6);assert.equal(d.mass,2.5);assert.equal(d.friction,.65);
        assert.equal(d.restitution,.25);assert.equal(d.linear_damp,.2);assert.equal(d.angular_damp,.4);
        assert.deepEqual(d.linear_velocity,[3,0]);assert.ok(Math.abs(d.angular_velocity-Math.PI/9)<1e-6);
      });
      await group('materials');await tool('erase');
      await editStroke([30,220],[30,220],'erase_stroke',1,'mixed-history-material-erase');
      const erased=authoredState(state);
      await exactHistory('undo',configured);await exactHistory('undo',moved);await exactHistory('undo',baseline);
      await exactHistory('undo',materialBaseline);
      await exactHistory('redo',baseline);await exactHistory('redo',moved);await exactHistory('redo',configured);await exactHistory('redo',erased);
      await group('objects');await selectObject(selected);
    }
    // Duplicate/delete exercise real body lifetimes and stable ID replacement.
    if(bodyCount<16) {
      const original=authoredState(state);
      await objectCommand('duplicate',bodyCount+1,{label:'duplicate-with-new-stable-id'});
      const duplicate=ids(state).at(-1);assert.ok(!original.ids.includes(duplicate));
      await selectObject(duplicate);await objectCommand('delete',bodyCount,{label:'delete-duplicate-and-retire-ownership'});
      check('duplicate-lifetime-leaves-original-graph-exact',()=>{
        assert.deepEqual(objects(state),original.definitions);assert.deepEqual(ids(state),original.ids);
      });
    } else {
      const original=authoredState(state),retired=ids(state)[7];
      await selectObject(retired);await objectCommand('delete',15,{label:'delete-middle-sampling-slot'});
      const fifteen=authoredState(state);
      await selectObject(ids(state)[2]);await objectCommand('duplicate',16,{label:'replacement-appends-new-stable-id'});
      const replacement=ids(state).at(-1);assert.ok(!original.ids.includes(replacement));
      assert.ok(!ids(state).includes(retired));
      await exactHistory('undo',fifteen);await exactHistory('undo',original);
      await objectTool('box');
      const before=await objectGesture([426,35],[442,53],{label:'seventeenth-body-atomic-refusal'});
      await waitFor('body-17-capacity-refused',s=>String(s.last_refusal).includes('capacity'));
      check('body-17-preserves-existing-16-world-and-definition',()=>{assertObjectRefusal(before,state);assertRegistry(state,16);});
    }
  }
  if(bodyCount===1||bodyCount===16)await cancelledObjectGesture();
  await click('object_clear');await waitFor('clear-object-selection',s=>!s.editor.selected_object_id&&!s.editor.object_gesture_active);
  const initial=authoredState(state);
  await runWorkload(initial,'first-'+bodyCount+'-body-workload');
  await pausedStep(bodyCount>0);
  if(bodyCount>0) {
    await selectObject(ids(state)[0]);
    const originalMass=objects(state)[0].mass;
    await inspector('physics',{mass:originalMass+1});
    await applyInspector(bodyCount,{run:true,label:'paused-Run-mass-intervention'});
    const modified=checkpoint('after-physical-Modified');
    await click('object_apply');
    await stable('unchanged-inspector-does-not-add-intervention',modified);
    check('no-op-inspector-preserves-sticky-Modified',()=>{assertObjectRefusal(modified,state);assert.equal(state.pristine,false);});
    await objectCommand('delete',bodyCount-1,{run:true,label:'live-delete-retires-RID-slot-and-feedback'});
    await objectTool('box');
    const before=await objectGesture([220,35],[236,53],{label:'live-spawn-new-stable-identity'});
    await waitFor('live-spawn-accepted',s=>s.mutation_count>before.mutation_count);
    check('live-spawn-is-journalled-and-independent',()=>{
      assertObjectIntervention(before,state,bodyCount);assert.ok(!initial.ids.includes(ids(state).at(-1)));
    });
    if(bodyCount===16) {
      const before=await objectGesture([426,35],[442,53],{label:'Run-body-17-refusal'});
      await waitFor('Run-capacity-refusal-reported',s=>String(s.last_refusal).includes('capacity'));
      check('Run-body-17-refusal-keeps-Modified-and-journal',()=>assertObjectRefusal(before,state));
    }
  } else {
    await objectTool('box');
    const before=await objectGesture([220,35],[236,53],{label:'zero-to-one-live-activation'});
    await waitFor('zero-to-one-accepted',s=>s.mutation_count>before.mutation_count);
    check('zero-to-one-live-activation-journalled',()=>assertObjectIntervention(before,state,1));
    await pausedStep(true);
    await selectObject(ids(state)[0]);await objectCommand('delete',0,{run:true,label:'one-to-zero-live-deactivation'});
    await pausedStep(false);
    check('zero-body-after-deletion-has-no-ghosts',()=>assertRegistry(state,0));
  }
  await resetObjects(initial,false);
  await resetObjects(initial,true);
  const fresh=checkpoint('fresh-editable-baseline');
  await click('undo');await stable('Reset-and-Edit-cannot-resurrect-object-history',fresh);
  check('reconstruction-retains-exact-logical-objects',()=>assertAuthoredState(state,initial));
  await click('object_clear');await waitFor('terminal-no-object-gizmo',s=>!s.editor.selected_object_id&&!s.editor.object_gesture_active);
  // Re-run after reconstruction. This capture scores real settled physics,
  // separately from exact initial-state reconstruction checked above.
  await runWorkload(initial,'reconstructed-'+bodyCount+'-body-workload');
  await click('object_clear');await waitFor('physical-capture-gizmos-clear',s=>!s.editor.selected_object_id&&!s.editor.object_gesture_active);
  await click('tools');await waitFor('terminal-tools-hidden',s=>!s.editor.object_inspector.visible);
  await click('fit');await observe();
  const terminalPause=checkpoint('terminal-'+bodyCount+'-body-physical-world');
  await stable('terminal-physical-world-paused',terminalPause,{camera:true});
  check('all-ordinary-object-input-has-trusted-coordinate-matched-delivery',()=>assertTrustedDelivery(domInputEvents,expectedDOM));
  check('no-ordinary-object-application-console-errors',()=>assert.deepEqual(consoleEvents.filter(e=>['error','exception'].includes(e.type)),[]));
  await capture('world',true);await observe();
  check('physical-state-paused-through-terminal-capture',()=>assertPausedStable(terminalPause,state,{camera:true}));
  check('world-and-every-body-have-independent-visible-pixels',()=>{
    const frame=captures.find(x=>x.name==='world');assert.ok(frame.pixels.bright_fraction>=.008&&frame.pixels.unique_4bit_rgb>=8);
    assert.equal(frame.object_pixels.body_count,bodyCount);assert.equal(frame.object_pixels.bodies.length,bodyCount);
  });
} catch (error) {
  failures.push(String(error));
  console.error("SF_M3_BROWSER_FAILURE",String(error));
  if (ws?.readyState === WebSocket.OPEN && !captureStarted) await capture("failure");
} finally {
  const evidence = {schema:"sandfall-sf-m3-browser-v1",url,observed_at:new Date().toISOString(),
    duration_ms:Date.now()-started,status:failures.length ? "failed" : "passed",failures,
    deadlines_ms:{phase_wait_total:timeoutMs,capture:150000,post_capture_observation:30000,cleanup:5000},
    requested_viewport:{width,height,dpr},browser_version:browserVersion,logical_viewport:layout,
    served_identity:servedIdentity,harness_inputs:harnessInputs,harness_checkout:harnessCheckout,
    verification:{path:verificationPath,sha256:sha256(verificationBytes),
      build_source_commit:verification.build_source_commit,harness_source_commit:verification.harness_source_commit,
      source_equivalence:verification.source_equivalence},
    acceptance_mode:"ordinary dedicated Sandfall application; read-only test=1; genuine CDP input only",
    scope:{compatibility_web:true,threaded_web:false,human_visual_acceptance:false,
      coupled_body_count:bodyCount,capacity_refusal:bodyCount===16,ordinary_coupled_minimum_ticks:bodyCount?600:60,
      physical_save_restore_and_partial_fault:"Separate Godot backend/session gates; not claimed by this browser receipt"},
    final_state:state,final_metrics:metrics,checks,checkpoints,transitions,control_layouts:controlLayouts,input_events:inputEvents,
    expected_dom_delivery:expectedDOM,dom_input_events:domInputEvents,cdp_poll_errors:pollErrors,
    captures,observations,console_events:consoleEvents};
  mkdirSync(dirname(output),{recursive:true});
  writeFileSync(output,JSON.stringify(evidence,null,2)+"\n");
  console.log("SF_M3_BROWSER_RESULT",JSON.stringify({status:evidence.status,failures,
    build_source:verification.build_source_commit,final_tick:state?.tick,rapier_steps:state?.rapier_steps,
    checks:checks.length,pixels:captures.find(value=>value.name === "world")?.pixels}));
  process.exitCode = failures.length ? 1 : 0;
  const cleanupDeadline = setTimeout(()=>{
    failures.push("CDP transport cleanup exceeded five seconds");
    evidence.status = "failed"; evidence.cleanup_timeout = true;
    writeFileSync(output,JSON.stringify(evidence,null,2)+"\n");
    console.error("SF_M3_BROWSER_CLEANUP_FAILURE",failures.at(-1));
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
