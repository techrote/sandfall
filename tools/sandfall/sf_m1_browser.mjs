#!/usr/bin/env node
// Source-matched SF-M1 ordinary application acceptance. All application data is
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
import {
  assertOrdinaryState, assertEdit, assertInputClear, physicalCheckpoint,
  assertPausedStable, assertStep, assertReset, assertGallery600, assertTrustedDelivery,
} from "./sf_m1_browser_assertions.mjs";

const argv = new Map();
for (let i = 2; i < process.argv.length; i += 2) argv.set(process.argv[i], process.argv[i + 1]);
const port = Number(argv.get("--port") || "9231");
const url = argv.get("--url") || "http://127.0.0.1:8040/?test=1";
const output = resolve(argv.get("--output") || "sf-m1-browser/browser.json");
const screenshotPath = resolve(argv.get("--screenshot") || "sf-m1-browser/browser.png");
const timeoutMs = Number(argv.get("--timeout-ms") || "1200000");
const width = Number(argv.get("--width") || "800");
const height = Number(argv.get("--height") || "450");
const dpr = Number(argv.get("--dpr") || "1");
const verificationPath = argv.get("--verification");
if (!verificationPath) throw Error("A SHA-verified SF-M1 export receipt is required (--verification)");
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
const harnessInputs = ["sf_m1_browser.mjs", "sf_m1_browser_assertions.mjs", "sf_m0_geometry.mjs", "sf_m0_png_stats.mjs"]
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
    render_rejections:state.render_rejections,document_focused:metrics.documentFocused,
    visibility:metrics.visibility};
  observations.push(sample);
  const logKey = JSON.stringify([phase,state.generation,state.mode,state.menu,state.paused]);
  if (logKey !== lastLog || Date.now()-lastLogAt > 10000) {
    console.log("SF_M1_BROWSER_OBSERVATION", JSON.stringify(sample));
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
      console.warn("SF_M1_BROWSER_POLL", String(error));
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
    console.log("SF_M1_BROWSER_CHECK", name);
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
  const rect = state.buttons?.[name];
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

async function keyEvent(type, key, code, keyCode, {repeat = false} = {}) {
  await observe();
  const startIndex = domInputEvents.length;
  await input("Input.dispatchKeyEvent",{type,key,code,autoRepeat:repeat,
    windowsVirtualKeyCode:keyCode,nativeVirtualKeyCode:keyCode});
  await observe();
  expectedDOM.push({action:`${code}-${type}${repeat ? "-repeat" : ""}`,
    type:type === "keyUp" ? "keyup" : "keydown",code,repeat,
    start_index:startIndex,end_index:domInputEvents.length});
}

async function key(key, code, keyCode) {
  await keyEvent("keyDown",key,code,keyCode);
  await keyEvent("keyUp",key,code,keyCode);
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
    console.warn("SF_M1_BROWSER_CAPTURE", String(error));
    return snap;
  }
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
    for (const type of ['pointerdown','pointerup','pointercancel','keydown','keyup','wheel']) {
      addEventListener(type,event=>{
        window.__sandfallObservedInput.push({type,isTrusted:event.isTrusted,
          key:event.key??null,code:event.code??null,repeat:event.repeat??false,
          button:event.button??null,buttons:event.buttons??null,x:event.clientX??null,y:event.clientY??null,
          target:event.target?.tagName,targetId:event.target?.id,
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
  await waitFor("Sandbox-blank-Edit-ready",s=>s.ready && s.entry === "sandbox" && s.scene_id === "blank");
  check("Sandbox-enters-blank-Edit-zero",()=>assertEdit(state));
  await stable("Sandbox-neither-solver-advances",checkpoint("blank-Edit"));
  await click("template_native");
  await waitFor("native-template-Edit-ready",s=>s.ready && s.scene_id === "material_lab" && s.mode === "edit");
  check("native-template-is-Edit-zero",()=>{assertEdit(state); assert.equal(state.rapier_active,false);});
  const nativeInitial = checkpoint("native-initial");

  await click("step");
  await stable("disabled-Edit-Step-does-not-advance",nativeInitial);
  check("Edit-Step-refused",()=>assertEdit(state));
  phase = "legacy-actor-keys-in-Edit";
  await legacyKeys();
  await stable("legacy-keys-have-no-actor-or-world-authority",nativeInitial,{camera:true});
  check("legacy-input-left-no-held-authority",()=>assertInputClear(state));

  await click("pan_right");
  await waitFor("camera-pan-observed",s=>JSON.stringify(s.camera) !== JSON.stringify(nativeInitial.camera));
  check("camera-pan-does-not-change-physics-or-interest",()=>assertPausedStable(nativeInitial,state));
  const panned = copy(state.camera);
  await click("zoom_in");
  await waitFor("camera-zoom-observed",s=>JSON.stringify(s.camera) !== JSON.stringify(panned));
  check("camera-zoom-does-not-change-physics-or-interest",()=>assertPausedStable(nativeInitial,state));
  await click("fit");
  await waitFor("camera-fit-observed",s=>JSON.stringify(s.camera) === JSON.stringify(nativeInitial.camera));

  await click("run");
  await waitFor("native-Run-fresh-session-fifteen-ticks",s=>s.ready && s.mode === "run" && !s.paused &&
    s.generation > nativeInitial.generation && s.tick >= 15,150000);
  check("Run-freezes-initial-recipe-and-starts-native-only",()=>{
    assertOrdinaryState(state); assert.equal(state.rapier_active,false); assert.equal(state.rapier_steps,0);
    assert.equal(state.definition_hash,nativeInitial.definition_hash);
    assert.equal(state.initial_hash,nativeInitial.initial_hash);
    assert.ok(state.moves > 0,"No actual material movement during normal Run");
  });
  await click("pause");
  await waitFor("native-Run-paused",s=>s.mode === "run" && s.paused);
  await stable("native-Pause-stops-both-counters",checkpoint("native-paused"));
  await pausedStep(false);
  await sandboxReset(nativeInitial,"run");
  await sandboxReset(nativeInitial,"edit");

  await click("template_coupled");
  await waitFor("coupled-template-Edit-ready",s=>s.ready && s.scene_id === "physics_pit" && s.mode === "edit");
  check("coupled-template-ready-with-zero-solver-ticks",()=>{
    assertEdit(state); assert.equal(state.rapier_active,true); assert.equal(state.body_poses.length,3);
  });
  const coupledInitial = checkpoint("coupled-initial");
  await stable("coupled-Edit-neither-solver-advances",coupledInitial);
  await click("run");
  await waitFor("coupled-Run-fresh-session",s=>s.mode === "run" && !s.paused && s.tick >= 15 &&
    s.generation > coupledInitial.generation,150000);
  check("coupled-Run-freezes-initial-recipe",()=>{
    assert.equal(state.definition_hash,coupledInitial.definition_hash);
    assert.equal(state.initial_hash,coupledInitial.initial_hash);
    assert.equal(state.tick,state.rapier_steps);
  });
  await click("pause");
  await waitFor("coupled-Run-paused",s=>s.paused && s.mode === "run");
  await stable("coupled-Pause-stops-both-counters",checkpoint("coupled-paused"));
  await pausedStep(true);
  await sandboxReset(coupledInitial,"run");
  await sandboxReset(coupledInitial,"edit");

  await click("gallery");
  await waitFor("Gallery-autoplay-after-readiness",s=>s.ready && s.entry === "gallery" &&
    s.mode === "run" && !s.paused && s.scene_id === "physics_pit" && s.tick >= 1,150000);
  check("Gallery-ready-before-normal-coupled-advancement",()=>{
    assertOrdinaryState(state); assert.equal(state.rapier_active,true);
    assert.equal(state.rapier_steps,state.tick);
    assert.equal(state.pending_colliders,0);
    const installed = state.journal?.findLast(value=>value.action === "install" && value.generation === state.generation);
    assert.ok(installed,"Actual Gallery installation journal was not observed");
    assert.equal(installed.native_tick,0,"Gallery advanced native simulation during installation");
    assert.equal(installed.rapier_steps,0,"Gallery advanced Rapier during installation");
  });
  await waitFor("Gallery-600-actual-coupled-ticks",s=>s.tick >= 600,600000);
  check("ordinary-Gallery-600-contact-and-displacement",()=>assertGallery600(state));
  checkpoints.push({name:"ordinary-Gallery-600",elapsed_ms:Date.now()-started,state:copy(state),metrics:copy(metrics)});

  // A normal keydown pauses once; held/repeated keydown must not toggle again.
  await keyEvent("keyDown","p","KeyP",80);
  await waitFor("P-key-pauses-Gallery",s=>s.paused && !s.menu);
  const repeatBaseline = checkpoint("held-P-pause");
  for (let i=0;i<3;i++) await keyEvent("keyDown","p","KeyP",80,{repeat:true});
  await stable("held-P-repeats-do-not-resume",repeatBaseline);

  // Keep P physically held while arming a Godot button, then leave the actual
  // tab. Clearing the application's pointer map alone is insufficient: an old
  // BaseButton release must not admit a Step after its gesture is retired.
  await observe();
  const heldControlBaseline = checkpoint("before-held-Step-blur");
  const stepTarget = mapGodotRect(state.buttons.step,metrics,layout);
  const heldControlDOMStart = domInputEvents.length;
  inputEvents.push({action:"Step-held-across-real-blur",godot:state.buttons.step,
    mapped:stepTarget,metrics:copy(metrics),elapsed_ms:Date.now()-started});
  await input("Input.dispatchMouseEvent",{type:"mouseMoved",...stepTarget.center,buttons:0});
  await input("Input.dispatchMouseEvent",{type:"mousePressed",button:"left",buttons:1,...stepTarget.center,clickCount:1});
  await waitFor("held-Step-button-gesture-observed",s=>s.input.pending_ui_gestures === 1);
  expectedDOM.push({action:"Step-held-across-real-blur",type:"pointerdown",button:0,...stepTarget.center,
    start_index:heldControlDOMStart,end_index:domInputEvents.length});
  await stable("held-Step-awaits-release-without-repeat",heldControlBaseline);
  const uiClearBeforeBlur = state.input.clear_serial;
  secondaryTarget = (await cmd("Target.createTarget",{url:"about:blank"})).targetId;
  await cmd("Target.activateTarget",{targetId:secondaryTarget});
  await waitFor("real-blur-retires-held-button-and-key",s=>metrics.documentFocused === false &&
    s.input.clear_serial > uiClearBeforeBlur && s.input.pending_ui_gestures === 0 && s.input.pointer_buttons === 0);
  check("real-blur-retires-BaseButton-admission-and-held-P",()=>{
    assertInputClear(state); assertPausedStable(heldControlBaseline,state);
  });
  await cmd("Target.activateTarget",{targetId:originalTarget});
  await cmd("Page.bringToFront");
  await waitFor("held-button-tab-refocused",()=>metrics.documentFocused === true);
  await keyEvent("keyDown","p","KeyP",80,{repeat:true});
  // Browser focus loss may cancel its pointer; retain whatever up/cancel it
  // actually reports. The explicit old release must not create a new command.
  await input("Input.dispatchMouseEvent",{type:"mouseReleased",button:"left",buttons:0,...stepTarget.center,clickCount:1});
  await keyEvent("keyUp","p","KeyP",80);
  await stable("retired-button-release-and-key-repeat-cannot-step-or-resume",heldControlBaseline,{camera:true});
  check("retired-UI-release-leaves-no-pending-authority",()=>assertInputClear(state));
  await cmd("Target.closeTarget",{targetId:secondaryTarget});
  secondaryTarget = null;

  const pausedLegacyBaseline = checkpoint("before-paused-Run-legacy-and-paint-input");
  phase = "legacy-actor-and-pointer-paint-paths-in-paused-Run";
  await legacyKeys();
  await worldClick("left");
  await worldClick("right");
  await stable("paused-Run-legacy-keys-and-pointers-cannot-mutate-native-world",pausedLegacyBaseline,{camera:true});
  check("paused-Run-negative-input-leaves-no-held-authority",()=>assertInputClear(state));

  // Modal entry retires an in-progress real pointer gesture. Continue preserves
  // an existing user pause and cannot replay the gesture through the modal.
  const modalPhysical = checkpoint("before-modal-gesture");
  let point = await beginDrag();
  const clearBeforeModal = state.input.clear_serial;
  await key("Escape","Escape",27);
  await waitFor("Escape-opens-modal-and-retires-input",s=>s.menu && s.input.clear_serial > clearBeforeModal &&
    !s.input.gesture_active && s.input.pointer_buttons === 0);
  check("modal-entry-clears-pending-and-held-input",()=>{assertInputClear(state);assertPausedStable(modalPhysical,state);});
  const modalState = checkpoint("modal-paused");
  await input("Input.dispatchMouseEvent",{type:"mouseMoved",x:point.x-12,y:point.y-8,buttons:4});
  point = {x:point.x-12,y:point.y-8};
  await releaseMiddle(point);
  await stable("modal-blocks-camera-and-world-input",modalState,{camera:true});
  await click("continue");
  await waitFor("genuine-Continue-closes-modal",s=>!s.menu && s.paused);
  check("Continue-preserves-user-pause-and-no-paint-through",()=>assertPausedStable(modalState,state,{camera:true}));

  // Use another real browser tab to lose focus. No JS blur/event dispatch is
  // used, and refocus must require a new button press to reacquire the camera.
  point = await beginDrag();
  const blurPhysical = checkpoint("before-real-tab-blur");
  const clearBeforeBlur = state.input.clear_serial;
  secondaryTarget = (await cmd("Target.createTarget",{url:"about:blank"})).targetId;
  await cmd("Target.activateTarget",{targetId:secondaryTarget});
  await waitFor("real-tab-blur-retires-input",s=>metrics.documentFocused === false &&
    s.input.clear_serial > clearBeforeBlur && !s.input.gesture_active && s.input.pointer_buttons === 0);
  check("browser-blur-clears-input-without-world-mutation",()=>{assertInputClear(state);assertPausedStable(blurPhysical,state);});
  const afterBlur = checkpoint("after-real-tab-blur");
  await cmd("Target.activateTarget",{targetId:originalTarget});
  await cmd("Page.bringToFront");
  await waitFor("original-canvas-refocused",()=>metrics.documentFocused === true);
  await input("Input.dispatchMouseEvent",{type:"mouseMoved",x:point.x-16,y:point.y-8,buttons:4});
  point = {x:point.x-16,y:point.y-8};
  // Focus loss may cancel the browser pointer itself. Do not demand a second
  // pointerup after cancellation; retain the actual browser event trace.
  await releaseMiddle(point,{expectCanvas:false});
  await stable("refocus-requires-fresh-camera-gesture",afterBlur,{camera:true});
  check("refocus-has-no-stale-step-or-held-action",()=>assertInputClear(state));
  await cmd("Target.closeTarget",{targetId:secondaryTarget});
  secondaryTarget = null;

  point = await beginDrag();
  const outsidePhysical = checkpoint("before-outside-release");
  const clearBeforeOutside = state.input.clear_serial;
  const outside = {x:-12,y:point.y};
  await input("Input.dispatchMouseEvent",{type:"mouseMoved",...outside,buttons:4});
  await releaseMiddle(outside,{expectCanvas:false});
  await waitFor("outside-release-retires-gesture",s=>s.input.clear_serial > clearBeforeOutside &&
    !s.input.gesture_active && s.input.pointer_buttons === 0);
  check("outside-release-clears-input-without-physics",()=>{assertInputClear(state);assertPausedStable(outsidePhysical,state);});
  await click("fit");
  await waitFor("final-camera-fit",s=>JSON.stringify(s.camera) === JSON.stringify(coupledInitial.camera));
  const terminalPause = checkpoint("terminal-paused-world");
  await stable("terminal-paused-world-stable",terminalPause,{camera:true});
  check("all-genuine-controls-delivered-to-intended-canvas-coordinates",()=>assertTrustedDelivery(domInputEvents,expectedDOM));
  check("final-ordinary-Gallery-physics-scope",()=>assertGallery600(state));

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
  console.error("SF_M1_BROWSER_FAILURE",String(error));
  if (ws?.readyState === WebSocket.OPEN && !captureStarted) await capture("failure");
} finally {
  const evidence = {schema:"sandfall-sf-m1-browser-v1",url,observed_at:new Date().toISOString(),
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
  console.log("SF_M1_BROWSER_RESULT",JSON.stringify({status:evidence.status,failures,
    build_source:verification.build_source_commit,final_tick:state?.tick,rapier_steps:state?.rapier_steps,
    checks:checks.length,pixels:captures.find(value=>value.name === "world")?.pixels}));
  process.exitCode = failures.length ? 1 : 0;
  const cleanupDeadline = setTimeout(()=>{
    failures.push("CDP transport cleanup exceeded five seconds");
    evidence.status = "failed"; evidence.cleanup_timeout = true;
    writeFileSync(output,JSON.stringify(evidence,null,2)+"\n");
    console.error("SF_M1_BROWSER_CLEANUP_FAILURE",failures.at(-1));
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
