// Negative startup contracts are helper tests, never browser/physics evidence.
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import '../web/sandfall_preflight.js';
const p=globalThis.SandfallWebPreflight;
const good={secure_context:true,cross_origin_isolated:true,shared_array_buffer:true,
  worker:true,shared_wasm_memory:true,logical_processors:8};
for(const size of [0,1,3,55,56,63,64,65,1000,1024*1024]) {
  const bytes=Uint8Array.from({length:size},(_,i)=>i%251);
  assert.equal(p.sha256Fallback(bytes.buffer),createHash('sha256').update(bytes).digest('hex'));
}
assert.equal(p.policy('compat',null,{...good,cross_origin_isolated:false,shared_array_buffer:false}).resolved_workers,1);
assert.throws(()=>p.policy('compat',null,{...good,secure_context:false}),/Sandfall Web requires HTTPS/);
for(const flag of ['secure_context','cross_origin_isolated','shared_array_buffer','worker','shared_wasm_memory'])
  assert.throws(()=>p.policy('threaded','2',{...good,[flag]:false}));
for(const value of ['0','3','8','32','-1','1.0','02','nan','']) assert.throws(()=>p.policy('threaded',value,good));
assert.throws(()=>p.policy('compat','2',good),/exactly one/);
assert.throws(()=>p.policy('threaded','4',{...good,logical_processors:2}),/exceed/);
for(const [logical,expected] of [[1,1],[2,2],[4,4],[12,6]])
  assert.equal(p.policy('threaded','auto',{...good,logical_processors:logical}).resolved_workers,expected);
const data=new TextEncoder().encode('verified actual payload');
const expected={assets:[{path:'index.pck',size:data.length,sha256:createHash('sha256').update(data).digest('hex'),mime:['application/octet-stream']}]};
function environment(bytes=data,mime='application/octet-stream',status=200) {
  return {URL,location:{href:'http://example.invalid/nested/index.html'},AbortSignal,crypto:globalThis.crypto,
    fetch:async()=>new Response(bytes,{status,headers:{'Content-Type':mime}})};
}
assert.equal((await p.verifyAssets(expected,environment())).length,1);
await assert.rejects(p.verifyAssets(expected,environment(new TextEncoder().encode('corrupt'))),/mismatch/);
await assert.rejects(p.verifyAssets(expected,environment(data,'text/html')),/MIME/);
await assert.rejects(p.verifyAssets(expected,environment(data,'application/octet-stream',404)),/Missing runtime/);
// A host that changes every second response cannot change consumed runtime
// bytes. This exercises the production binding, including copied Responses
// and the worker/worklet Blob path; it is not actual-browser evidence.
const paths=['index.js','index.pck','index.wasm','godot_rapier.wasm'];
const payloads=new Map(paths.map(path=>[path,new TextEncoder().encode('original '+path)]));
const requests=new Map();
const env={URL,URLSearchParams,Blob,Response,AbortSignal,crypto:globalThis.crypto,
  location:{href:'http://custody.invalid/nested/index.html',search:''},navigator:{hardwareConcurrency:2},
  isSecureContext:true,crossOriginIsolated:false,
  fetch:async address=>{
    const path=new URL(address).pathname.split('/').at(-1);
    requests.set(path,(requests.get(path)||0)+1);
    assert.equal(requests.get(path),1,'Runtime consumption refetched a previously verified asset');
    return new Response(payloads.get(path),{headers:{'Content-Type':path.endsWith('.js')?'text/javascript':'application/octet-stream'}});
  }};
const contract={profile:'compat',source_commit:'helper-fixture',assets:paths.map(path=>({path,
  size:payloads.get(path).length,sha256:createHash('sha256').update(payloads.get(path)).digest('hex'),
  mime:[path.endsWith('.js')?'text/javascript':'application/octet-stream']}))};
await p.run(contract,env);
for(const path of paths) {
  const first=new Uint8Array(await (await env.fetch(new URL(path,env.location.href))).arrayBuffer());
  assert.deepEqual(first,payloads.get(path));
  first.fill(0); // A consumer cannot corrupt the retained copy for another load.
  assert.deepEqual(new Uint8Array(await (await env.fetch(path)).arrayBuffer()),payloads.get(path));
  const blob=p.assetUrl(path,env);
  assert.deepEqual(new Uint8Array(await (await fetch(blob)).arrayBuffer()),payloads.get(path));
  URL.revokeObjectURL(blob);
}
assert.deepEqual([...requests.values()],[1,1,1,1]);
assert.throws(()=>p.assetUrl('unverified.js',env),/Unverified runtime/);
await assert.rejects(env.fetch('index.pck',{method:'POST'}),/GET/);
const observations=p.consumed();observations[0].sha256='modified by caller';
assert.notEqual(p.consumed()[0].sha256,'modified by caller');
console.log('SF_M5_PREFLIGHT_HELPERS_PASS (hash, host, workers, MIME, refusal, consumed-byte custody and private copies)');
