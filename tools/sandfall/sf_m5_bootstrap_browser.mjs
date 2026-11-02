#!/usr/bin/env node
// SF-M5 actual Chromium bootstrap/custody and worker qualification. Only passive
// browser observations and genuine UI input; no application commands or mocks.
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {mkdirSync,readFileSync,writeFileSync} from 'node:fs';
import {dirname,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {assertOrdinaryState,assertTrustedDelivery} from './sf_m2_browser_assertions.mjs';
import {sampleControlLayout,sameControlLayout,controlLayoutSettled} from './sf_m3_browser_assertions.mjs';
import {unexpectedConsoleErrors} from './sf_m4_browser_assertions.mjs';
const args=new Map();for(let i=2;i<process.argv.length;i+=2)args.set(process.argv[i],process.argv[i+1]);
const port=Number(args.get('--port')),url=args.get('--url'),output=resolve(args.get('--output'));
const expected=args.get('--expect')||'positive',caseName=args.get('--case')||'positive';
const expectedMessage=args.get('--refusal-pattern')||'';
const verificationPath=args.get('--verification'),verificationBytes=readFileSync(verificationPath),verification=JSON.parse(verificationBytes);
const width=Number(args.get('--width')||'800'),height=Number(args.get('--height')||'450'),dpr=Number(args.get('--dpr')||'1');
const minimumTicks=Number(args.get('--ticks')||'60'),timeoutMs=Number(args.get('--timeout-ms')||'240000');
const workers=args.get('--workers')||'1',profile=verification.profile,layout=verification.logical_viewport;
const workload=args.get('--workload')||'sixteen_body',speed=1;
assert.ok(['material_lab','sixteen_body'].includes(workload));
assert.equal(verification.status,'passed');assert.ok(['compat','threaded'].includes(profile));
assert.equal(verification.application_entry,'sandfall');assert.equal(verification.entry_scene,'res://sandfall_main.tscn');
assert.ok(layout&&[port,width,height,dpr,minimumTicks,timeoutMs].every(n=>Number.isFinite(n)&&n>0));
assert.ok(['positive','refused'].includes(expected));
if(expected==='refused')assert.ok(expectedMessage,'A precise expected refusal is required');
if(caseName.startsWith('compat-')){assert.equal(profile,'compat');assert.equal(workers,'1');assert.equal(expected,'positive');}
const sha=bytes=>createHash('sha256').update(bytes).digest('hex'),sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const root=fileURLToPath(new URL('../../',import.meta.url));
const harnessInputs=['sf_m5_bootstrap_browser.mjs','sf_m2_browser_assertions.mjs','sf_m3_browser_assertions.mjs','sf_m4_browser_assertions.mjs','sf_m0_geometry.mjs']
 .map(path=>({path,sha256:sha(readFileSync(new URL(path,import.meta.url)))}));
const harnessHead=execFileSync('git',['-C',root,'rev-parse','HEAD'],{encoding:'utf8'}).trim();
const harnessDirty=execFileSync('git',['-C',root,'status','--porcelain','--',...harnessInputs.map(x=>'tools/sandfall/'+x.path)],{encoding:'utf8'}).trim();
const started=Date.now(),deadline=started+timeoutMs,pending=new Map();
const consoleEvents=[],inputEvents=[],expectedDOM=[],controlLayouts=[],failures=[],checks=[],observations=[];
let ws,nextId=0,state=null,metrics=null,domEvents=[],browser=null,phase='startup',startup=null,refusal=null,consumed=[];
let terminal=null,screenshot=null,corruptionProbes=[];
function check(name,fn){fn();checks.push({name,elapsed_ms:Date.now()-started});console.log('SF_M5_BOOTSTRAP_CHECK',name);}
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
      startup:globalThis.sandfallWebStartup??null,refusal:globalThis.sandfallWebFailure??null,consumed:globalThis.SandfallWebPreflight?.consumed()??[],input:window.__sandfallObservedInput??[],
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
  metrics=value.metrics;domEvents=value.input;startup=value.startup;refusal=value.refusal;consumed=value.consumed;
  if(!value.text)return null;
  state=JSON.parse(value.text);
  assertOrdinaryState(state,{requireReady:false});
  return state;
}

async function waitFor(label,predicate,budget=90000){
  phase=label;const until=Math.min(deadline,Date.now()+budget);
  while(Date.now()<until){const value=await observe();if(refusal&&expected==='positive')throw Error('Application startup refused: '+refusal.message);if(predicate(value))return value?structuredClone(value):null;await sleep(200);}
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

try {
 let tab;const until=Date.now()+30000;
 while(Date.now()<until){
  try{tab=(await fetch(`http://127.0.0.1:${port}/json/list`,{signal:AbortSignal.timeout(2000)}).then(r=>r.json())).find(t=>t.type==='page');}catch{}
  if(tab)break;await sleep(200);
 }
 assert.ok(tab,'No isolated Chromium target');ws=new WebSocket(tab.webSocketDebuggerUrl);
 await new Promise((resolve,reject)=>{const timer=setTimeout(()=>reject(Error('CDP connection deadline expired')),10000);
  ws.addEventListener('open',()=>{clearTimeout(timer);resolve();},{once:true});ws.addEventListener('error',e=>{clearTimeout(timer);reject(e);},{once:true});});
 ws.addEventListener('message',event=>{const m=JSON.parse(event.data);
  if(m.method==='Runtime.consoleAPICalled')consoleEvents.push({type:m.params.type,text:m.params.args.map(x=>x.value??x.description??'').join(' ').slice(0,4000)});
  else if(m.method==='Runtime.exceptionThrown')consoleEvents.push({type:'exception',text:JSON.stringify(m.params.exceptionDetails)});
  const callback=pending.get(m.id);if(callback){pending.delete(m.id);m.error?callback.reject(Error(JSON.stringify(m.error))):callback.resolve(m.result);}});
 browser=await cmd('Browser.getVersion');await cmd('Page.enable');await cmd('Runtime.enable');await cmd('Page.bringToFront');
 await cmd('Emulation.setDeviceMetricsOverride',{width,height,deviceScaleFactor:dpr,mobile:false});
 await cmd('Page.addScriptToEvaluateOnNewDocument',{source:`window.__sandfallObservedInput=[];
  for(const type of ['pointerdown','pointerup','keydown','keyup'])addEventListener(type,event=>{
   window.__sandfallObservedInput.push({type,isTrusted:event.isTrusted,key:event.key??null,code:event.code??null,repeat:event.repeat??false,
    button:event.button??null,x:event.clientX??null,y:event.clientY??null,target:event.target?.tagName,targetId:event.target?.id,
    targetClass:event.target?.className,targetContentEditable:event.target?.isContentEditable===true,targetIsActive:event.target===document.activeElement,
    targetSharesCanvasParent:event.target?.parentElement===document.querySelector('canvas')?.parentElement,focused:document.hasFocus(),time_ms:performance.now()});
  },{capture:true,passive:true});`});
 await cmd('Page.navigate',{url});
 if(expected==='refused'){
  await waitFor('precise-startup-refusal',()=>Boolean(refusal),45000);
  check('expected-startup-refusal',()=>{assert.equal(refusal.status,'refused');assert.match(refusal.message,new RegExp(expectedMessage));});
  check('refusal-before-application-authority',()=>{assert.equal(state,null);assert.equal(startup,null);assert.deepEqual(consumed,[]);});
  check('real-browser-negative-conditions',()=>{
   if(caseName==='no-isolation'||caseName==='no-coop'||caseName==='no-coep')assert.equal(metrics.isolated,false);
   if(caseName==='insecure-origin')assert.equal(metrics.secure,false);
  });
  check('only-the-precise-refusal-diagnostic',()=>{
   assert.deepEqual(consoleEvents.filter(event=>['error','exception'].includes(event.type)),
    [{type:'error',text:'SF_M5_WEB_REFUSAL '+refusal.message}]);
  });
 }else{
  await waitFor('dedicated-home-ready',s=>s?.app_ready&&s.entry==='home',150000);
  check('verified-source-and-startup',()=>{
   assert.equal(state.source_commit,verification.build_source_commit);assert.equal(startup.status,'assets-and-host-verified');
   assert.equal(startup.source_commit,verification.build_source_commit);assert.equal(startup.profile,profile);
   assert.equal(startup.requested_workers,workers);
   if(workers!=='auto')assert.equal(startup.resolved_workers,Number(workers));
   assert.ok([1,2,4,6].includes(startup.resolved_workers));
   const native=verification.artifacts.find(f=>f.path===`libcybersand_native.web.${profile==='threaded'?'threads':'nothreads'}.wasm`);
   assert.equal(state.native_sha256,native.sha256);assert.equal(state.provenance.build_profile,profile);
   if(profile==='threaded'){assert.equal(metrics.secure,true);assert.equal(metrics.isolated,true);assert.equal(metrics.sharedArrayBuffer,true);assert.equal(metrics.worker,true);}
   if(caseName==='compat-no-isolation'){
    assert.equal(metrics.isolated,false);assert.equal(startup.capabilities.cross_origin_isolated,false);
   }
  });
  observations.push({phase:'home',state:structuredClone(state),metrics:structuredClone(metrics)});
  await launch();
  const configured=startup.resolved_workers,count=workload==='sixteen_body'?16:0;
  await waitFor('actual-native-rapier-work',s=>s?.tick>=minimumTicks&&s.native.web_profile.observed_workers_peak>=Math.min(2,configured),150000);
  check('actual-native-workers-and-solver-owners',()=>{
   assert.equal(state.workers,configured);assert.equal(state.native.web_profile.configured_workers,configured);
   assert.equal(state.native.web_profile.resolved_workers,configured);assert.equal(state.native.web_profile.requested_workers,workers);
   assert.ok(state.native.web_profile.observed_workers_peak>=Math.min(2,configured));
   assert.ok(state.native.web_profile.observed_workers_peak<=configured);assert.equal(state.rapier_steps,count?state.tick:0);
   assert.equal(state.native.fixed_delta,1/60);assert.equal(state.actor_count,0);assert.equal(state.render_rejections,0);
   assert.equal(state.native.body_ids.length,count);assert.equal(state.native.body_states.length,count);assert.equal(state.rendering.body_count,count);
   assert.deepEqual(state.rendering.body_ids,state.native.body_ids);assert.ok(state.moves>0);
   if(count){assert.ok(state.contacts_total>0);assert.ok(state.displaced_total>0);
    assert.ok(Object.values(state.native.object_feedback).some(x=>x.applications>0&&(Math.abs(x.accepted_impulse_x)+Math.abs(x.accepted_impulse_y)>0)));}
  });
  check('runtime-consumes-verified-bytes',()=>{
   for(const path of ['index.js','index.wasm','index.side.wasm','index.pck','godot_rapier.wasm',`libcybersand_native.web.${profile==='threaded'?'threads':'nothreads'}.wasm`]){
    const expectedHash=verification.artifacts.find(x=>x.path===path)?.sha256;
    assert.ok(consumed.some(row=>row.path===path&&row.sha256===expectedHash),'Verified consumption missing: '+path);
   }
  });
  if(caseName==='toctou'){
   const before=state.tick;
   for(const path of ['index.js','index.pck','godot_rapier.wasm',`libcybersand_native.web.${profile==='threaded'?'threads':'nothreads'}.wasm`]){
    const reply=await fetch(new URL(path,url),{signal:AbortSignal.timeout(30000)}),bytes=Buffer.from(await reply.arrayBuffer());
    const hash=sha(bytes),original=verification.artifacts.find(x=>x.path===path).sha256;
    assert.notEqual(hash,original,'Host did not actually substitute the second response');corruptionProbes.push({path,sha256:hash,expected_original_sha256:original,status:reply.status});
   }
   await waitFor('continued-physical-work-after-host-substitution',s=>s.tick>=before+10,90000);
   check('second-host-response-cannot-replace-live-runtime',()=>{assert.equal(state.rapier_steps,count?state.tick:0);assert.equal(state.mode,'run');assert.equal(state.render_rejections,0);});
  }
  await click('pause');await waitFor('paused',s=>s?.paused);const paused=structuredClone(state);
  await waitFor('stable-paused-owner',s=>s.frame>=paused.frame+3,15000);
  check('pause-preserves-native-and-rapier-counters',()=>{assert.equal(state.tick,paused.tick);assert.equal(state.rapier_steps,paused.rapier_steps);});
  check('trusted-input-and-engine-diagnostics',()=>{assertTrustedDelivery(domEvents,expectedDOM);assert.deepEqual(unexpectedConsoleErrors(consoleEvents,[]),[]);});
  terminal=structuredClone(state);observations.push({phase:'terminal',state:terminal,metrics:structuredClone(metrics)});
 }
 // Input is complete. This terminal capture is never followed by application
 // input or overlapping captures, even if the screenshot command times out.
 try{const shot=await cmd('Page.captureScreenshot',{format:'png',fromSurface:false},30000);const path=output.replace(/\.json$/,'.png');
  mkdirSync(dirname(path),{recursive:true});const bytes=Buffer.from(shot.data,'base64');writeFileSync(path,bytes);screenshot={path,sha256:sha(bytes),bytes:bytes.length};
 }catch(error){screenshot={error:String(error)};}
}catch(error){failures.push(String(error));console.error('SF_M5_BOOTSTRAP_FAILURE',String(error));}
finally{
 const result={schema:'sandfall-sf-m5-bootstrap-browser-v1',status:failures.length?'failed':'passed',case:caseName,expect:expected,
  failures,checks,source_commit:verification.build_source_commit,profile,workload,workers_requested:workers,viewport:{width,height,dpr},url,
  browser,browser_metrics:metrics,startup,refusal,consumed,corruption_probes:corruptionProbes,terminal,last_observed_state:state,observations,screenshot,
  input:inputEvents,dom_input:domEvents,expected_dom:expectedDOM,control_layouts:controlLayouts,console:consoleEvents,
  verification_sha256:sha(verificationBytes),artifact_verification:verification,harness_inputs:harnessInputs,
  harness_checkout:{commit:harnessHead,dirty_paths:harnessDirty.split('\n').filter(Boolean)},elapsed_ms:Date.now()-started,
  scope:'Actual Chromium startup/isolation/worker/source-custody and bounded production workload execution; not full M4, performance, other-browser or human acceptance'};
 mkdirSync(dirname(output),{recursive:true});writeFileSync(output,JSON.stringify(result,null,2)+'\n');
 console.log('SF_M5_BOOTSTRAP_RESULT',JSON.stringify({status:result.status,case:caseName,output,failures,checks:checks.length,
  native_ticks:terminal?.tick,configured_workers:terminal?.workers,observed_workers:terminal?.native?.web_profile?.observed_workers_peak,refusal}));
 if(ws?.readyState===WebSocket.OPEN){try{await cmd('Browser.close',{},3000);}catch{}}
 for(const p of pending.values())p.reject(Error('Evidence complete; transport closed'));pending.clear();
 if(ws&&ws.readyState!==WebSocket.CLOSED)ws.close();if(failures.length)process.exitCode=1;
}
