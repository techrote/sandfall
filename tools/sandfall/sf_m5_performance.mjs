#!/usr/bin/env node
// Measure the ordinary source-matched Web application. Application state is
// read-only; all transitions use trusted browser input and settled controls.
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {mkdirSync,readFileSync,writeFileSync} from 'node:fs';
import {dirname,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import os from 'node:os';
import {assertOrdinaryState,assertTrustedDelivery} from './sf_m2_browser_assertions.mjs';
import {sampleControlLayout,sameControlLayout,controlLayoutSettled} from './sf_m3_browser_assertions.mjs';
import {unexpectedConsoleErrors} from './sf_m4_browser_assertions.mjs';
import {assertPerformanceState,summarizeInterval,assertFinalDistribution} from './sf_m5_performance_assertions.mjs';

const args = new Map();
for (let i=2;i<process.argv.length;i+=2) args.set(process.argv[i],process.argv[i+1]);
const port=Number(args.get('--port')||'9231');
const url=args.get('--url')||'http://127.0.0.1:8040/?test=1';
const output=resolve(args.get('--output')||'sf-m5-performance/browser.json');
const verificationPath=args.get('--verification');
const profile=args.get('--profile')||'compat';
const workload=args.get('--workload')||'sixteen_body';
const bodies=workload==='sixteen_body'?16:0;
const width=Number(args.get('--width')||'800'), height=Number(args.get('--height')||'450'), dpr=Number(args.get('--dpr')||'1');
const durationMs=Number(args.get('--duration-ms')||'30000'), timeoutMs=Number(args.get('--timeout-ms')||'420000');
const speed=Number(args.get('--speed')||'1');
const workers=args.get('--workers')||new URL(url).searchParams.get('workers')||'auto';
const repetition=Number(args.get('--repetition')||'1');
assert.ok(verificationPath,'Source-matched Web verification is required');
assert.ok(['compat','threaded'].includes(profile));
assert.ok(['blank','material_lab','sixteen_body'].includes(workload));
assert.ok([0.25,0.5,1,2,4].includes(speed));
assert.ok(['auto','1','2','4','6'].includes(workers));
assert.ok([width,height,dpr,durationMs,timeoutMs,repetition].every(n=>Number.isFinite(n)&&n>0));
assert.ok(durationMs>=5000&&durationMs<=120000,'Register a 5–120 second interval');
const query=new URL(url).searchParams;
assert.equal(query.get('test'),'1');
assert.ok([...query.keys()].every(k=>['test','workers'].includes(k)),'Unexpected application query parameter');
assert.equal(query.getAll('test').length,1);
assert.ok(query.getAll('workers').length<=1);
if(query.has('workers'))assert.equal(query.get('workers'),workers);
else assert.equal(workers,'auto','An explicit worker request must be present in the actual URL');
const verificationBytes=readFileSync(verificationPath), verification=JSON.parse(verificationBytes);
assert.equal(verification.status,'passed');
assert.equal(verification.application_entry,'sandfall');
assert.equal(verification.entry_scene,'res://sandfall_main.tscn');
assert.equal(verification.profile,profile,'Verified export belongs to another profile');
const layout=verification.logical_viewport;
assert.ok(layout,'Source-derived viewport is absent');
const sha=bytes=>createHash('sha256').update(bytes).digest('hex');
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const root=fileURLToPath(new URL('../../',import.meta.url));
const inputs=['sf_m5_performance.mjs','sf_m5_performance_assertions.mjs','sf_m3_browser_assertions.mjs',
  'sf_m2_browser_assertions.mjs','sf_m4_browser_assertions.mjs','sf_m0_geometry.mjs'].map(path=>({path,sha256:sha(readFileSync(new URL(path,import.meta.url)))}));
const harnessHead=execFileSync('git',['-C',root,'rev-parse','HEAD'],{encoding:'utf8'}).trim();
const harnessDirty=execFileSync('git',['-C',root,'status','--porcelain','--',...inputs.map(x=>'tools/sandfall/'+x.path)],{encoding:'utf8'}).trim();
const started=Date.now(), deadline=started+timeoutMs;
const served=[],samples=[],consoleEvents=[],inputEvents=[],expectedDOM=[],controlLayouts=[],failures=[],pending=new Map();
let ws,nextId=0,state=null,metrics=null,domEvents=[],browser=null,phase='startup';
let first=null,last=null,terminal=null,summary=null,startup=null,configuredWorkers=null,buildInfo=null;

function cmd(method,params={},budget=30000){
  return new Promise((resolve,reject)=>{
    const id=++nextId;
    const timer=setTimeout(()=>{if(pending.delete(id))reject(Error(method+' deadline expired'));},budget);
    pending.set(id,{resolve:r=>{clearTimeout(timer);resolve(r);},reject:e=>{clearTimeout(timer);reject(e);}});
    try{ws.send(JSON.stringify({id,method,params}));}catch(e){pending.delete(id);clearTimeout(timer);reject(e);}
  });
}

async function observe(){
  const reply=await cmd('Runtime.evaluate',{expression:`(() => {
    const canvas=document.querySelector('canvas');
    return {text:document.getElementById('sandfall-test-state')?.textContent??'',
      startup:globalThis.sandfallWebStartup??null,input:window.__sandfallObservedInput??[],
      metrics:{canvas:canvas?.getBoundingClientRect().toJSON()??null,
        backing:canvas?{width:canvas.width,height:canvas.height}:null,
        viewport:{width:innerWidth,height:innerHeight},devicePixelRatio,
        visualViewport:visualViewport?{width:visualViewport.width,height:visualViewport.height,
          offsetLeft:visualViewport.offsetLeft,offsetTop:visualViewport.offsetTop,scale:visualViewport.scale}:null,
        canvasStyle:canvas?{width:getComputedStyle(canvas).width,height:getComputedStyle(canvas).height,
          transform:getComputedStyle(canvas).transform,objectFit:getComputedStyle(canvas).objectFit}:null,
        secure:isSecureContext,isolated:crossOriginIsolated,hardwareConcurrency:navigator.hardwareConcurrency,
        sharedArrayBuffer:typeof SharedArrayBuffer==='function',worker:typeof Worker==='function',
        focused:document.hasFocus(),visibility:document.visibilityState,userAgent:navigator.userAgent}};})()`,returnByValue:true});
  assert.ok(!reply.exceptionDetails,'Browser read failed: '+JSON.stringify(reply.exceptionDetails));
  const value=reply.result?.value;assert.ok(value,'No browser observation');
  metrics=value.metrics;domEvents=value.input;startup=value.startup;
  if(!value.text)return null;
  state=JSON.parse(value.text);
  assertOrdinaryState(state,{requireReady:false});
  return state;
}

async function waitFor(label,predicate,budget=90000){
  phase=label;const until=Math.min(deadline,Date.now()+budget);
  while(Date.now()<until){const value=await observe();if(value&&predicate(value))return structuredClone(value);await sleep(200);}
  throw Error('Timed out waiting for '+label);
}

async function input(method,params){
  inputEvents.push({phase,elapsed_ms:Date.now()-started,method,params});
  // State-changing commands are sent once. A CDP deadline fails this run.
  await cmd(method,params,18000);
}

async function click(name){
  let baseline=null,confirmed=null;
  await waitFor('control-'+name+'-layout',s=>{
    const current=sampleControlLayout(s,metrics,layout,name);
    if(controlLayoutSettled(baseline,current)){confirmed=current;return true;}
    if(!sameControlLayout(baseline,current)||current?.frame<baseline?.frame)baseline=current;
    return false;
  },20000);
  assert.ok(controlLayoutSettled(baseline,confirmed));
  controlLayouts.push({name,first_frame:baseline.frame,confirmed_frame:confirmed.frame,geometry:confirmed.geometry,mapped:confirmed.mapped});
  const {x,y}=confirmed.mapped.center,begin=domEvents.length;
  await input('Input.dispatchMouseEvent',{type:'mouseMoved',x,y,buttons:0});
  await input('Input.dispatchMouseEvent',{type:'mousePressed',button:'left',buttons:1,x,y,clickCount:1});
  await sleep(100);
  await input('Input.dispatchMouseEvent',{type:'mouseReleased',button:'left',buttons:0,x,y,clickCount:1});
  await observe();
  for(const type of ['pointerdown','pointerup'])expectedDOM.push({action:name,type,button:0,x,y,start_index:begin,end_index:domEvents.length});
}

async function key(key,code,keyCode,{text,modifiers=0}={}){
  await observe();const begin=domEvents.length;
  await input('Input.dispatchKeyEvent',{type:'keyDown',key,code,windowsVirtualKeyCode:keyCode,nativeVirtualKeyCode:keyCode,modifiers,...(text?{text,unmodifiedText:text}:{})});
  await input('Input.dispatchKeyEvent',{type:'keyUp',key,code,windowsVirtualKeyCode:keyCode,nativeVirtualKeyCode:keyCode,modifiers});
  await observe();
  for(const type of ['keydown','keyup'])expectedDOM.push({action:'text-'+key,type,code,repeat:false,allow_godot_ime:true,start_index:begin,end_index:domEvents.length});
}

async function launch(){
  if(workload==='sixteen_body'){
    await click('gallery_browse');await waitFor('gallery-open',s=>s.project_modal==='gallery'&&s.menu);
    await click('gallery_search');await key('a','KeyA',65,{modifiers:2});
    for(const ch of 'Sandfall 16-Body'){
      const code=/[a-zA-Z]/.test(ch)?'Key'+ch.toUpperCase():/\d/.test(ch)?'Digit'+ch:ch===' '?'Space':'Minus';
      await key(ch,code,ch===' '?32:ch==='-'?189:ch.toUpperCase().charCodeAt(0),{text:ch});
    }
    await key('Enter','Enter',13);
    await waitFor('gallery-sixteen-visible',s=>s.gallery.visible_ids.length===1&&s.gallery.visible_ids[0]==='sixteen_body');
    await click('gallery_launch_sixteen_body');
    await waitFor('sixteen-autoplay',s=>s.ready&&s.mode==='run'&&s.scene_id===workload&&!s.paused&&s.tick>0,150000);
  }else{
    await click('sandbox');await waitFor('sandbox-ready',s=>s.ready&&s.entry==='sandbox'&&s.mode==='edit',150000);
    await click(workload==='blank'?'template_blank':'template_native');
    await waitFor('template-ready',s=>s.ready&&s.scene_id===workload&&s.mode==='edit'&&s.tick===0,150000);
    await click('run');await waitFor('template-running',s=>s.mode==='run'&&!s.paused&&s.tick>0,150000);
  }
  if(speed!==state.speed){await click('speed_'+speed);await waitFor('requested-speed',s=>s.speed===speed);}
}

async function sample(){
  await observe();
  assertPerformanceState(state,{bodies,profile,configuredWorkers});
  assert.equal(state.paused,false,'Measurement unexpectedly paused');
  assert.equal(state.speed,speed);
  assert.equal(metrics.focused,true);assert.equal(metrics.visibility,'visible');
  const cdp=await cmd('Performance.getMetrics');
  samples.push({elapsed_ms:Date.now()-started,observed_usec:state.performance.observed_usec,
    frame:state.frame,tick:state.tick,rapier_steps:state.rapier_steps,generation:state.generation,
    mode:state.mode,paused:state.paused,speed:state.speed,workers:state.workers,
    workers_observed_last_tick:state.native.workers_observed_last_tick??null,
    web_profile:state.native.web_profile??null,
    pending_colliders:state.pending_colliders,pacing:state.performance.pacing,
    scheduled_tick_credits:state.performance.scheduled_tick_credits,completed_callback_ticks:state.performance.completed_callback_ticks,
    render_payload_bytes:state.performance.render.counters.payload_bytes??0,
    godot_memory_static_bytes:state.performance.godot_memory_static_bytes,
    godot_memory_static_max_bytes:state.performance.godot_memory_static_max_bytes,
    godot_memory_static_available:state.performance.godot_memory_static_available===true,
    cdp_metrics:Object.fromEntries(cdp.metrics.map(row=>[row.name,row.value]))});
  return structuredClone(state);
}

try{
  for(const file of [...verification.artifacts,{path:'SHA256SUMS',sha256:verification.manifest_sha256}]){
    const address=new URL(file.path,url).href,response=await fetch(address,{signal:AbortSignal.timeout(30000)});
    assert.ok(response.ok,'Served artifact unavailable: '+file.path);
    const bytes=Buffer.from(await response.arrayBuffer()),actual=sha(bytes);
    assert.equal(actual,file.sha256,'Served bytes differ: '+file.path);
    if(file.size!==undefined)assert.equal(bytes.length,file.size);
    if(file.path==='build-info.json')buildInfo=JSON.parse(bytes.toString('utf8'));
    served.push({path:file.path,sha256:actual,bytes:bytes.length,mime:response.headers.get('content-type')});
  }
  let tab;const until=Date.now()+30000;
  while(Date.now()<until){
    try{tab=(await fetch(`http://127.0.0.1:${port}/json/list`,{signal:AbortSignal.timeout(2000)}).then(r=>r.json())).find(t=>t.type==='page');}catch{}
    if(tab)break;await sleep(200);
  }
  assert.ok(tab,'No isolated Chromium target');
  ws=new WebSocket(tab.webSocketDebuggerUrl);
  await new Promise((resolve,reject)=>{
    const timer=setTimeout(()=>reject(Error('CDP connection deadline expired')),10000);
    ws.addEventListener('open',()=>{clearTimeout(timer);resolve();},{once:true});
    ws.addEventListener('error',error=>{clearTimeout(timer);reject(error);},{once:true});
  });
  ws.addEventListener('message',event=>{
    const message=JSON.parse(event.data);
    if(message.method==='Runtime.consoleAPICalled')consoleEvents.push({type:message.params.type,text:message.params.args.map(x=>x.value??x.description??'').join(' ').slice(0,3000)});
    else if(message.method==='Runtime.exceptionThrown')consoleEvents.push({type:'exception',text:JSON.stringify(message.params.exceptionDetails)});
    const callback=pending.get(message.id);
    if(callback){pending.delete(message.id);message.error?callback.reject(Error(JSON.stringify(message.error))):callback.resolve(message.result);}
  });
  browser=await cmd('Browser.getVersion');await cmd('Page.enable');await cmd('Runtime.enable');await cmd('Performance.enable');
  await cmd('Page.bringToFront');
  await cmd('Emulation.setDeviceMetricsOverride',{width,height,deviceScaleFactor:dpr,mobile:false});
  await cmd('Page.addScriptToEvaluateOnNewDocument',{source:`window.__sandfallObservedInput=[];
    for(const type of ['pointerdown','pointerup','keydown','keyup'])addEventListener(type,event=>{
      window.__sandfallObservedInput.push({type,isTrusted:event.isTrusted,key:event.key??null,code:event.code??null,
        repeat:event.repeat??false,button:event.button??null,x:event.clientX??null,y:event.clientY??null,
        target:event.target?.tagName,targetId:event.target?.id,targetClass:event.target?.className,
        targetContentEditable:event.target?.isContentEditable===true,targetIsActive:event.target===document.activeElement,
        targetSharesCanvasParent:event.target?.parentElement===document.querySelector('canvas')?.parentElement,
        focused:document.hasFocus(),time_ms:performance.now()});},{capture:true,passive:true});`});
  await cmd('Page.navigate',{url});
  await waitFor('home-ready',s=>s.app_ready&&s.entry==='home',150000);
  assert.equal(state.source_commit,verification.build_source_commit);
  const native=verification.artifacts.find(f=>f.path===`libcybersand_native.web.${profile==='threaded'?'threads':'nothreads'}.wasm`);
  assert.ok(native,'Missing profile-specific native module');assert.equal(state.native_sha256,native.sha256);
  assert.equal(state.provenance.build_profile,profile);
  if(profile==='threaded'){
    assert.equal(metrics.secure,true);assert.equal(metrics.isolated,true);
    assert.equal(metrics.sharedArrayBuffer,true);assert.equal(metrics.worker,true);
  }
  await launch();configuredWorkers=state.workers;
  if(workers!=='auto')assert.equal(configuredWorkers,Number(workers));
  if(profile==='compat')assert.equal(configuredWorkers,1);
  await waitFor('warmup-actual-work',s=>s.tick>=30,120000);
  phase='measurement';first=await sample();
  let nextLog=Date.now()+5000;
  while(Date.now()<deadline){
    await sleep(500);last=await sample();
    if(Date.now()>=nextLog){console.log('SF_M5_PERFORMANCE_SAMPLE',JSON.stringify(samples.at(-1)));nextLog=Date.now()+5000;}
    if(last.performance.observed_usec-first.performance.observed_usec>=durationMs*1000)break;
  }
  summary=summarizeInterval(first,last,{bodies,profile,configuredWorkers,durationMs});
  await click('pause');
  await waitFor('paused-with-current-distributions',s=>s.paused&&s.performance.host.metrics.native_tick_ms?.count===s.tick,15000);
  terminal=structuredClone(state);
  assertFinalDistribution(terminal,{bodies});
  if(profile==='threaded'&&configuredWorkers>1&&workload!=='blank')
    assert.ok(terminal.native.web_profile?.observed_workers_peak>=2,'Multiworker execution was not observed in actual native work');
  assertTrustedDelivery(domEvents,expectedDOM);
  assert.deepEqual(unexpectedConsoleErrors(consoleEvents,[]),[],'Unexpected browser/engine diagnostics');
}catch(error){failures.push(String(error));console.error('SF_M5_PERFORMANCE_FAILURE',String(error));}
finally{
  const cpu=os.cpus();
  const result={schema:'sandfall-sf-m5-performance-browser-v1',status:failures.length?'failed':'passed',failures,
    source_commit:verification.build_source_commit,verification_sha256:sha(verificationBytes),profile,workers_requested:workers,
    workers_configured:configuredWorkers,workload,bodies,speed,repetition,registered_duration_ms:durationMs,
    viewport:{width,height,dpr},url,elapsed_ms:Date.now()-started,browser,browser_metrics:metrics,startup,
    runner:{platform:os.platform(),release:os.release(),arch:os.arch(),cpu_model:cpu[0]?.model??null,
      logical_cpus:cpu.length,available_parallelism:os.availableParallelism(),memory_total_bytes:os.totalmem(),memory_free_bytes:os.freemem(),node:process.version},
    build_info:buildInfo,artifact_verification:verification,
    served_identity:served,harness_inputs:inputs,harness_checkout:{commit:harnessHead,dirty_paths:harnessDirty.split('\n').filter(Boolean)},
    summary,first,last,terminal,samples,console:consoleEvents,input:inputEvents,dom_input:domEvents,
    expected_dom:expectedDOM,control_layouts:controlLayouts,
    limits:['One actual Chromium engine/profile/host only; no cross-browser equivalence.',
      'Native latency distribution covers the scene lifetime including warmup; window scope is explicit.',
      'Frame and render distribution epochs are application lifetime, not GPU completion measurements.',
      'CDP TaskDuration is renderer main-thread work; Godot allocator and JS heap are not total process RSS.',
      'Throughput is measured, not a 60 FPS guarantee; observation and software-renderer overhead are included.']};
  mkdirSync(dirname(output),{recursive:true});writeFileSync(output,JSON.stringify(result,null,2)+'\n');
  console.log('SF_M5_PERFORMANCE_RESULT',JSON.stringify({status:result.status,output,summary,failures}));
  if(ws?.readyState===WebSocket.OPEN){try{await cmd('Browser.close',{},3000);}catch{}}
  for(const value of pending.values())value.reject(Error('Evidence complete; CDP transport closed'));pending.clear();
  if(ws&&ws.readyState!==WebSocket.CLOSED)ws.close();
  if(failures.length)process.exitCode=1;
}
