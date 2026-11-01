#!/usr/bin/env node
// M5-A02/B01 ordinary-browser chemistry. Every mutation is one trusted CDP
// gesture; Runtime.evaluate only reads the existing application observer.
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {mkdirSync,readFileSync,writeFileSync} from 'node:fs';
import {dirname,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {mapGodotRect,cssRectToScreenshotROI} from './sf_m0_geometry.mjs';
import {pngDimensions,analyzePng} from './sf_m0_png_stats.mjs';
import {mapWorldCell} from './sf_m2_geometry.mjs';
import {assertOrdinaryState,assertEdit,assertEditMutation,assertPausedStable,
  assertHistoryLocked,assertTrustedDelivery,gestureAcknowledged} from './sf_m2_browser_assertions.mjs';
import {sampleControlLayout,sameControlLayout,controlLayoutSettled} from './sf_m3_browser_assertions.mjs';
import {configureWebProfile,assertWorkerProfile,webProfile,nativeArtifactName} from './sf_m5_web_profile.mjs';
import {CELLS,TUPLES,inspectedSample,assertExactHistory,assertChemicalFirstStep,
  assertChemicalConversion,assertChemicalReset} from './sf_m5_scientific_browser_assertions.mjs';

const args=new Map();
for(let i=2;i<process.argv.length;i+=2)args.set(process.argv[i],process.argv[i+1]);
const port=Number(args.get('--port')||'9437'),url=args.get('--url')||'http://127.0.0.1:8067/?test=1';
const output=resolve(args.get('--output')||'sf-m5-scientific-browser/browser.json');
const screenshot=resolve(args.get('--screenshot')||output.replace(/\.json$/,'.png'));
const width=Number(args.get('--width')||'800'),height=Number(args.get('--height')||'450'),dpr=Number(args.get('--dpr')||'1');
const timeoutMs=Number(args.get('--timeout-ms')||'420000');
assert.ok([port,width,height,dpr,timeoutMs].every(x=>Number.isFinite(x)&&x>0));
const verificationPath=args.get('--verification');
assert.ok(verificationPath,'A source-matched Web verifier receipt is required');
const verificationBytes=readFileSync(verificationPath),verification=JSON.parse(verificationBytes);
assert.equal(verification.status,'passed');assert.equal(verification.application_entry,'sandfall');
assert.equal(verification.entry_scene,'res://sandfall_main.tscn');
const layout=verification.logical_viewport;assert.ok(layout,'No source-derived viewport');
configureWebProfile(verification,url);
const sha=bytes=>createHash('sha256').update(bytes).digest('hex');
const copy=value=>structuredClone(value),pollDelay=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const root=fileURLToPath(new URL('../../',import.meta.url));
const inputs=['sf_m5_scientific_browser.mjs','sf_m5_scientific_browser_assertions.mjs','sf_m5_web_profile.mjs',
  'sf_m2_browser_assertions.mjs','sf_m3_browser_assertions.mjs','sf_m2_geometry.mjs','sf_m0_geometry.mjs','sf_m0_png_stats.mjs']
  .map(path=>({path,sha256:sha(readFileSync(new URL(path,import.meta.url)))}));
const harnessHead=execFileSync('git',['-C',root,'rev-parse','HEAD'],{encoding:'utf8'}).trim();
const dirty=execFileSync('git',['-C',root,'status','--porcelain','--',...inputs.map(x=>'tools/sandfall/'+x.path)],{encoding:'utf8'}).trim();
const started=Date.now(),deadline=started+timeoutMs;
const pending=new Map(),served=[],consoleEvents=[],inputEvents=[],expectedDOM=[],checks=[],checkpoints=[],observations=[],controlLayouts=[],failures=[],captures=[];
let ws,nextId=0,state=null,metrics=null,startup=null,domEvents=[],browser=null,phase='startup',captureStarted=false;

function cmd(method,params={},budget=30000){
  return new Promise((resolve,reject)=>{
    const id=++nextId,timer=setTimeout(()=>{if(pending.delete(id))reject(Error(method+' CDP deadline expired'));},budget);
    pending.set(id,{resolve:value=>{clearTimeout(timer);resolve(value);},reject:error=>{clearTimeout(timer);reject(error);}});
    try{ws.send(JSON.stringify({id,method,params}));}catch(error){pending.delete(id);clearTimeout(timer);reject(error);}
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
        documentFocused:document.hasFocus(),visibility:document.visibilityState,
        activeElement:{tag:document.activeElement?.tagName,id:document.activeElement?.id},userAgent:navigator.userAgent}};})()`,returnByValue:true});
  assert.ok(!reply.exceptionDetails,'Read-only observer failed: '+JSON.stringify(reply.exceptionDetails));
  const value=reply.result?.value;assert.ok(value,'No browser readback');
  metrics=value.metrics;startup=value.startup;domEvents=value.input;
  if(!value.text)return null;
  state=JSON.parse(value.text);
  assertOrdinaryState(state,{requireReady:false});
  if(state.ready)assertWorkerProfile(state);
  if(observations.at(-1)?.frame!==state.frame)observations.push({phase,elapsed_ms:Date.now()-started,
    frame:state.frame,generation:state.generation,mode:state.mode,tick:state.tick,rapier_steps:state.rapier_steps,
    paused:state.paused,workers:state.workers,current_hash:state.current_hash,document:state.document,
    editor:state.editor,native_revision:state.native?.native_revision,web_profile:state.native?.web_profile});
  return state;
}

async function waitFor(label,predicate,budget=30000){
  phase=label;const until=Math.min(deadline,Date.now()+budget);
  while(Date.now()<until){const value=await observe();if(value&&predicate(value))return copy(value);await pollDelay(100);}
  throw Error('Timed out waiting for '+label);
}
function check(name,callback){callback();checks.push({name,frame:state?.frame,generation:state?.generation,tick:state?.tick,status:'passed'});console.log('SF_M5_SCIENCE_BROWSER_CHECK',name);}
function checkpoint(name){const entry={name,state:copy(state),metrics:copy(metrics)};checkpoints.push(entry);return entry.state;}
async function stable(label,before){await waitFor(label,s=>s.frame>=before.frame+3);check(label,()=>assertPausedStable(before,state));return copy(state);}

async function input(method,params){
  assert.equal(captureStarted,false,'Input after terminal capture is forbidden');
  const entry={phase,elapsed_ms:Date.now()-started,method,params,acknowledged:false};inputEvents.push(entry);
  // A state-changing event is sent once. A deadline fails this execution.
  await cmd(method,params,18000);entry.acknowledged=true;
}
async function click(name){
  let first=null,confirmed=null;
  await waitFor('control-'+name+'-settled',s=>{
    const current=sampleControlLayout(s,metrics,layout,name);
    if(controlLayoutSettled(first,current)){confirmed=current;return true;}
    if(!sameControlLayout(first,current)||current.frame<first.frame)first=current;
    return false;
  },15000);
  assert.ok(controlLayoutSettled(first,confirmed));
  controlLayouts.push({name,first_frame:first.frame,confirmed_frame:confirmed.frame,geometry:confirmed.geometry,mapped:confirmed.mapped});
  const {x,y}=confirmed.mapped.center,startIndex=domEvents.length;
  await input('Input.dispatchMouseEvent',{type:'mouseMoved',x,y,buttons:0});
  await input('Input.dispatchMouseEvent',{type:'mousePressed',button:'left',buttons:1,x,y,clickCount:1});
  const pressed=state.frame;
  await waitFor('control-'+name+'-press-processed',s=>s.frame>pressed);
  await input('Input.dispatchMouseEvent',{type:'mouseReleased',button:'left',buttons:0,x,y,clickCount:1});
  await observe();
  for(const type of ['pointerdown','pointerup'])expectedDOM.push({action:name,type,button:0,x,y,start_index:startIndex,end_index:domEvents.length});
}
async function key(keyValue,code,keyCode,{modifiers=0,text,allowGodotIME=false}={}){
  await observe();const startIndex=domEvents.length,frame=state.frame;
  await input('Input.dispatchKeyEvent',{type:'keyDown',key:keyValue,code,windowsVirtualKeyCode:keyCode,nativeVirtualKeyCode:keyCode,
    modifiers,autoRepeat:false,...(text===undefined?{}:{text,unmodifiedText:text})});
  await input('Input.dispatchKeyEvent',{type:'keyUp',key:keyValue,code,windowsVirtualKeyCode:keyCode,nativeVirtualKeyCode:keyCode,modifiers,autoRepeat:false});
  await waitFor('key-'+code+'-processed',s=>s.frame>frame);
  for(const type of ['keydown','keyup'])expectedDOM.push({action:phase,type,code,repeat:false,allow_godot_ime:allowGodotIME,start_index:startIndex,end_index:domEvents.length});
}
async function field(name,text,predicate){
  await click(name);await key('a','KeyA',65,{modifiers:2,allowGodotIME:true});
  for(const ch of String(text))await key(ch,ch==='-'?'Minus':'Digit'+ch,ch==='-'?189:ch.charCodeAt(0),{text:ch,allowGodotIME:true});
  await key('Enter','Enter',13,{allowGodotIME:true});
  await waitFor('field-'+name+'-'+text,predicate);
}
async function tool(name){await click('tool_'+name);await waitFor('tool-'+name,s=>s.editor.tool===name);}
async function material(name,id){await click('material_'+name);await waitFor('material-'+name,s=>s.editor.primary.id===id);}

async function selectSteam(){
  // Source focus order before the width LineEdit: shape, secondary palette,
  // primary palette. Ordinary toolbar buttons intentionally have FOCUS_NONE.
  // The unfiltered native catalogue is ascending valid IDs; ID10 is invalid,
  // so Steam ID22 is 20 entries after the selected Wall ID1. Popup selection
  // starts at the current material; no unverified Home-key behavior is assumed.
  assert.equal(state.editor.primary.id,1,'Palette navigation requires the selected Wall control');
  await click('brush_width');
  for(let i=0;i<3;i++)await key('Tab','Tab',9,{modifiers:8,allowGodotIME:i===0});
  await key(' ','Space',32);
  for(let i=0;i<20;i++)await key('ArrowDown','ArrowDown',40);
  await key('Enter','Enter',13);
  await waitFor('Steam-selected-through-real-palette',s=>s.editor.primary.id===22);
  check('palette-default-state-is-real-native-Steam',()=>assert.deepEqual(state.editor.primary,{...TUPLES.steam,temperature:200}));
}

async function stroke(from,to,label){
  await observe();const before=copy(state),a=mapWorldCell(from,state.view,state.camera,metrics,layout),b=mapWorldCell(to,state.view,state.camera,metrics,layout);
  const startIndex=domEvents.length;
  inputEvents.push({action:label,cells:{from,to},points:{from:a.point,to:b.point},view:state.view,camera:state.camera,metrics:copy(metrics)});
  await input('Input.dispatchMouseEvent',{type:'mouseMoved',...a.point,buttons:0});
  await input('Input.dispatchMouseEvent',{type:'mousePressed',button:'left',buttons:1,...a.point,clickCount:1});
  await waitFor(label+'-real-press-preview',s=>gestureAcknowledged(s,from,from,before.frame));
  const pressed=state.frame;
  if(JSON.stringify(from)!==JSON.stringify(to)){
    await input('Input.dispatchMouseEvent',{type:'mouseMoved',...b.point,buttons:1});
    await waitFor(label+'-real-motion-preview',s=>gestureAcknowledged(s,from,to,pressed));
  }
  await input('Input.dispatchMouseEvent',{type:'mouseReleased',button:'left',buttons:0,...b.point,clickCount:1});
  await waitFor(label+'-released',s=>s.frame>pressed&&!s.editor.gesture_active);
  for(const type of ['pointerdown','mousedown'])expectedDOM.push({action:label,type,button:0,...a.point,coordinate_tolerance:1e-4,start_index:startIndex,end_index:domEvents.length});
  for(const type of ['pointerup','mouseup'])expectedDOM.push({action:label,type,button:0,...b.point,coordinate_tolerance:1e-4,start_index:startIndex,end_index:domEvents.length});
  return before;
}
async function paint(from,to,kind,count,label){
  const before=await stroke(from,to,label);
  await waitFor(label+'-committed',s=>s.document.revision>before.document.revision);
  check(label+'-one-exact-tick-zero-transaction',()=>assertEditMutation(before,state,kind,count));
  return checkpoint(label);
}
async function inspect(cell,expected){
  await tool('picker');
  // When repeating the same cell, first sample another real point so a stale
  // inspected dictionary cannot masquerade as completion of the new gesture.
  if(state.editor.inspected?.x===cell[0]&&state.editor.inspected?.y===cell[1])
    await stroke(CELLS.sentinel,CELLS.sentinel,'picker-freshness-sentinel');
  const before=await stroke(cell,cell,'inspect-'+cell.join('-'));
  await waitFor('picker-fresh-native-tuple',s=>s.frame>before.frame&&s.editor.inspected?.x===cell[0]&&s.editor.inspected?.y===cell[1]);
  check('picker-preserves-physical-state',()=>assertPausedStable(before,state));
  const sample=inspectedSample(state,cell,expected);
  checkpoints.push({name:'exact-tuple-'+cell.join('-'),sample});
  return sample;
}
async function history(direction,hash){
  const before=copy(state);await click(direction);await waitFor(direction+'-committed',s=>s.document.revision>before.document.revision);
  check(direction+'-exact-full-payload',()=>assertExactHistory(before,state,direction,hash));
}
async function zoomFixture(){
  // Four distinct accepted zoom commands make each specified cell addressable
  // by both integer legacy MouseEvents and fractional PointerEvents at DPR2.
  for(let i=0;i<4;i++){
    const before=copy(state);await click('zoom_in');await waitFor('fixture-zoom-'+i,s=>s.camera.zoom>before.camera.zoom);
    check('zoom-'+i+'-is-physical-neutral',()=>assertPausedStable(before,state));
  }
  for(const cell of [...Object.values(CELLS),[199,109],[201,111]])mapWorldCell(cell,state.view,state.camera,metrics,layout);
}
async function capture(name){
  assert.equal(captureStarted,false);captureStarted=true;
  const entry={name,state:copy(state),metrics:copy(metrics),method:'Page.captureScreenshot',from_surface:false};captures.push(entry);
  try{
    const result=await cmd('Page.captureScreenshot',{format:'png',fromSurface:false},150000),bytes=Buffer.from(result.data,'base64');
    const path=name==='terminal'?screenshot:screenshot.replace(/\.png$/,'-failure.png');mkdirSync(dirname(path),{recursive:true});writeFileSync(path,bytes);
    const dimensions=pngDimensions(bytes),mapped=mapGodotRect(state.view,metrics,layout);
    Object.assign(entry,{path,sha256:sha(bytes),bytes:bytes.length,dimensions,
      pixels:analyzePng(bytes,cssRectToScreenshotROI(mapped.css,metrics.viewport,dimensions,2)),visual_evidence_only:true});
  }catch(error){entry.error=String(error);if(name==='terminal')throw error;}
}

try{
  for(const artifact of [...verification.artifacts,{path:'SHA256SUMS',sha256:verification.manifest_sha256}]){
    const address=new URL(artifact.path,url).href,response=await fetch(address,{signal:AbortSignal.timeout(30000)});
    assert.ok(response.ok,'Served artifact unavailable: '+artifact.path);
    const bytes=Buffer.from(await response.arrayBuffer()),actual=sha(bytes);
    served.push({path:artifact.path,url:address,sha256:actual,bytes:bytes.length});
    assert.equal(actual,artifact.sha256,'Served bytes changed: '+artifact.path);
    if(artifact.size!==undefined)assert.equal(bytes.length,artifact.size);
  }
  const tabs=await fetch('http://127.0.0.1:'+port+'/json/list').then(r=>r.json()),tab=tabs.find(x=>x.type==='page');
  assert.ok(tab,'No isolated Chromium page');
  ws=new WebSocket(tab.webSocketDebuggerUrl);
  await new Promise((resolve,reject)=>{const timer=setTimeout(()=>reject(Error('CDP connect timeout')),10000);ws.addEventListener('open',()=>{clearTimeout(timer);resolve();},{once:true});ws.addEventListener('error',e=>{clearTimeout(timer);reject(e);},{once:true});});
  ws.addEventListener('message',event=>{
    const m=JSON.parse(event.data);
    if(m.method==='Runtime.consoleAPICalled')consoleEvents.push({type:m.params.type,text:(m.params.args??[]).map(x=>x.value??x.description??'').join(' ').slice(0,4000)});
    else if(m.method==='Runtime.exceptionThrown')consoleEvents.push({type:'exception',text:JSON.stringify(m.params.exceptionDetails)});
    else{const callback=pending.get(m.id);if(callback){pending.delete(m.id);m.error?callback.reject(Error(JSON.stringify(m.error))):callback.resolve(m.result);}}
  });
  browser=await cmd('Browser.getVersion');await cmd('Page.enable');await cmd('Runtime.enable');await cmd('Page.bringToFront');
  await cmd('Emulation.setDeviceMetricsOverride',{width,height,deviceScaleFactor:dpr,mobile:false});
  await cmd('Page.addScriptToEvaluateOnNewDocument',{source:`window.__sandfallObservedInput=[];
    for(const type of ['pointerdown','pointerup','mousedown','mouseup','keydown','keyup'])addEventListener(type,event=>{
      window.__sandfallObservedInput.push({type,isTrusted:event.isTrusted,key:event.key??null,code:event.code??null,repeat:event.repeat??false,
        button:event.button??null,x:event.clientX??null,y:event.clientY??null,target:event.target?.tagName,targetId:event.target?.id,
        targetClass:event.target?.className,targetContentEditable:event.target?.isContentEditable===true,
        targetIsActive:event.target===document.activeElement,targetSharesCanvasParent:event.target?.parentElement===document.querySelector('canvas')?.parentElement,
        focused:document.hasFocus(),time_ms:performance.now()});},{capture:true,passive:true});`});
  await cmd('Page.navigate',{url});
  await waitFor('dedicated-home',s=>s.app_ready&&s.entry==='home',150000);
  check('runtime-is-verified-source-and-native',()=>{
    assert.equal(state.source_commit,verification.build_source_commit);
    const native=verification.artifacts.find(a=>a.path===nativeArtifactName());assert.ok(native);assert.equal(state.native_sha256,native.sha256);
    if(webProfile.profile==='threaded')assert.equal(metrics.isolated,true);
  });
  await click('sandbox');await waitFor('blank-Edit',s=>s.ready&&s.entry==='sandbox'&&s.scene_id==='blank');
  check('blank-starts-at-tick-zero',()=>{assertEdit(state);assert.deepEqual(state.body_poses,[]);});
  const blank=checkpoint('blank');await stable('Edit-paused-no-solvers',blank);await zoomFixture();
  await field('brush_width','1',s=>s.editor.brush_size[0]===1&&s.editor.brush_size[1]===1);
  await material('wall',1);await tool('rectangle');assert.equal(state.editor.filled,true);
  const wall=await paint([199,109],[201,111],'rectangle',9,'sealed-cell-wall');
  await selectSteam();await field('temperature','1500',s=>s.editor.primary.temperature===1500);await tool('pencil');
  const steam=await paint(CELLS.steam,CELLS.steam,'pencil_stroke',1,'chemical-tuple');
  await inspect(CELLS.steam,TUPLES.steam);await history('undo',wall.current_hash);await inspect(CELLS.steam,TUPLES.wall);
  await history('redo',steam.current_hash);await inspect(CELLS.steam,TUPLES.steam);
  await material('sand',2);await field('temperature','777',s=>s.editor.primary.temperature===777);await tool('pencil');
  const authored=await paint(CELLS.hot,CELLS.hot,'pencil_stroke',1,'thermal-tuple');
  await inspect(CELLS.hot,TUPLES.hot);await history('undo',steam.current_hash);await inspect(CELLS.hot,TUPLES.empty);
  await history('redo',authored.current_hash);await inspect(CELLS.hot,TUPLES.hot);
  await stable('thermochemical-Edit-remains-exact',copy(state));
  await click('run');await waitFor('Run-real-first-advancement',s=>s.mode==='run'&&s.tick>0);
  check('first-advancement-retires-authored-history',()=>{
    assertHistoryLocked(state);assert.equal(state.initial_hash,authored.current_hash);assert.equal(state.document.cells_sha256,authored.current_hash);
    assert.equal(state.document.undo_depth,0);assert.equal(state.document.redo_depth,0);
  });
  await click('pause');await waitFor('Run-paused',s=>s.paused);
  const firstRun=checkpoint('original-Run-history-retired');await key('z','KeyZ',90,{modifiers:2});
  await waitFor('Run-Undo-refused',s=>s.last_refusal==='history_requires_edit_at_zero');await stable('Run-Undo-cannot-change-physics',firstRun);
  const beforeReset=copy(state);await click('reset');
  await waitFor('Run-reset-exact-tick-zero',s=>s.generation===beforeReset.generation+1&&s.paused&&s.tick===0&&s.mode==='run');
  check('Run-reset-restores-authored-full-hash',()=>{assert.equal(state.current_hash,authored.current_hash);assert.equal(state.rapier_steps,0);});
  await zoomFixture();
  const resetZero=checkpoint('first-step-control-tick-zero');await click('step');await waitFor('exactly-one-native-Step',s=>s.paused&&s.tick===1);
  const firstSamples={steam:await inspect(CELLS.steam,TUPLES.steamFirst),hotSource:await inspect(CELLS.hot,TUPLES.empty),hotDestination:await inspect(CELLS.fallen,TUPLES.hot)};
  check('real-first-Step-chemical-state-and-thermal-transport',()=>assertChemicalFirstStep(resetZero,state,firstSamples));
  checkpoints.push({name:'first-step-samples',samples:firstSamples,state:copy(state)});
  await click('pause');await waitFor('Steam-lifetime-executes',s=>!s.paused&&s.tick>=180,90000);
  await click('pause');await waitFor('conversion-paused',s=>s.paused&&s.tick>=180);
  const converted=await inspect(CELLS.steam,TUPLES.water);
  check('real-Steam-to-Water-product',()=>assertChemicalConversion(authored,state,converted));checkpoint('converted-Water');
  check('actual-requested-worker-profile-executed',()=>assertWorkerProfile(state,{requireObserved:true}));
  const evolved=copy(state);await click('reset_edit');
  await waitFor('Reset-Edit-fresh-authored-owner',s=>s.generation===evolved.generation+1&&s.mode==='edit'&&s.ready);
  await zoomFixture();
  const resetSamples={steam:await inspect(CELLS.steam,TUPLES.steam),hotSource:await inspect(CELLS.hot,TUPLES.hot),hotDestination:await inspect(CELLS.fallen,TUPLES.empty)};
  check('Reset-Edit-exact-initial-tuples-and-empty-history',()=>assertChemicalReset(authored,evolved,state,resetSamples));
  checkpoints.push({name:'reset-samples',samples:resetSamples,state:copy(state)});
  const terminal=checkpoint('terminal-authored-Edit');await stable('terminal-no-hidden-steps',terminal);
  check('every-mutating-input-was-trusted-and-exactly-targeted',()=>assertTrustedDelivery(domEvents,expectedDOM));
  check('no-engine-browser-errors',()=>assert.deepEqual(consoleEvents.filter(e=>['error','exception'].includes(e.type)),[]));
  await capture('terminal');await observe();check('terminal-capture-keeps-physics',()=>assertPausedStable(terminal,state));
}catch(error){failures.push(String(error));console.error('SF_M5_SCIENCE_BROWSER_FAILURE',String(error));if(ws?.readyState===WebSocket.OPEN&&!captureStarted)await capture('failure');}
finally{
  const evidence={schema:'sandfall-m5-scientific-browser-v1',status:failures.length?'failed':'passed',failures,
    observed_at:new Date().toISOString(),duration_ms:Date.now()-started,url,requested_viewport:{width,height,dpr},logical_viewport:layout,
    profile:copy(webProfile),browser_version:browser,served_identity:served,startup,
    harness_inputs:inputs,harness_checkout:{head_commit:harnessHead,identity_kind:dirty?'working-tree-harness':'committed-harness',dirty_paths:dirty.split('\n').filter(Boolean)},
    verification:{path:verificationPath,sha256:sha(verificationBytes),build_source_commit:verification.build_source_commit,source_equivalence:verification.source_equivalence},
    scope:{ordinary_browser:true,chemical_thermal_input:true,body_count:0,first_tick_history:'Original Run observes retirement after actual advancement; reset Run supplies exactly one paused native Step',
      human_exhibition_accepted:false,whole_stack_bitwise_replay:false,physics_pixels:'Terminal image is retained visual evidence; numerical physics comes from actual native readback'},
    checks,checkpoints,observations,control_layouts:controlLayouts,input_events:inputEvents,expected_dom_delivery:expectedDOM,dom_input_events:domEvents,
    final_state:state,final_metrics:metrics,console_events:consoleEvents,captures,deadlines_ms:{phase_total:timeoutMs,capture:150000,cleanup:5000}};
  mkdirSync(dirname(output),{recursive:true});writeFileSync(output,JSON.stringify(evidence,null,2)+'\n');
  console.log('SF_M5_SCIENCE_BROWSER_RESULT',JSON.stringify({status:evidence.status,failures,checks:checks.length,profile:webProfile,output}));
  process.exitCode=failures.length?1:0;
  const cleanup=setTimeout(()=>{evidence.status='failed';evidence.cleanup_timeout=true;evidence.failures.push('CDP cleanup exceeded five seconds');writeFileSync(output,JSON.stringify(evidence,null,2)+'\n');process.exit(1);},5000);cleanup.unref();
  if(ws?.readyState===WebSocket.OPEN){try{await cmd('Browser.close',{},3000);}catch{}ws.close();}
  for(const callback of pending.values())callback.reject(Error('CDP closing'));pending.clear();
}
