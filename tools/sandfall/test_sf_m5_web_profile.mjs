import assert from 'node:assert/strict';
import {configureWebProfile,assertWorkerProfile,webProfile} from './sf_m5_web_profile.mjs';
const verification={status:'passed',profile:'threaded',schema:'sandfall-sf-m5-web-artifact-verification-v1'};
for(const url of ['?test=1','?test=1&workers=auto','?test=1&workers=3','?test=1&workers=2&workers=4','?test=1&fixture=1&workers=2'])
  assert.throws(()=>configureWebProfile(verification,'https://example.invalid/'+url));
configureWebProfile(verification,'https://example.invalid/?test=1&workers=2');
const state={workers:2,native:{web_profile:{profile:'threaded',configured_workers:2,resolved_workers:2,observed_workers_peak:2,
  ownership:'synchronous-godot-main; native-only-worker-pool; main-thread-rapier',capabilities:{secure_context:true,cross_origin_isolated:true,shared_array_buffer:true,worker:true,shared_wasm_memory:true}}}};
assertWorkerProfile(state,{requireObserved:true});
for(const mutate of [s=>s.workers=1,s=>s.native.web_profile.profile='compat',s=>s.native.web_profile.configured_workers=1,
  s=>s.native.web_profile.capabilities.cross_origin_isolated=false,s=>s.native.web_profile.observed_workers_peak=3]) {
  const bad=structuredClone(state);mutate(bad);assert.throws(()=>assertWorkerProfile(bad));
}
configureWebProfile(verification,'https://example.invalid/?test=1&workers=2');
const noParticipation=structuredClone(state);noParticipation.native.web_profile.observed_workers_peak=1;
assert.throws(()=>assertWorkerProfile(noParticipation,{requireObserved:true}));
configureWebProfile({status:'passed',profile:'compat'},'http://example.invalid/?test=1');
assertWorkerProfile({workers:1});assert.throws(()=>assertWorkerProfile({workers:2}));
assert.equal(webProfile.expectedWorkers,1);
console.log('SF_M5_WEB_PROFILE_NEGATIVES_PASS');
