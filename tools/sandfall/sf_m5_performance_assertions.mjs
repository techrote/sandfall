// Read-only evidence checks. No fake counters or browser execution are supplied.
import assert from 'node:assert/strict';

const finite = (value, label) => assert.ok(typeof value === 'number' && Number.isFinite(value), `${label} is not finite`);
const count = (value, label) => assert.ok(Number.isSafeInteger(value) && value >= 0, `${label} is not a nonnegative counter`);

export function assertMetric(metric, label) {
  assert.ok(metric && typeof metric === 'object', `Missing ${label} metric`);
  for (const field of ['count','window_count','window_first_sequence','window_last_sequence']) count(metric[field], `${label}.${field}`);
  for (const field of ['total','max','last','p50','p95','window_max']) {
    finite(metric[field], `${label}.${field}`);
    assert.ok(metric[field] >= 0, `${label}.${field} is negative`);
  }
  assert.ok(metric.count >= metric.window_count && metric.window_count > 0 && metric.window_count <= 4096);
  assert.equal(metric.window_last_sequence, metric.count);
  assert.equal(metric.window_first_sequence, metric.count - metric.window_count + 1);
  assert.ok(metric.p50 <= metric.p95 && metric.p95 <= metric.window_max && metric.window_max <= metric.max,
    `${label} quantiles or lifetime maximum have inconsistent order`);
}

export function assertPerformanceState(state, { bodies, profile, configuredWorkers = null }) {
  const performance = state?.performance, host = performance?.host;
  assert.equal(performance?.schema, 'sandfall-performance-v1');
  assert.equal(host?.schema, 'sandfall-performance-v1');
  assert.equal(state.ready, true);
  assert.equal(state.mode, 'run');
  assert.equal(state.actor_count, 0);
  assert.equal(state.render_rejections, 0);
  assert.equal(state.native?.fixed_delta, 1 / 60);
  assert.equal(host.fixed_delta, 1 / 60);
  assert.equal(host.body_count, bodies);
  assert.equal(state.native?.body_ids?.length, bodies);
  assert.equal(state.rendering?.body_count, bodies);
  assert.deepEqual(state.rendering.body_ids, state.native.body_ids);
  count(state.tick, 'native tick');
  count(state.rapier_steps, 'Rapier steps');
  assert.equal(host.native_tick, state.tick);
  assert.equal(host.rapier_steps, state.rapier_steps);
  assert.equal(host.counters.native_completed ?? 0, state.tick);
  assert.equal(host.counters.rapier_completed ?? 0, state.rapier_steps);
  assert.equal(state.rapier_steps, bodies ? state.tick : 0);
  if (configuredWorkers !== null) assert.equal(state.workers, configuredWorkers);
  if (profile === 'compat') assert.equal(state.workers, 1);
  else assert.ok(Number.isSafeInteger(state.workers) && state.workers >= 1, 'Threaded worker configuration missing');
  for (const field of ['godot_memory_static_bytes','godot_memory_static_max_bytes','completed_callback_ticks'])
    count(performance[field], field);
  for (const field of ['scheduled_tick_credits','observed_usec']) finite(performance[field], field);
  assert.ok(performance.pacing && typeof performance.pacing.paused === 'boolean');
  finite(performance.pacing.tick_credit, 'pending tick credit');
  count(performance.pacing.pending_steps, 'pending Step');
  return host;
}

export function summarizeInterval(first, last, { bodies, profile, configuredWorkers = null, durationMs }) {
  assertPerformanceState(first, { bodies, profile, configuredWorkers });
  const host = assertPerformanceState(last, { bodies, profile, configuredWorkers });
  assert.equal(first.generation, last.generation, 'Measurement crossed session replacement');
  assert.equal(first.scene_id, last.scene_id, 'Measurement changed workload');
  assert.equal(first.performance.host.started_usec, host.started_usec, 'Host timing epoch changed');
  assert.equal(first.paused, false);
  assert.equal(last.paused, false, 'Rate interval contains a paused final observation');
  assert.equal(first.speed, last.speed, 'Requested speed changed during measurement');
  assert.equal(last.pristine, true);
  assert.equal(last.intervention_count, 0);
  const wallSeconds = (last.performance.observed_usec - first.performance.observed_usec) / 1e6;
  assert.ok(wallSeconds >= durationMs / 1000, 'Measured interval is shorter than registered duration');
  const nativeTicks = last.tick - first.tick, rapierSteps = last.rapier_steps - first.rapier_steps;
  assert.ok(nativeTicks > 0, 'Production native solver did not advance');
  assert.equal(rapierSteps, bodies ? nativeTicks : 0);
  const requested = 60 * first.speed;
  const renderBefore = first.performance.render.counters;
  const renderAfter = last.performance.render.counters;
  const bytes = (renderAfter.payload_bytes ?? 0) - (renderBefore.payload_bytes ?? 0);
  assert.ok(bytes >= 0, 'Render counter moved backwards');
  return {
    wall_seconds: wallSeconds, native_ticks: nativeTicks, rapier_steps: rapierSteps,
    requested_ticks_per_second: requested, achieved_ticks_per_second: nativeTicks / wallSeconds,
    requested_speed: first.speed, achieved_speed: nativeTicks / wallSeconds / 60,
    achieved_fraction_of_requested: nativeTicks / wallSeconds / requested,
    frames: last.frame - first.frame,
    frame_callbacks_per_second: (last.frame - first.frame) / wallSeconds,
    render_payload_bytes: bytes, render_payload_bytes_per_second: bytes / wallSeconds,
    scheduled_tick_credits: last.performance.scheduled_tick_credits - first.performance.scheduled_tick_credits,
    completed_callback_ticks: last.performance.completed_callback_ticks - first.performance.completed_callback_ticks,
    final_pending_steps: last.performance.pacing.pending_steps,
    final_tick_credit: last.performance.pacing.tick_credit,
    final_pending_colliders: host.pending_colliders,
    rate_scope: 'Actual native counters / application monotonic wall interval; no interpolation or skipped-work credit',
  };
}

export function assertFinalDistribution(state, { bodies }) {
  const host = state.performance.host;
  assert.equal(state.paused, true, 'Final distributions require a stable paused endpoint');
  assertMetric(host.metrics.native_tick_ms, 'native_tick_ms');
  assert.equal(host.metrics.native_tick_ms.count, state.tick,
    'Cached latency distribution has not caught up with the terminal native counter');
  assert.ok(host.metrics.native_tick_ms.max > 0, 'Actual native timing is missing');
  if (bodies) {
    assertMetric(host.metrics.rapier_step_ms, 'rapier_step_ms');
    assert.equal(host.metrics.rapier_step_ms.count, state.rapier_steps);
    assert.ok(state.contacts_total > 0, 'Sixteen-body workload has no actual material/body contact');
    assert.ok(state.native.body_body_pairs.length > 0, 'Sixteen-body workload has no actual body/body contact');
  } else assert.equal(host.metrics.rapier_step_ms, undefined, 'Zero-body workload measured nonexistent Rapier steps');
  assert.ok(host.counters.native_scheduler_jobs > 0 || state.scene_id === 'blank',
    'Material-intensive workload did not execute native jobs');
  for (const [name, metric] of Object.entries(host.metrics)) assertMetric(metric, name);
  return host.metrics;
}
