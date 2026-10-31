#!/usr/bin/env node
// Ordinary Web acceptance. Read state; drive ONLY genuine browser input.
// No Rapier acceptance mode, test callback invocation or application writes.
import { createHash } from "node:crypto";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { analyzePng, pngDimensions } from "./sf_m0_png_stats.mjs";
import { mapGodotRect, cssRectToScreenshotROI } from "./sf_m0_geometry.mjs";

const argv = new Map();
for (let i = 2; i < process.argv.length; i += 2) argv.set(process.argv[i], process.argv[i + 1]);
const port = Number(argv.get("--port") || "9231");
const url = argv.get("--url") || "http://127.0.0.1:8040/?test=1";
const output = resolve(argv.get("--output") || "sf-m0-ordinary/browser.json");
const screenshotPath = resolve(argv.get("--screenshot") || "sf-m0-ordinary/browser.png");
const timeoutMs = Number(argv.get("--timeout-ms") || "900000");
const width = Number(argv.get("--width") || "800");
const height = Number(argv.get("--height") || "450");
const dpr = Number(argv.get("--dpr") || "1");
const verificationPath = argv.get("--verification");
if (!verificationPath) throw Error("A SHA-verified export receipt is required (--verification)");
const verificationBytes = readFileSync(verificationPath);
const verification = JSON.parse(verificationBytes);
if (verification.status !== "passed" || !verification.logical_viewport)
  throw Error("Web export verification failed or lacks a source-bound viewport");
const layout = verification.logical_viewport;
const query = [...new URL(url).searchParams];
if (query.length !== 1 || query[0][0] !== "test" || query[0][1] !== "1")
  throw Error("Ordinary acceptance allows only the read-only ?test=1 observation mode");
if (![width, height, dpr, timeoutMs].every(x => Number.isFinite(x) && x > 0))
  throw Error("Invalid browser dimensions or timeout");
const sleep = ms => new Promise(r => setTimeout(r, ms));
const sha256 = bytes => createHash("sha256").update(bytes).digest("hex");
const harnessInputs = ["sf_m0_ordinary_browser.mjs","sf_m0_geometry.mjs","sf_m0_png_stats.mjs"]
  .map(path=>({path,sha256:sha256(readFileSync(new URL(path,import.meta.url)))}));
const started = Date.now();
const observations = [], consoleEvents = [], inputEvents = [], captures = [], transitions = [];
const failures = [];
const servedIdentity = [];
let ws, nextId = 0, state = null, metrics = null, browserVersion = null, domInputEvents = [], phase = "startup";
let pollErrors = 0, initialTick = null, firstAdvanceTick = null, menuPauseTick = null;
let captureStarted = false;
const pending = new Map();

const cmd = (method, params = {}, deadlineMs = 30000) => new Promise((resolve, reject) => {
  const id = ++nextId;
  const timeout = setTimeout(() => {
    if (pending.delete(id)) reject(Error(method + " CDP deadline expired"));
  }, deadlineMs);
  pending.set(id, {
    resolve: value => { clearTimeout(timeout); resolve(value); },
    reject: error => { clearTimeout(timeout); reject(error); },
  });
  ws.send(JSON.stringify({id, method, params}));
});

async function observe() {
  const r = await cmd("Runtime.evaluate", {
    // All application observations are reads. DOM listeners below only record
    // real browser events; they cannot dispatch events or alter Godot state.
    expression: `(() => {
      const c = document.querySelector('canvas');
      return {text:document.getElementById('cybersand-test-state')?.textContent ?? '',
        metrics:{canvas:c?.getBoundingClientRect().toJSON() ?? null,
          backing:c ? {width:c.width,height:c.height} : null,
          viewport:{width:innerWidth,height:innerHeight}, devicePixelRatio,
          visualViewport:visualViewport ? {width:visualViewport.width,height:visualViewport.height,
            offsetLeft:visualViewport.offsetLeft,offsetTop:visualViewport.offsetTop,scale:visualViewport.scale} : null,
          documentFocused:document.hasFocus(),visibility:document.visibilityState,
          activeElement:{tag:document.activeElement?.tagName,id:document.activeElement?.id},
          canvasStyle:c ? {width:getComputedStyle(c).width,height:getComputedStyle(c).height,
            transform:getComputedStyle(c).transform,objectFit:getComputedStyle(c).objectFit} : null,
          title:document.title,userAgent:navigator.userAgent,isolated:crossOriginIsolated},
        input:window.__sandfallObservedInput ?? []};
    })()`, returnByValue: true,
  });
  if (r.exceptionDetails) throw Error("Browser state read failed: " + JSON.stringify(r.exceptionDetails));
  const value = r.result?.value;
  if (!value) throw Error("Browser state read returned no object");
  metrics = value.metrics;
  domInputEvents = value.input;
  if (!value.text) return null;
  state = JSON.parse(value.text);
  if (Object.keys(state.rapier_test ?? {}).length)
    throw Error("Special Rapier acceptance fixture unexpectedly active");
  const sample = {elapsed_ms:Date.now()-started,phase,ready:state.ready,demo:state.demo,
    menu:state.menu,paused:state.paused,tick:state.tick,moves:state.moves,
    rapier:state.rapier,rapier_steps:state.rapier_steps,workers:state.workers,
    render_rejections:state.render_rejections,world_godot:state.view,
    continue_godot:state.buttons?.continue ?? null,metrics};
  observations.push(sample);
  console.log("SF_M0_ORDINARY_OBSERVATION", JSON.stringify({phase,tick:state.tick,
    menu:state.menu,paused:state.paused,moves:state.moves,elapsed_ms:sample.elapsed_ms}));
  return state;
}

async function waitFor(label, predicate, budgetMs = 90000) {
  phase = label;
  const deadline = Math.min(started + timeoutMs, Date.now() + budgetMs);
  while (Date.now() < deadline) {
    try {
      const current = await observe();
      if (current && predicate(current)) {
        transitions.push({phase:label,elapsed_ms:Date.now()-started,tick:current.tick,
          menu:current.menu,paused:current.paused});
        return current;
      }
    } catch (error) {
      if (!String(error).includes("CDP deadline expired")) throw error;
      pollErrors++;
      console.warn("SF_M0_ORDINARY_POLL", String(error));
    }
    await sleep(600);
  }
  throw Error("Timed out waiting for " + label);
}

async function input(method, params) {
  // Chromium surface capture temporarily changes input scaling at DPR > 1.
  // A timed-out CDP promise does not cancel the underlying capture. Therefore
  // all captures are terminal with respect to input, even diagnostic captures.
  if (captureStarted) throw Error("Browser input cannot follow screenshot capture");
  const event = {elapsed_ms:Date.now()-started,phase,method,params,acknowledged:false};
  inputEvents.push(event);
  // An acknowledgement is diagnostic, not an acceptance criterion. Send each
  // event exactly once; a late ack must not cause a second toggle/click.
  try { await cmd(method, params, 18000); event.acknowledged = true; }
  catch (error) { event.error = String(error); }
}

async function clickContinue() {
  if (!state?.menu || !state.buttons?.continue) throw Error("No visible Continue button");
  const mapped = mapGodotRect(state.buttons.continue, metrics, layout);
  const {x,y} = mapped.center;
  if (!(x > 0 && x < metrics.viewport.width && y > 0 && y < metrics.viewport.height))
    throw Error("Continue hit point is outside browser CSS viewport");
  inputEvents.push({action:"continue-target",elapsed_ms:Date.now()-started,
    godot:state.buttons.continue,mapped,metrics});
  await input("Input.dispatchMouseEvent", {type:"mouseMoved",x,y,buttons:0});
  await input("Input.dispatchMouseEvent", {type:"mousePressed",button:"left",buttons:1,x,y,clickCount:1});
  await sleep(100);
  await input("Input.dispatchMouseEvent", {type:"mouseReleased",button:"left",buttons:0,x,y,clickCount:1});
}

async function key(key, code, keyCode) {
  await input("Input.dispatchKeyEvent", {type:"keyDown",key,code,
    windowsVirtualKeyCode:keyCode,nativeVirtualKeyCode:keyCode});
  await sleep(100);
  await input("Input.dispatchKeyEvent", {type:"keyUp",key,code,
    windowsVirtualKeyCode:keyCode,nativeVirtualKeyCode:keyCode});
}

async function capture(name, scoreWorld = false) {
  captureStarted = true;
  const snap = {name,phase,elapsed_ms:Date.now()-started,state,metrics,
    method:"Page.captureScreenshot",from_surface:false};
  captures.push(snap);
  try {
    // Capture the visible browser view without Chromium's temporary surface
    // emulation/resize. Actual PNG dimensions still define the world ROI scale.
    const r = await cmd("Page.captureScreenshot", {format:"png",fromSurface:false}, 150000);
    const bytes = Buffer.from(r.data,"base64");
    const path = name === "world" ? screenshotPath : screenshotPath.replace(/\.png$/, "-"+name+".png");
    mkdirSync(dirname(path),{recursive:true});
    writeFileSync(path,bytes);
    const screenshot = pngDimensions(bytes);
    Object.assign(snap,{path,sha256:sha256(bytes),size_bytes:bytes.length,screenshot});
    if (scoreWorld) {
      if (state.menu !== false) throw Error("An open menu cannot qualify world pixels");
      if (metrics.canvasStyle?.transform !== "none") throw Error("Unexpected CSS canvas transform");
      if (metrics.visualViewport?.scale !== 1) throw Error("Unexpected browser page zoom");
      const mapped = mapGodotRect(state.view,metrics,layout);
      // Round inward and exclude the frame; UI/header pixels are never sampled.
      const roi = cssRectToScreenshotROI(mapped.css,metrics.viewport,screenshot,2);
      Object.assign(snap,{world_godot:state.view,world_css:mapped.css,transform:mapped.transform,
        pixels:analyzePng(bytes,roi)});
    }
    return snap;
  } catch (error) {
    snap.error = String(error);
    if (scoreWorld) throw error;
    console.warn("SF_M0_ORDINARY_CAPTURE", String(error));
    return snap;
  }
}

try {
  // Bind the tested HTTP origin to the independently verified local export.
  // The server serves that unchanged directory; all logs are outside it.
  for (const artifact of [...verification.artifacts,
      {path:"SHA256SUMS",sha256:verification.manifest_sha256}]) {
    const name = artifact.path;
    const address = new URL(name,url).href;
    const response = await fetch(address,{signal:AbortSignal.timeout(30000)});
    if (!response.ok) throw Error("Cannot verify served artifact: "+address+" HTTP "+response.status);
    const bytes = Buffer.from(await response.arrayBuffer());
    const actual = sha256(bytes);
    const expected = artifact.sha256;
    servedIdentity.push({url:address,sha256:actual,expected_sha256:expected,size:bytes.length});
    if (actual!==expected || (artifact.size!==undefined && bytes.length!==artifact.size))
      throw Error("Served export differs from verified artifact: "+name);
  }
  let tab;
  const discoveryDeadline = Date.now()+30000;
  while (Date.now()<discoveryDeadline) {
    try { tab=(await fetch("http://127.0.0.1:"+port+"/json/list",
      {signal:AbortSignal.timeout(2000)}).then(r=>r.json())).find(t=>t.type==="page"); }
    catch { /* Chrome startup is bounded below. */ }
    if (tab) break;
    await sleep(250);
  }
  if (!tab) throw Error("Chromium CDP page never appeared");
  ws = new WebSocket(tab.webSocketDebuggerUrl);
  await new Promise((ok,fail)=>{
    const timer=setTimeout(()=>fail(Error("CDP WebSocket connection deadline expired")),10000);
    ws.addEventListener("open",()=>{clearTimeout(timer);ok();},{once:true});
    ws.addEventListener("error",error=>{clearTimeout(timer);fail(error);},{once:true});
  });
  ws.addEventListener("message",event=>{
    const m=JSON.parse(event.data);
    if (m.method==="Runtime.consoleAPICalled") {
      consoleEvents.push({type:m.params.type,text:(m.params.args??[]).map(x=>x.value??x.description??"").join(" ").slice(0,2400)});
    } else if (m.method==="Runtime.exceptionThrown") {
      consoleEvents.push({type:"exception",text:JSON.stringify(m.params.exceptionDetails)});
    } else {
      const cb=pending.get(m.id);
      if (cb) {pending.delete(m.id);m.error?cb.reject(Error(JSON.stringify(m.error))):cb.resolve(m.result);}
    }
  });
  browserVersion = await cmd("Browser.getVersion");
  await cmd("Page.enable");
  await cmd("Runtime.enable");
  await cmd("Page.bringToFront");
  await cmd("Emulation.setDeviceMetricsOverride",{width,height,deviceScaleFactor:dpr,mobile:false});
  await cmd("Page.addScriptToEvaluateOnNewDocument",{source:`
    window.__sandfallObservedInput=[];
    for(const type of ['pointerdown','pointerup','keydown','keyup']) {
      addEventListener(type,event=>{
        window.__sandfallObservedInput.push({type,isTrusted:event.isTrusted,
          key:event.key??null,code:event.code??null,x:event.clientX??null,y:event.clientY??null,
          target:event.target?.tagName,targetId:event.target?.id,
          focused:document.hasFocus(),time_ms:performance.now()});
      },{capture:true,passive:true});
    }`});
  await cmd("Page.navigate",{url});
  await waitFor("initial-menu",s=>s.ready&&s.menu===true,150000);
  if (state.demo!=="neon_works" || state.rapier!==true || state.workers!==1)
    throw Error("Unexpected ordinary compatibility startup state");
  if (state.tick!==0) throw Error("Initial menu advanced simulation before Continue");
  initialTick=state.tick;
  // Capture only after the final genuine input and stable pause. Capturing the
  // initial menu can leave DPR emulation changed after a CDP timeout.
  phase="first-continue-click";
  await clickContinue();
  await waitFor("first-continue-closed",s=>s.menu===false);
  await waitFor("ordinary-fifteen-ticks",s=>s.menu===false&&s.tick-initialTick>=15&&s.moves>0,150000);
  firstAdvanceTick=state.tick;
  phase="keyboard-open-menu";
  await key("Escape","Escape",27);
  await waitFor("keyboard-menu-opened",s=>s.menu===true);
  menuPauseTick=state.tick;
  await sleep(1000);
  await waitFor("menu-still-pauses",s=>s.menu===true);
  if (state.tick!==menuPauseTick) throw Error("Native ticks advanced while normal menu was open");
  phase="second-continue-click";
  await clickContinue();
  await waitFor("second-continue-closed",s=>s.menu===false&&s.tick>menuPauseTick);
  phase="keyboard-pause";
  await key("p","KeyP",80);
  await waitFor("keyboard-paused",s=>s.menu===false&&s.paused===true);
  const pauseTick=state.tick;
  await sleep(1000);
  await waitFor("paused-stable",s=>s.paused===true);
  if (state.tick!==pauseTick) throw Error("Native ticks advanced after normal P-key pause");
  await capture("world",true);
  await observe();
  if (state.tick!==pauseTick || state.menu || !state.paused)
    throw Error("Application changed during paused world capture");
  if (state.render_rejections!==0) throw Error("Renderer rejected native snapshots");
  const world=captures.find(c=>c.name==="world");
  if (!world?.pixels || world.pixels.bright_fraction<.008 || world.pixels.unique_4bit_rgb<8)
    throw Error("Actual world viewport is blank or insufficiently varied: "+JSON.stringify(world?.pixels));
  const trustedPointer=domInputEvents.filter(e=>e.isTrusted&&e.type.startsWith("pointer")&&e.target==="CANVAS");
  const trustedKey=domInputEvents.filter(e=>e.isTrusted&&e.type==="keydown"&&e.target==="CANVAS");
  if (trustedPointer.length!==4 || !trustedKey.some(e=>e.key==="Escape") || !trustedKey.some(e=>e.code==="KeyP"))
    throw Error("Missing independently observed trusted pointer/keyboard delivery to canvas");
  const targets=inputEvents.filter(e=>e.action==="continue-target");
  for (let i=0;i<trustedPointer.length;i++) {
    const event=trustedPointer[i], target=targets[Math.floor(i/2)]?.mapped.center;
    if (!target || !event.focused || event.type!==(i%2?"pointerup":"pointerdown") ||
        Math.abs(event.x-target.x)>1 || Math.abs(event.y-target.y)>1)
      throw Error("Trusted canvas pointer differs from the intended CSS target");
  }
  if (state.paint_commands!==0) throw Error("UI clicks unexpectedly painted into the simulation");
} catch (error) {
  failures.push(String(error));
  console.error("SF_M0_ORDINARY_FAILURE",String(error));
  // A CDP timeout does not cancel capture. Do not start a second overlapping
  // screenshot, or issue any further input, after the first capture began.
  if (ws?.readyState===WebSocket.OPEN && !captureStarted) await capture("failure");
} finally {
  const evidence={schema:"sandfall-sf-m0-ordinary-visual-v2",url,
    observed_at:new Date().toISOString(),duration_ms:Date.now()-started,
    status:failures.length?"failed":"passed",failures,
    requested_viewport:{width,height,dpr},browser_version:browserVersion,
    logical_viewport:layout,served_identity:servedIdentity,
    harness_inputs:harnessInputs,
    verification:{path:verificationPath,sha256:sha256(verificationBytes),
      build_source_commit:verification.build_source_commit,harness_source_commit:verification.harness_source_commit,
      source_equivalence:verification.source_equivalence},
    acceptance_mode:"ordinary process/physics; read-only test=1; genuine CDP input only",
    initial_tick:initialTick,first_advance_tick:firstAdvanceTick,menu_pause_tick:menuPauseTick,
    final_state:state,final_metrics:metrics,transitions,input_events:inputEvents,
    dom_input_events:domInputEvents,cdp_poll_errors:pollErrors,
    captures,observations,console_events:consoleEvents};
  mkdirSync(dirname(output),{recursive:true});
  writeFileSync(output,JSON.stringify(evidence,null,2)+"\n");
  console.log("SF_M0_ORDINARY_RESULT",JSON.stringify({status:evidence.status,failures,
    build_source:verification.build_source_commit,final_tick:state?.tick,
    pixels:captures.find(c=>c.name==="world")?.pixels}));
  process.exitCode=failures.length?1:0;
  // A successful Browser.close reply need not finish the WebSocket handshake.
  // Keep cleanup bounded too; failure is retained and can never become green.
  const cleanupDeadline=setTimeout(()=>{
    failures.push("CDP transport cleanup exceeded five seconds");
    evidence.status="failed";
    evidence.cleanup_timeout=true;
    writeFileSync(output,JSON.stringify(evidence,null,2)+"\n");
    console.error("SF_M0_ORDINARY_CLEANUP_FAILURE",failures.at(-1));
    process.exit(1);
  },5000);
  cleanupDeadline.unref();
  if (ws?.readyState===WebSocket.OPEN) {
    try {await cmd("Browser.close",{},3000);} catch { /* Close transport below. */ }
  }
  if (ws && ws.readyState!==WebSocket.CLOSED) {
    ws.addEventListener("close",()=>clearTimeout(cleanupDeadline),{once:true});
    try {ws.close();} catch { /* Deadline records an unresolved transport. */ }
  } else clearTimeout(cleanupDeadline);
}
