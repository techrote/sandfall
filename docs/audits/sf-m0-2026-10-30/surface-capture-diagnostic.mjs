import {spawn} from 'node:child_process';
import {openSync,writeFileSync,mkdirSync} from 'node:fs';
import {resolve} from 'node:path';
const base=resolve('evidence/cdp-dpr2-diagnostic');
const chrome=spawn(resolve('toolchains/chrome/opt/google/chrome/chrome'),['--headless=new','--no-sandbox','--disable-dev-shm-usage','--enable-unsafe-swiftshader','--use-gl=angle','--use-angle=swiftshader','--remote-debugging-port=9233',`--user-data-dir=${base}/profile`,'about:blank'],{stdio:['ignore',openSync(`${base}/chrome.log`,'w'),openSync(`${base}/chrome.log`,'a')]});
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
const results={chrome_pid:chrome.pid,cases:[],errors:[]};
let ws,nextId=0;const pending=new Map();
function cmd(method,params={},timeout=10000){return new Promise((ok,fail)=>{const id=++nextId;const timer=setTimeout(()=>{pending.delete(id);fail(Error(method+' deadline'));},timeout);pending.set(id,{ok:x=>{clearTimeout(timer);ok(x);},fail:x=>{clearTimeout(timer);fail(x);}});ws.send(JSON.stringify({id,method,params}));});}
const read=async label=>{const d=await cmd('Runtime.evaluate',{expression:'({events:window.events,dpr:devicePixelRatio,width:innerWidth,height:innerHeight,viewport:{scale:visualViewport.scale,width:visualViewport.width,height:visualViewport.height},canvas:document.querySelector("canvas").getBoundingClientRect().toJSON()})',returnByValue:true});const v={label,...d.result.value};results.cases.push(v);console.log(JSON.stringify(v));};
async function click(x=201.25,y=300){for(const type of ['mousePressed','mouseReleased'])await cmd('Input.dispatchMouseEvent',{type,button:'left',buttons:type==='mousePressed'?1:0,x,y,clickCount:1});}
try{
let tab;for(let i=0;i<100;i++){try{tab=(await fetch('http://127.0.0.1:9233/json/list',{signal:AbortSignal.timeout(1000)}).then(r=>r.json())).find(t=>t.type==='page');}catch{}if(tab)break;await sleep(100);}
if(!tab)throw Error('No diagnostic page');
ws=new WebSocket(tab.webSocketDebuggerUrl);await new Promise((ok,fail)=>{ws.addEventListener('open',ok,{once:true});ws.addEventListener('error',fail,{once:true});});ws.addEventListener('message',e=>{const m=JSON.parse(e.data),p=pending.get(m.id);if(p){pending.delete(m.id);m.error?p.fail(Error(JSON.stringify(m.error))):p.ok(m.result);}});
await cmd('Page.enable');await cmd('Runtime.enable');await cmd('Page.bringToFront');await cmd('Emulation.setDeviceMetricsOverride',{width:640,height:400,deviceScaleFactor:2,mobile:false});
const html='<html><body style="margin:0"><canvas width="1280" height="800" style="width:100vw;height:100vh;background:linear-gradient(red,blue)"></canvas><script>window.events=[]; for(const type of ["pointerdown","pointerup"])addEventListener(type,e=>events.push({type,x:e.clientX,y:e.clientY,trusted:e.isTrusted,target:e.target.tagName,time:performance.now()}),{capture:true,passive:true});</script></body></html>';
await cmd('Page.navigate',{url:'data:text/html,'+encodeURIComponent(html)});await sleep(300);
await click();await read('before-capture');
let s=await cmd('Page.captureScreenshot',{format:'png',fromSurface:true});writeFileSync(`${base}/normal.png`,Buffer.from(s.data,'base64'));
await click();await read('after-completed-capture');
for(let i=0;i<4;i++){
const capture=cmd('Page.captureScreenshot',{format:'png',fromSurface:true});
await click();await read('during-capture-'+i);
s=await capture;writeFileSync(`${base}/race-${i}.png`,Buffer.from(s.data,'base64'));
await click();await read('after-raced-capture-'+i);
}
await cmd('Browser.close');
}catch(e){results.errors.push(String(e));console.error(String(e));}finally{writeFileSync(`${base}/result.json`,JSON.stringify(results,null,2)+'\n');if(ws&&ws.readyState===WebSocket.OPEN)ws.close();chrome.kill();}
