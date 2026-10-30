#!/usr/bin/env node
// Read-only SF-M0 browser triage against an immutable, already-built Web artifact.
// Use set_text only to trigger existing diagnostic state publication; never hash
// or export the live World during a physics run.
import {writeFileSync,mkdirSync} from "node:fs";
import {dirname,resolve} from "node:path";

const args = new Map();
for (let i=2; i<process.argv.length; i+=2) args.set(process.argv[i],process.argv[i+1]);
const port=Number(args.get("--port") ?? "9228");
const url=args.get("--url") ?? "http://127.0.0.1:8035/?test=1&rapier=1";
const output=resolve(args.get("--output") ?? "sf-m0-triage/probe.json");
const png=resolve(args.get("--screenshot") ?? "sf-m0-triage/probe.png");
const duration=Number(args.get("--duration-ms") ?? "110000");
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
let page=null;
for(let i=0;i<120;i++){
  try {
    const pages=await fetch("http://127.0.0.1:"+port+"/json/list").then(r=>r.json());
    page=pages.find(x=>x.type==="page");
    if(page) break;
  }catch{}
  await sleep(250);
}
if(!page) throw Error("No CDP page");
const ws=new WebSocket(page.webSocketDebuggerUrl);
await new Promise((ok,err)=>{ws.addEventListener("open",ok,{once:true});ws.addEventListener("error",err,{once:true})});
let id=0;
const pending=new Map();
const consoleEvents=[];
ws.addEventListener("message",event=>{
  const x=JSON.parse(event.data);
  if(x.method==="Runtime.consoleAPICalled"){
    consoleEvents.push({type:x.params.type,text:(x.params.args||[]).map(a=>a.value??a.description??"").join(" ").slice(0,5000)});
    return;
  }
  if(x.method==="Runtime.exceptionThrown"){
    consoleEvents.push({type:"exception",text:x.params.exceptionDetails?.text??"unknown"});
    return;
  }
  if(!pending.has(x.id))return;
  const item=pending.get(x.id);pending.delete(x.id);
  x.error?item.reject(new Error(JSON.stringify(x.error))):item.resolve(x.result);
});
const cmd=(method,params={})=>new Promise((resolve,reject)=>{
  const key=++id;pending.set(key,{resolve,reject});ws.send(JSON.stringify({id:key,method,params}));
});
await cmd("Page.enable");
await cmd("Runtime.enable");
await cmd("Page.navigate",{url});
const observed=[];
let lastState=null;
const started=Date.now();
while(Date.now()-started < duration){
  await sleep(2000);
  try{
    const run=await cmd("Runtime.evaluate",{
      expression:"window.cybersandTest?.invoke?.(JSON.stringify({op:'set_text',text:''})); ({exists:!!window.cybersandTest,href:location.href,title:document.title})",
      returnByValue:true
    });
    await sleep(200);
    const read=await cmd("Runtime.evaluate",{
      expression:"document.getElementById('cybersand-test-state')?.textContent ?? ''",
      returnByValue:true
    });
    let state=null;
    const value=read.result?.value??"";
    if(value)state=JSON.parse(value);
    const sample={elapsed_ms:Date.now()-started,found_test_object:!!run.result?.value?.exists,
      title:run.result?.value?.title,
      ready:state?.ready??null,menu:state?.menu??null,paused:state?.paused??null,
      tick:state?.tick??null,rapier_steps:state?.rapier_steps??null,
      rapier:state?.rapier??null,workers:state?.workers??null,
      pending_colliders:state?.collider_pending??null,rapier_test:state?.rapier_test??null};
    observed.push(sample);
    lastState=state??lastState;
    if(observed.length%5===0) console.log("SF_M0_TRIAGE_PROGRESS",JSON.stringify(sample));
    if(state?.rapier_test && Object.hasOwn(state.rapier_test,"ticks"))break;
  }catch(e){observed.push({elapsed_ms:Date.now()-started,error:String(e)})}
}
const passConsole=consoleEvents.some(x=>x.text.includes("WEB_RAPIER_PROBE") && x.text.includes('"ok":true'));
const readyConsole=consoleEvents.some(x=>x.text.includes("WEB_DEMO_READY") && x.text.includes("RAPIER2D"));
const exceptionConsole=consoleEvents.some(x=>x.text.includes("WEB_CPP_EXCEPTION_PROBE true"));
const progress=observed.some(x=>typeof x.tick==="number" && x.tick>0);
const finalCoupling=lastState?.rapier_test?.ok===true && lastState?.rapier_test?.ticks===600;
const result={
 schema:"sandfall-sf-m0-browser-triage-v1", source_web_commit:"5a2f6868aa8dbcb10febc6d3af2a2debfa246c18",
 url,elapsed_ms:Date.now()-started,phase:finalCoupling?"full_rapier_600_tick_pass":progress?"tick_progress_observed":readyConsole&&passConsole?"web_rapier_startup_only":"startup_not_proven",
 preflight:{web_ready_console:readyConsole,rapier_capability:passConsole,cpp_exception_probe:exceptionConsole},
 progress,final_coupling:finalCoupling,observed,terminal_state:lastState,console_events:consoleEvents.slice(-100)
};
mkdirSync(dirname(output),{recursive:true});
writeFileSync(output,JSON.stringify(result,null,2)+"\n");
const screenshot=await cmd("Page.captureScreenshot",{format:"png",fromSurface:true});
mkdirSync(dirname(png),{recursive:true});
writeFileSync(png,Buffer.from(screenshot.data,"base64"));
console.log("SF_M0_TRIAGE_TERMINAL",JSON.stringify({phase:result.phase,preflight:result.preflight,
  progress:result.progress,final_coupling:result.final_coupling,
  last_observation:observed.at(-1),console_events:consoleEvents.length}));
await cmd("Browser.close");
if(!(readyConsole&&passConsole&&exceptionConsole))process.exitCode=1;
