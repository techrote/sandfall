#!/usr/bin/env node
// SF-M0 ordinary interactive Web visual smoke: NO Rapier 600-tick fixture.
// Reuses a SHA-verified build and exercises the normal Godot _process,
// physics advancement, real browser UI input and screen capture.
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { analyzePng } from "./sf_m0_png_stats.mjs";

const argv = new Map();
for (let i = 2; i < process.argv.length; i += 2) argv.set(process.argv[i], process.argv[i + 1]);
const port = Number(argv.get("--port") || "9231");
const url = argv.get("--url") || "http://127.0.0.1:8040/?test=1";
const output = resolve(argv.get("--output") || "sf-m0-ordinary/browser.json");
const screenshotPath = resolve(argv.get("--screenshot") || "sf-m0-ordinary/browser.png");
const timeoutMs = Number(argv.get("--timeout-ms") || "210000");
const sleep = ms => new Promise(r => setTimeout(r, ms));
let tab;
for (let i = 0; i < 120; i++) {
  try {
    const tabs = await fetch("http://127.0.0.1:" + port + "/json/list").then(r => r.json());
    tab = tabs.find(x => x.type === "page");
    if (tab) break;
  } catch { /* Chromium may not yet expose CDP */ }
  await sleep(250);
}
if (!tab) throw Error("Chromium CDP page never appeared");
const ws = new WebSocket(tab.webSocketDebuggerUrl);
await new Promise((ok, fail) => {
  ws.addEventListener("open", ok, {once: true});
  ws.addEventListener("error", fail, {once: true});
});
let nextId = 0;
const pending = new Map(), consoleEvents = [];
ws.addEventListener("message", event => {
  const m = JSON.parse(event.data);
  if (m.method === "Runtime.consoleAPICalled") {
    consoleEvents.push({type: m.params.type, text:
      (m.params.args || []).map(x => x.value ?? x.description ?? "").join(" ").slice(0, 1200)});
    return;
  }
  if (m.method === "Runtime.exceptionThrown") {
    consoleEvents.push({type: "exception", text: m.params.exceptionDetails?.text ?? "unknown"});
    return;
  }
  const cb = pending.get(m.id);
  if (!cb) return;
  pending.delete(m.id);
  m.error ? cb.reject(Error(JSON.stringify(m.error))) : cb.resolve(m.result);
});
const cmd = (method, params = {}, deadlineMs = 18000) => new Promise((resolve, reject) => {
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

await cmd("Page.enable");
await cmd("Runtime.enable");
await cmd("Page.bringToFront");
await cmd("Emulation.setDeviceMetricsOverride", {
  width: 1280, height: 720, deviceScaleFactor: 1, mobile: false,
});
await cmd("Page.navigate", {url});
const started = Date.now();
let state = null, screenshot = null, pixels = null, canvas = null, title = null;
let attempts = 0, keyPresses = 0, pollErrors = 0;
const observations = [];
const sendEscape = async () => {
  await cmd("Input.dispatchKeyEvent", {type: "keyDown", key: "Escape", code: "Escape",
    windowsVirtualKeyCode: 27, nativeVirtualKeyCode: 27});
  await sleep(40);
  await cmd("Input.dispatchKeyEvent", {type: "keyUp", key: "Escape", code: "Escape",
    windowsVirtualKeyCode: 27, nativeVirtualKeyCode: 27});
  keyPresses++;
};

while (Date.now() - started < timeoutMs) {
  await sleep(800);
  try {
    const r = await cmd("Runtime.evaluate", {
      expression: "({text:document.getElementById('cybersand-test-state')?.textContent ?? '',title:document.title,canvas:document.querySelector('canvas')?.getBoundingClientRect().toJSON() ?? null})",
      returnByValue: true,
    });
    const v = r.result?.value ?? {};
    title = v.title;
    canvas = v.canvas;
    if (v.text) state = JSON.parse(v.text);
    if (state?.ready && state?.menu && keyPresses < 3) {
      if (keyPresses === 0 || Date.now() - started > 55000 + (keyPresses - 1) * 18000) {
        console.log("SF_M0_VISUAL_MENU_CLOSE_ATTEMPT", keyPresses + 1);
        await sendEscape();
      }
    }
    if (state) {
      const sample = {elapsed_ms: Date.now() - started, ready: state.ready,
        demo: state.demo, menu: state.menu, tick: state.tick,
        rapier: state.rapier, workers: state.workers,
        render_rejections: state.render_rejections, moves: state.moves,
        paused: state.paused, viewport: state.view};
      observations.push(sample);
      if (attempts++ % 6 === 0) console.log("SF_M0_VISUAL_OBSERVATION", JSON.stringify(sample));
      if (state.ready && !state.menu && state.tick >= 15) break;
    }
  } catch (e) {
    pollErrors++;
    if (pollErrors < 5 || pollErrors % 20 === 0)
      console.warn("SF_M0_VISUAL_CDP_POLL", String(e));
  }
}
try {
  const captured = await cmd("Page.captureScreenshot", {format: "png", fromSurface: true}, 45000);
  screenshot = Buffer.from(captured.data, "base64");
  pixels = analyzePng(screenshot);
} catch (error) { console.warn("SF_M0_VISUAL_CAPTURE", String(error)); }
const browser = await cmd("Runtime.evaluate", {
  expression: "({userAgent:navigator.userAgent, isolated:crossOriginIsolated})",
  returnByValue: true,
}).catch(() => null);

const failures = [];
if (!state?.ready) failures.push("No successful native Web startup state");
if (state?.demo !== "neon_works") failures.push("Normal default Neon Works world not selected");
if (state?.menu !== false) failures.push("Could not close normal menu via real browser Escape input");
if (!(state?.tick >= 15)) failures.push("Normal Web physics did not advance 15 native ticks");
if (state?.rapier !== true) failures.push("Rapier capability unavailable in normal Web host");
if (state?.workers !== 1) failures.push("Compatibility profile did not choose one worker");
if (!screenshot || !pixels) failures.push("No analyzable actual browser screenshot");
if (pixels && pixels.bright_fraction < .008)
  failures.push("World-central screenshot region is near black: bright_fraction=" + pixels.bright_fraction);
if (pixels && pixels.unique_4bit_rgb < 8)
  failures.push("Screenshot region has too few luminance/colour levels: unique=" + pixels.unique_4bit_rgb);
const evidence = {
  schema: "sandfall-sf-m0-ordinary-visual-v1", url,
  observed_at: new Date().toISOString(), duration_ms: Date.now() - started,
  status: failures.length ? "failed" : "passed", failures,
  user_agent: browser?.result?.value?.userAgent ?? null,
  isolated: browser?.result?.value?.isolated ?? null,
  key_presses: keyPresses, cdp_poll_errors: pollErrors,
  title, canvas, pixels, final_state: state,
  observations: observations.slice(-100), console_events: consoleEvents.slice(-150),
};
mkdirSync(dirname(output), {recursive: true});
mkdirSync(dirname(screenshotPath), {recursive: true});
writeFileSync(output, JSON.stringify(evidence, null, 2) + "\n");
if (screenshot) writeFileSync(screenshotPath, screenshot);
console.log("SF_M0_VISUAL_RESULT", JSON.stringify({
  status: evidence.status, failures, source_scene: state?.demo,
  final_tick: state?.tick, menu: state?.menu, render_rejections: state?.render_rejections,
  pixels, screenshot: Boolean(screenshot),
}));
try { await cmd("Browser.close", {}, 3000); } catch { ws.close(); }
if (failures.length) process.exitCode = 1;
