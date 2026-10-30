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
const timeoutMs = Number(args.get("--timeout-ms") || 240000);
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
  pending.set(id, { resolve, reject });
  ws.send(JSON.stringify({ id, method, params }));
});
await command("Page.enable");
await command("Runtime.enable");
await command("Page.navigate", { url });

let state = null;
const started = Date.now();
while (Date.now() - started < timeoutMs) {
  try {
    const r = await command("Runtime.evaluate", {
      expression: "document.getElementById('cybersand-test-state')?.textContent ?? ''",
      returnByValue: true,
    });
    const value = r.result?.value ?? "";
    if (value) {
      state = JSON.parse(value);
      if (state?.rapier_test && Object.hasOwn(state.rapier_test, "ticks")) break;
    }
  } catch { /* Context changing during startup */ }
  await sleep(500);
}
const complete = state?.rapier_test && Object.hasOwn(state.rapier_test, "ticks");
const browser = await command("Runtime.evaluate", {
  expression: "({userAgent:navigator.userAgent, isolated:crossOriginIsolated})",
  returnByValue: true,
});
const shot = await command("Page.captureScreenshot", { format: "png", fromSurface: true });
mkdirSync(dirname(output), { recursive: true });
mkdirSync(dirname(screenshot), { recursive: true });

const failures = [];
if (!complete) failures.push("Timed out before terminal Rapier probe state");
if (state?.ready !== true) failures.push("Web host not ready");
if (state?.rapier !== true) failures.push("Rapier backend unavailable");
if (state?.workers !== 1) failures.push("Compatibility profile did not select one worker");
if (state?.rapier_test?.ok !== true) failures.push("Native/cellular Rapier probe returned failure");
if (state?.rapier_test?.ticks !== 600) failures.push("Expected 600 real Rapier/native ticks");
if (!Number.isFinite(state?.rapier_test?.contacts) || state.rapier_test.contacts <= 0) failures.push("No positive body/material contacts");
if (!Number.isFinite(state?.rapier_test?.displaced) || state.rapier_test.displaced <= 0) failures.push("No positive material displacement");
const evidence = {
  schema: "sandfall-sf-m0-browser-probe-v1",
  url, observed_at: new Date().toISOString(), elapsed_ms: Date.now() - started,
  user_agent: browser.result?.value?.userAgent,
  cross_origin_isolated: browser.result?.value?.isolated,
  status: failures.length ? "failed" : "passed",
  failures, state, console_events: consoleEvents.slice(-200),
};
writeFileSync(output, JSON.stringify(evidence, null, 2) + "\n");
writeFileSync(screenshot, Buffer.from(shot.data, "base64"));
console.log(JSON.stringify({ status: evidence.status, failures, user_agent: evidence.user_agent,
  source_state: { workers: state?.workers, rapier: state?.rapier, rapier_test: state?.rapier_test } }));
await command("Browser.close");
if (failures.length) process.exitCode = 1;
