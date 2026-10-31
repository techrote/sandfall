#!/usr/bin/env node
// SF-M0 real Chromium CDP probe for the frozen CyberSand Web/Rapier baseline.
// No npm package required on Node 22+ (built-in fetch and WebSocket).
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";

const args = new Map();
for (let i = 2; i < process.argv.length; i += 2) args.set(process.argv[i], process.argv[i + 1]);
const port = Number(args.get("--port") || 9222);
const url = args.get("--url") || "http://127.0.0.1:8030/?test=1&rapier=1";
const output = resolve(args.get("--output") || "sf-m0-browser-probe.json");
const screenshot = resolve(args.get("--screenshot") || "sf-m0-browser-probe.png");
// Headless software-rendered 600-step Rapier runs measured ~541 steps in
// 240s on CI. Keep 600 physical ticks and use a 12-minute wall-clock cap;
// the separate 90s no-progress guard still stops genuine stalls.
const timeoutMs = Number(args.get("--timeout-ms") || 720000);
if (typeof WebSocket !== "function") throw new Error("Node 22+ with built-in WebSocket is required");

const sleep = ms => new Promise(r => setTimeout(r, ms));
let tab;
for (let i = 0; i < 120; i++) {
  try {
    const tabs = await fetch("http://127.0.0.1:" + port + "/json/list").then(r => r.json());
    tab = tabs.find(p => p.type === "page");
    if (tab) break;
  } catch { /* Chrome not ready yet */ }
  await sleep(250);
}
if (!tab) throw new Error("Chrome debugging page not available");
const ws = new WebSocket(tab.webSocketDebuggerUrl);
await new Promise((resolveOpen, rejectOpen) => {
  ws.addEventListener("open", resolveOpen, { once: true });
  ws.addEventListener("error", rejectOpen, { once: true });
});
let nextId = 1;
const pending = new Map();
const consoleEvents = [];
const phaseEvents = [];
let latestPhase = null;
let lastPhaseAt = Date.now();
let lastDomState = null;
let pollFailures = 0;
ws.addEventListener("message", event => {
  const data = JSON.parse(event.data);
  if (data.method === "Runtime.consoleAPICalled") {
    const params = data.params || {};
    consoleEvents.push({ type: params.type, text: (params.args || []).map(x => x.value ?? x.description ?? "").join(" ").slice(0, 1200) });
    return;
  }
  if (data.method === "Runtime.exceptionThrown") {
    consoleEvents.push({ type: "exception", text: data.params?.exceptionDetails?.text ?? "Unknown" });
    return;
  }
  if (!pending.has(data.id)) return;
  const callback = pending.get(data.id);
  pending.delete(data.id);
  if (data.error) callback.reject(new Error(JSON.stringify(data.error)));
  else callback.resolve(data.result);
});
const command = (method, params = {}) => new Promise((resolve, reject) => {
  const id = nextId++;
  const deadline = setTimeout(() => {
    if (!pending.has(id)) return;
    pending.delete(id);
    reject(new Error("CDP " + method + " timed out"));
  }, 12000);
  pending.set(id, {
    resolve: value => { clearTimeout(deadline); resolve(value); },
    reject: error => { clearTimeout(deadline); reject(error); },
  });
  ws.send(JSON.stringify({ id, method, params }));
});
await command("Page.enable");
await command("Runtime.enable");
await command("Page.navigate", { url });

let state = null;
let browser = null;
let screenshotBytes = null;
const started = Date.now();
while (Date.now() - started < timeoutMs) {
  try {
    const r = await command("Runtime.evaluate", {
      expression: "({state:document.getElementById('cybersand-test-state')?.textContent ?? '', phase:window.sandfallM0ProbeProgress ?? null, test:window.cybersandTest?.state ?? null})",
      returnByValue: true,
    });
    const value = r.result?.value ?? {};
    if (value.state) state = JSON.parse(value.state);
    if (value.test && Object.keys(value.test).length) lastDomState = value.test;
    if (value.phase && JSON.stringify(value.phase) !== JSON.stringify(latestPhase)) {
      latestPhase = value.phase;
      phaseEvents.push({ observed_ms: Date.now() - started, ...latestPhase });
      lastPhaseAt = Date.now();
      console.log("SF_M0_BROWSER_PHASE", JSON.stringify(latestPhase));
    }
    if (state?.rapier_test && Object.hasOwn(state.rapier_test, "ticks")) break;
  } catch (error) {
    pollFailures++;
    if (pollFailures <= 4 || pollFailures % 20 === 0) console.warn("SF_M0_CDP_POLL", error.message);
  }
  // A static phase is not a completion result. Stop boundedly and record
  // exactly where progress ceased instead of mislabelling startup as failed.
  if (latestPhase && Date.now() - lastPhaseAt > 90000) break;
  await sleep(750);
}
const complete = !!(state?.rapier_test && Object.hasOwn(state.rapier_test, "ticks"));
try {
  browser = await command("Runtime.evaluate", {
    expression: "({userAgent:navigator.userAgent, isolated:crossOriginIsolated})",
    returnByValue: true,
  });
} catch (error) { console.warn("SF_M0_BROWSER_METADATA", error.message); }
try {
  const shot = await command("Page.captureScreenshot", { format: "png", fromSurface: true });
  screenshotBytes = Buffer.from(shot.data, "base64");
} catch (error) { console.warn("SF_M0_SCREENSHOT", error.message); }
mkdirSync(dirname(output), { recursive: true });
mkdirSync(dirname(screenshot), { recursive: true });

const textLogs = consoleEvents.map(item => item.text);
const startup = {
  godot: textLogs.some(text => text.includes("Godot Engine v4.7")),
  rapier_registered: textLogs.some(text => text.includes("PHYSICS ENGINE 2D: Rapier2D v0.35.2")),
  rapier_capability: textLogs.some(text => text.includes('WEB_RAPIER_PROBE {"ok":true')),
  cpp_exception_probe: textLogs.some(text => text.includes("WEB_CPP_EXCEPTION_PROBE true")),
  web_ready: textLogs.some(text => text.includes("WEB_DEMO_READY")),
  compat_one_worker: textLogs.some(text => text.includes("COMPAT · 1 WORKERS · RAPIER2D")),
};
const failures = [];
if (!complete) failures.push("600-tick Rapier acceptance incomplete; last observable phase: " +
  JSON.stringify(latestPhase ?? "no phase telemetry"));
if (complete) {
  if (state?.ready !== true) failures.push("Host readiness false in terminal result");
  if (state?.rapier !== true) failures.push("Rapier unavailable in terminal result");
  if (state?.workers !== 1) failures.push("Compatibility worker count differs from 1");
  if (state?.rapier_test?.ok !== true) failures.push("Rapier fixture reported failed acceptance");
  if (state?.rapier_test?.ticks !== 600) failures.push("Expected 600 actual native/Rapier ticks");
  if (!Number.isFinite(state?.rapier_test?.contacts) || state.rapier_test.contacts <= 0) failures.push("No positive body/material contacts");
  if (!Number.isFinite(state?.rapier_test?.displaced) || state.rapier_test.displaced <= 0) failures.push("No positive material displacement");
}
for (const [key, passed] of Object.entries(startup)) if (!passed) failures.push("Startup proof absent: " + key);
const evidence = {
  schema: "sandfall-sf-m0-browser-probe-v1",
  url, observed_at: new Date().toISOString(), elapsed_ms: Date.now() - started,
  user_agent: browser?.result?.value?.userAgent ?? null,
  cross_origin_isolated: browser?.result?.value?.isolated ?? null,
  status: failures.length ? "failed" : "passed",
  startup, failures, phase_events: phaseEvents.slice(-200),
  latest_phase: latestPhase, dom_state: lastDomState, cdp_poll_failures: pollFailures,
  state, console_events: consoleEvents.slice(-200),
};
writeFileSync(output, JSON.stringify(evidence, null, 2) + "\n");
if (screenshotBytes) writeFileSync(screenshot, screenshotBytes);
console.log(JSON.stringify({ status: evidence.status, failures,
  startup, latest_phase: latestPhase, user_agent: evidence.user_agent,
  source_state: { workers: state?.workers, rapier: state?.rapier, rapier_test: state?.rapier_test } }));
try { await command("Browser.close"); } catch { ws.close(); }
if (failures.length) process.exitCode = 1;
