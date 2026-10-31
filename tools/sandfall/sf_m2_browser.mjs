#!/usr/bin/env node
// Source-matched SF-M2 ordinary application acceptance. All application data is
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
const output = resolve(argv.get("--output") || "sf-m2-browser/browser.json");
const screenshotPath = resolve(argv.get("--screenshot") || "sf-m2-browser/browser.png");
const timeoutMs = Number(argv.get("--timeout-ms") || "1200000");
const width = Number(argv.get("--width") || "800");
const height = Number(argv.get("--height") || "450");
const dpr = Number(argv.get("--dpr") || "1");
const verificationPath = argv.get("--verification");
if (!verificationPath) throw Error("A SHA-verified SF-M2 export receipt is required (--verification)");
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
const harnessInputs = ["sf_m2_browser.mjs", "sf_m2_browser_assertions.mjs", "sf_m2_geometry.mjs", "sf_m0_geometry.mjs", "sf_m0_png_stats.mjs"]
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
    pristine:state.pristine,intervention_count:state.intervention_count,last_edit:state.last_edit,
    last_refusal:state.last_refusal,render_rejections:state.render_rejections,document_focused:metrics.documentFocused,
    visibility:metrics.visibility};
  observations.push(sample);
  const logKey = JSON.stringify([phase,state.generation,state.mode,state.menu,state.paused]);
  if (logKey !== lastLog || Date.now()-lastLogAt > 10000) {
    console.log("SF_M2_BROWSER_OBSERVATION", JSON.stringify(sample));
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
      console.warn("SF_M2_BROWSER_POLL", String(error));
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
    console.log("SF_M2_BROWSER_CHECK", name);
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
  await observe();
  const rect = state.buttons?.[name] ?? state.editor_controls?.[name];
  if (!rect) throw Error("No observed Control rectangle for " + name);
  const mapped = mapGodotRect(rect,metrics,layout);
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
        pixels:analyzePng(bytes,roi)});
    }
    return snap;
  } catch (error) {
    snap.error = String(error);
    if (scoreWorld) throw error;
    console.warn("SF_M2_BROWSER_CAPTURE", String(error));
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
    const code = ch === "-" ? "Minus" : "Digit"+ch;
    const keyCode = ch === "-" ? 189 : ch.charCodeAt(0);
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
    for (const type of ['pointerdown','pointerup','pointercancel','mousedown','mouseup','keydown','keyup','wheel']) {
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

  await click("sandbox");
  await waitFor("Sandbox-blank-Edit-ready",s=>s.ready && s.entry==="sandbox" && s.scene_id==="blank");
  check("Sandbox-is-zero-tick-empty-history",()=>{
    assertEdit(state); assert.equal(state.document.undo_depth,0); assert.equal(state.document.redo_depth,0);
  });
  const blank=checkpoint("blank-Edit");
  await stable("Edit-does-not-run-either-solver",blank);
  await field("brush_width","1",s=>s.editor.brush_size[0]===1 && s.editor.brush_size[1]===1);
  await material("sand",2); await tool("pencil");
  const firstStroke=await editStroke([10,10],[20,10],"pencil_stroke",11,"interpolated-pencil");
  await history("undo",blank.current_hash);
  await history("redo",firstStroke.current_hash);
  await pick([15,10],{id:2,state_a:0,state_b:0,temperature:200});
  await tool("erase");
  await editStroke([15,10],[15,10],"erase_stroke",1,"explicit-erasure");
  await history("undo",firstStroke.current_hash);

  await material("wall",1);
  await field("temperature","777",s=>s.editor.primary.temperature===777);
  await tool("rectangle");
  await click("filled"); await waitFor("outline-selected",s=>s.editor.filled===false);
  const wall=await editStroke([100,40],[120,60],"rectangle",80,"outlined-thermal-wall");
  await pick([100,40],{id:1,state_a:0,state_b:0,temperature:777});
  await tool("line");
  await editStroke([80,80],[100,80],"line",21,"exact-thermal-line");
  await tool("rectangle"); await click("filled");
  await waitFor("filled-rectangle-selected",s=>s.editor.filled===true);
  await editStroke([50,40],[52,42],"rectangle",9,"filled-thermal-rectangle");
  await material("water",3); await tool("fill");
  await editStroke([110,50],[110,50],"flood_fill",361,"bounded-category-fill");
  await pick([110,50],{id:3,state_a:255,state_b:0,temperature:200});

  await tool("select");
  let before=await stroke([105,45],[108,48],{label:"rectangular-selection"});
  await waitFor("selection-installed",s=>JSON.stringify(s.editor.selection)==="[105,45,4,4]");
  check("selection-is-presentation-only",()=>assertPausedStable(before,state));
  await click("copy"); await waitFor("exact-clipboard-captured",s=>JSON.stringify(s.editor.clipboard_size)==="[4,4]");
  const beforePaste=checkpoint("before-paste");
  await tool("paste");
  const pasted=await editStroke([150,45],[150,45],"selection_paste",16,"exact-tuple-paste");
  await tool("move");
  const moved=await editStroke([151,46],[153,46],"selection_move",16,"overlap-safe-selection-move");
  await history("undo",pasted.current_hash);
  await history("redo",moved.current_hash);
  before=checkpoint("before-cut");
  await click("cut");
  await waitFor("cut-committed",s=>s.document.revision>before.document.revision);
  check("cut-one-full-tuple-transaction",()=>assertEditMutation(before,state,"cut",16));
  const cut=checkpoint("after-cut");
  await history("undo",moved.current_hash);
  await history("redo",cut.current_hash);
  await history("undo",moved.current_hash);
  before=checkpoint("before-delete");
  await click("delete");
  await waitFor("delete-committed",s=>s.document.revision>before.document.revision);
  check("delete-one-transaction",()=>assertEditMutation(before,state,"delete",16));
  await history("undo",moved.current_hash);
  // An undone history item must survive a no-op brush; redo is not discarded.
  await material("wall",1); await tool("pencil");
  await field("temperature","777",s=>s.editor.primary.temperature===777);
  before=checkpoint("before-no-effect");
  await stroke([100,40],[100,40],{label:"no-effect-wall"});
  await waitFor("no-effect-refused",s=>s.last_refusal==="no_effect");
  check("no-effect-preserves-document-and-redo",()=>assertPausedStable(before,state));

  await material("sand",2); await tool("fill");
  before=checkpoint("before-cancel-fill");
  await stroke([400,200],[400,200],{label:"large-cancellable-fill"});
  await waitFor("large-fill-incremental",s=>s.editor.fill_active && s.tool_busy);
  check("fill-preview-does-not-touch-native",()=>assertPausedStable(before,state));
  await click("cancel_tool");
  await waitFor("fill-cancelled",s=>!s.editor.fill_active && !s.tool_busy);
  await stable("cancelled-fill-is-no-op",before);

  // A real tab transition retires a held stroke. No JS focus/state setter.
  await tool("pencil");
  before=checkpoint("before-held-stroke-blur");
  let point=cellPoint([240,50]);
  await input("Input.dispatchMouseEvent",{type:"mouseMoved",...point,buttons:0});
  const heldStart=domInputEvents.length;
  await input("Input.dispatchMouseEvent",{type:"mousePressed",button:"left",buttons:1,...point,clickCount:1});
  await waitFor("held-stroke-active",s=>s.editor.gesture_active);
  expectedDOM.push({action:"held-stroke-before-blur",type:"pointerdown",button:0,...point,start_index:heldStart,end_index:domInputEvents.length});
  secondaryTarget=(await cmd("Target.createTarget",{url:"about:blank"})).targetId;
  await cmd("Target.activateTarget",{targetId:secondaryTarget});
  await waitFor("real-tab-blur-cancels-stroke",s=>metrics.documentFocused===false && !s.editor.gesture_active && s.input.pointer_buttons===0);
  check("blur-no-paint-through",()=>assertPausedStable(before,state));
  await cmd("Target.activateTarget",{targetId:originalTarget}); await cmd("Page.bringToFront");
  await waitFor("actual-canvas-refocused",()=>metrics.documentFocused===true);
  point=cellPoint([260,50]);
  await input("Input.dispatchMouseEvent",{type:"mouseMoved",...point,buttons:1});
  await input("Input.dispatchMouseEvent",{type:"mouseReleased",button:"left",buttons:0,...point,clickCount:1});
  await stable("old-release-cannot-commit-stroke",before);
  await cmd("Target.closeTarget",{targetId:secondaryTarget}); secondaryTarget=null;
  await key("Escape","Escape",27);
  await waitFor("real-Escape-opens-modal",s=>s.menu);
  const modal=checkpoint("modal-before-world-click");
  await stroke([400,20],[400,20],{label:"modal-blocked-world-stroke"});
  await stable("modal-blocks-material-tool",modal);
  await click("continue"); await waitFor("genuine-Continue-closes-menu",s=>!s.menu);
  check("Continue-keeps-authored-state",()=>assertPausedStable(before,state));
  await tool("picker");
  const authored=checkpoint("frozen-authored-design");
  await click("run");
  await waitFor("authored-Run-advances",s=>s.mode==="run" && s.tick>=15);
  await click("pause"); await waitFor("authored-Run-paused",s=>s.paused);
  check("Run-freezes-authored-revision-and-retires-both-histories",()=>{
    assertHistoryLocked(state); assert.equal(state.initial_hash,authored.current_hash);
    assert.equal(state.document.cells_sha256,authored.current_hash);
    assert.equal(state.definition_hash,authored.definition_hash);
    assert.equal(state.rapier_steps,0); assert.equal(state.pristine,true);
  });
  const paused=checkpoint("paused-authored-Run");
  await click("undo"); await stable("disabled-Run-Undo-does-nothing",paused);
  await keyEvent("keyDown","z","KeyZ",90,{modifiers:2});
  await keyEvent("keyUp","z","KeyZ",90,{modifiers:2});
  await waitFor("Run-Undo-command-refused",s=>s.last_refusal==="history_requires_edit_at_zero");
  await stable("Run-handler-enforces-history-boundary",paused);
  await click("speed_4"); await waitFor("four-times-pacing-selected",s=>s.speed===4);
  await pausedStep(false);
  await click("speed_1"); await waitFor("normal-pacing-restored",s=>s.speed===1);
  await material("sand",2); await field("temperature","777",s=>s.editor.primary.temperature===777); await tool("pencil");
  before=checkpoint("before-Run-intervention");
  await stroke([250,50],[260,50],{label:"Run-thermal-intervention"});
  await waitFor("Run-intervention-accepted",s=>s.mutation_count>before.mutation_count);
  check("Run-edit-is-journalled-not-undo-history",()=>assertRunIntervention(before,state,"pencil_stroke"));
  await stable("paused-intervention-does-not-step",checkpoint("after-Run-intervention"));
  const beforeReset=copy(state);
  await click("reset");
  await waitFor("Reset-rebuilds-frozen-design",s=>s.generation>beforeReset.generation && s.tick===0 && s.paused);
  check("Reset-restores-authored-tuples-not-evolved-physics",()=>{
    assert.equal(state.current_hash,authored.current_hash); assert.equal(state.initial_hash,authored.current_hash);
    assert.equal(state.definition_hash,authored.definition_hash); assert.equal(state.pristine,true);
    assert.equal(state.intervention_count,0); assertHistoryLocked(state);
  });
  const runReset=copy(state);
  await click("reset_edit");
  await waitFor("Reset-and-Edit-new-history",s=>s.generation>runReset.generation && s.mode==="edit");
  check("Reset-and-Edit-starts-empty-history",()=>{
    assertEdit(state); assert.equal(state.current_hash,authored.current_hash);
    assert.equal(state.document.undo_depth,0); assert.equal(state.document.redo_depth,0);
  });
  await material("sand",2); await tool("pencil");
  await editStroke([350,50],[352,50],"pencil_stroke",3,"new-Edit-epoch");
  await history("undo",authored.current_hash);
  before=checkpoint("new-history-exhausted"); await click("undo");
  await stable("old-Edit-history-never-resurrects",before);

  await tool("picker"); await click("template_coupled");
  await waitFor("coupled-Edit-at-zero",s=>s.ready && s.scene_id==="physics_pit" && s.mode==="edit");
  check("coupled-Edit-still-zero-ticks",()=>{assertEdit(state);assert.equal(state.rapier_active,true);});
  await material("wall",1); await tool("line");
  await editStroke([30,30],[40,30],"line",11,"hard-terrain-collider-edit");
  check("hard-terrain-collider-readiness",()=>assert.equal(state.pending_colliders,0));
  await tool("picker"); await click("run");
  await waitFor("new-coupled-Run-advances",s=>s.mode==="run" && s.tick>=15);
  await click("pause"); await waitFor("coupled-Run-paused",s=>s.paused);
  await pausedStep(true);
  await material("sand",2); await tool("pencil");
  before=checkpoint("before-body-occupancy-refusal");
  const bodyCell=state.body_poses[0].slice(0,2).map(Math.floor);
  await stroke(bodyCell,bodyCell,{label:"body-occupancy-negative"});
  await waitFor("occupied-cell-edit-refused",s=>String(s.last_refusal).includes("occup"));
  check("occupied-body-cell-refusal-is-nonmutating",()=>assertPausedStable(before,state));

  // Finish on the unchanged three-body Gallery, with all editing gizmos clear.
  await tool("picker"); await click("gallery");
  await waitFor("Gallery-600-real-coupled-ticks",s=>s.entry==="gallery" && s.tick>=600,300000);
  await click("pause"); await waitFor("Gallery-paused-for-final-capture",s=>s.paused);
  await click("fit");
  await waitFor("terminal-gizmos-clear",s=>s.editor.tool==="picker" && !s.editor.grid &&
    !s.editor.gesture_active && !s.editor.fill_active && s.editor.selection[2]===0);
  const terminalPause=checkpoint("terminal-paused-world");
  await stable("terminal-world-stable",terminalPause,{camera:true});
  check("all-browser-input-delivered-at-measured-coordinates",()=>assertTrustedDelivery(domInputEvents,expectedDOM));
  check("ordinary-Gallery-600-physics-contract",()=>assertGallery600(state));
  check("no-ordinary-application-console-errors",()=>assert.deepEqual(consoleEvents.filter(e=>["error","exception"].includes(e.type)),[]));

  // This is the first and terminal screenshot. No input or overlapping capture
  // is permitted afterwards, even if CDP times out before returning the PNG.
  await capture("world",true);
  await observe();
  check("physical-state-stayed-paused-through-capture",()=>assertPausedStable(terminalPause,state,{camera:true}));
  check("actual-world-viewport-has-visible-material-content",()=>{
    const pixels = captures.find(value=>value.name === "world")?.pixels;
    assert.ok(pixels && pixels.bright_fraction >= 0.008 && pixels.unique_4bit_rgb >= 8,
      "Actual world viewport is blank or insufficiently varied: " + JSON.stringify(pixels));
  });
} catch (error) {
  failures.push(String(error));
  console.error("SF_M2_BROWSER_FAILURE",String(error));
  if (ws?.readyState === WebSocket.OPEN && !captureStarted) await capture("failure");
} finally {
  const evidence = {schema:"sandfall-sf-m2-browser-v1",url,observed_at:new Date().toISOString(),
    duration_ms:Date.now()-started,status:failures.length ? "failed" : "passed",failures,
    deadlines_ms:{phase_wait_total:timeoutMs,capture:150000,post_capture_observation:30000,cleanup:5000},
    requested_viewport:{width,height,dpr},browser_version:browserVersion,logical_viewport:layout,
    served_identity:servedIdentity,harness_inputs:harnessInputs,harness_checkout:harnessCheckout,
    verification:{path:verificationPath,sha256:sha256(verificationBytes),
      build_source_commit:verification.build_source_commit,harness_source_commit:verification.harness_source_commit,
      source_equivalence:verification.source_equivalence},
    acceptance_mode:"ordinary dedicated Sandfall application; read-only test=1; genuine CDP input only",
    scope:{compatibility_web:true,threaded_web:false,human_visual_acceptance:false,
      coupled_body_count:3,ordinary_coupled_minimum_ticks:600,
      physical_save_restore_and_partial_fault:"Separate Godot backend/session gates; not claimed by this browser receipt"},
    final_state:state,final_metrics:metrics,checks,checkpoints,transitions,input_events:inputEvents,
    expected_dom_delivery:expectedDOM,dom_input_events:domInputEvents,cdp_poll_errors:pollErrors,
    captures,observations,console_events:consoleEvents};
  mkdirSync(dirname(output),{recursive:true});
  writeFileSync(output,JSON.stringify(evidence,null,2)+"\n");
  console.log("SF_M2_BROWSER_RESULT",JSON.stringify({status:evidence.status,failures,
    build_source:verification.build_source_commit,final_tick:state?.tick,rapier_steps:state?.rapier_steps,
    checks:checks.length,pixels:captures.find(value=>value.name === "world")?.pixels}));
  process.exitCode = failures.length ? 1 : 0;
  const cleanupDeadline = setTimeout(()=>{
    failures.push("CDP transport cleanup exceeded five seconds");
    evidence.status = "failed"; evidence.cleanup_timeout = true;
    writeFileSync(output,JSON.stringify(evidence,null,2)+"\n");
    console.error("SF_M2_BROWSER_CLEANUP_FAILURE",failures.at(-1));
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
