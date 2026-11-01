// Explicit profile contract for one isolated browser process. Older callers
// retain exactly the original compatibility/one-worker oracle by default.
import assert from 'node:assert/strict';
export let webProfile={profile:'compat',expectedWorkers:1,observedPeak:0,requireCapabilities:false};

export function configureWebProfile(verification,url) {
  assert.equal(verification.status,'passed','Web profile needs a verified artifact');
  assert.ok(['compat','threaded'].includes(verification.profile),'Unsupported verified Web profile');
  const query=new URL(url).searchParams;
  assert.equal(query.get('test'),'1','Only the read-only observer may be enabled');
  assert.equal(query.getAll('test').length,1,'Duplicate observer parameter');
  assert.ok([...query.keys()].every(key=>['test','workers'].includes(key)),'Unexpected application URL parameter');
  assert.ok(query.getAll('workers').length<=1,'Duplicate worker request');
  let expectedWorkers=1;
  if(verification.profile==='threaded') {
    assert.equal(verification.schema,'sandfall-sf-m5-web-artifact-verification-v1','Threaded acceptance needs complete M5 identity');
    assert.ok(['1','2','4','6'].includes(query.get('workers')),'Threaded regression requires an explicit supported worker control');
    expectedWorkers=Number(query.get('workers'));
  } else assert.ok(query.get('workers')===null||query.get('workers')==='1','Compatibility regression requires exactly one worker');
  webProfile={profile:verification.profile,expectedWorkers,observedPeak:0,
    requireCapabilities:verification.schema==='sandfall-sf-m5-web-artifact-verification-v1'};
  return webProfile;
}

export function assertWorkerProfile(state,{requireObserved=false}={}) {
  assert.equal(state.workers,webProfile.expectedWorkers,'Actual native worker count differs from the explicit profile control');
  if(!webProfile.requireCapabilities) return;
  const profile=state.native?.web_profile;
  assert.ok(profile,'Actual native worker/capability observation is absent');
  assert.equal(profile.profile,webProfile.profile,'Runtime silently switched Web profiles');
  assert.equal(profile.configured_workers,webProfile.expectedWorkers,'Configured native worker count mismatch');
  assert.equal(profile.resolved_workers,webProfile.expectedWorkers,'Resolved native worker request mismatch');
  assert.ok(Number.isSafeInteger(profile.observed_workers_peak)&&profile.observed_workers_peak>=0&&profile.observed_workers_peak<=webProfile.expectedWorkers,
    'Actual worker participation is invalid');
  assert.equal(profile.ownership,'synchronous-godot-main; native-only-worker-pool; main-thread-rapier');
  if(webProfile.profile==='threaded') {
    for(const key of ['secure_context','cross_origin_isolated','shared_array_buffer','worker','shared_wasm_memory'])
      assert.equal(profile.capabilities?.[key],true,'Threaded browser capability absent: '+key);
  }
  webProfile.observedPeak=Math.max(webProfile.observedPeak,profile.observed_workers_peak);
  if(requireObserved) assert.ok(webProfile.observedPeak>=(webProfile.expectedWorkers>1?2:1),'No observed native execution for requested worker profile');
}

export function nativeArtifactName() {
  return 'libcybersand_native.web.'+(webProfile.profile==='threaded'?'threads':'nothreads')+'.wasm';
}
