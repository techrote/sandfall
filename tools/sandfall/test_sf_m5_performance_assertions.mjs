// Synthetic evidence negatives qualify the validator only, never the runtime.
import assert from 'node:assert/strict';
import {assertMetric,assertPerformanceState,summarizeInterval,assertFinalDistribution} from './sf_m5_performance_assertions.mjs';

const metric={count:60,total:60,max:2,last:1,window_count:60,window_first_sequence:1,window_last_sequence:60,p50:1,p95:2,window_max:2};
const make=()=>({ready:true,mode:'run',paused:false,actor_count:0,render_rejections:0,tick:60,rapier_steps:0,
  workers:1,frame:70,generation:1,scene_id:'blank',speed:1,pristine:true,intervention_count:0,
  native:{fixed_delta:1/60,body_ids:[]},rendering:{body_count:0,body_ids:[]},
  performance:{schema:'sandfall-performance-v1',observed_usec:1000000,scheduled_tick_credits:60,completed_callback_ticks:60,
    godot_memory_static_bytes:100,godot_memory_static_max_bytes:200,pacing:{paused:false,tick_credit:0,pending_steps:0},
    render:{counters:{payload_bytes:200}},host:{schema:'sandfall-performance-v1',body_count:0,native_tick:60,rapier_steps:0,
      fixed_delta:1/60,started_usec:100,counters:{native_completed:60},metrics:{native_tick_ms:structuredClone(metric)},pending_colliders:0}}});
const options={bodies:0,profile:'compat',configuredWorkers:1};
assertMetric(metric,'fixture');assertPerformanceState(make(),options);
for(const mutate of [m=>m.p95=NaN,m=>m.window_count=4097,m=>m.p50=3,m=>m.window_first_sequence=0,m=>m.max=0]){
  const value=structuredClone(metric);mutate(value);assert.throws(()=>assertMetric(value,'negative'));
}
for(const mutate of [s=>s.tick=61,s=>s.rapier_steps=1,s=>s.workers=2,s=>s.actor_count=1,s=>s.native.fixed_delta=1/30,
  s=>s.performance.host.counters.native_completed=59,s=>s.rendering.body_count=1,s=>s.performance.godot_memory_static_bytes=NaN]){
  const state=make();mutate(state);assert.throws(()=>assertPerformanceState(state,options));
}
const first=make(),last=make();last.tick=120;last.performance.host.native_tick=120;last.performance.host.counters.native_completed=120;
last.performance.observed_usec=6000000;last.performance.completed_callback_ticks=120;last.performance.scheduled_tick_credits=360;last.frame=100;
const summary=summarizeInterval(first,last,{...options,durationMs:5000});
assert.equal(summary.achieved_ticks_per_second,12);assert.equal(summary.achieved_fraction_of_requested,0.2);
assert.equal(summary.scheduled_tick_credits,300);assert.equal(summary.completed_callback_ticks,60);
for(const mutate of [s=>s.generation=2,s=>s.paused=true,s=>s.speed=4,s=>s.performance.host.started_usec=101]){
  const value=structuredClone(last);mutate(value);assert.throws(()=>summarizeInterval(first,value,{...options,durationMs:5000}));
}
const terminal=make();terminal.paused=true;assertFinalDistribution(terminal,{bodies:0});
terminal.performance.host.metrics.native_tick_ms.count=59;
assert.throws(()=>assertFinalDistribution(terminal,{bodies:0}),'Stale latency cache cannot qualify final measurement');
console.log('SF_M5_PERFORMANCE_ASSERTION_NEGATIVES_PASSED');
