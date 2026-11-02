/* SF-M5 startup contract. This runs before loading the Godot engine script.
 * It validates this export's bytes and host, never claims physics acceptance.
 * The pure SHA-256 fallback preserves hashing when WebCrypto is unavailable;
 * pinned Godot 4.7 still requires a secure origin for both export profiles.
 */
(function (root) {
  'use strict';
  const K = [0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
    0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
    0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
    0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
    0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
    0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
    0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
    0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2];
  const rotate = (x,n) => (x >>> n) | (x << (32-n));
  function sha256Fallback(input) {
    const bytes = new Uint8Array(input), length = bytes.length;
    const padded = new Uint8Array(Math.ceil((length+9)/64)*64);
    padded.set(bytes); padded[length]=0x80;
    const view = new DataView(padded.buffer);
    view.setUint32(padded.length-8, Math.floor(length/0x20000000));
    view.setUint32(padded.length-4, (length*8)>>>0);
    const h=[0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19], w=new Uint32Array(64);
    for(let offset=0;offset<padded.length;offset+=64) {
      for(let i=0;i<16;i++) w[i]=view.getUint32(offset+i*4);
      for(let i=16;i<64;i++) {
        const s0=rotate(w[i-15],7)^rotate(w[i-15],18)^(w[i-15]>>>3);
        const s1=rotate(w[i-2],17)^rotate(w[i-2],19)^(w[i-2]>>>10);
        w[i]=(w[i-16]+s0+w[i-7]+s1)>>>0;
      }
      let [a,b,c,d,e,f,g,j]=h;
      for(let i=0;i<64;i++) {
        const t1=(j+(rotate(e,6)^rotate(e,11)^rotate(e,25))+((e&f)^(~e&g))+K[i]+w[i])>>>0;
        const t2=((rotate(a,2)^rotate(a,13)^rotate(a,22))+((a&b)^(a&c)^(b&c)))>>>0;
        j=g;g=f;f=e;e=(d+t1)>>>0;d=c;c=b;b=a;a=(t1+t2)>>>0;
      }
      [a,b,c,d,e,f,g,j].forEach((v,i)=>h[i]=(h[i]+v)>>>0);
    }
    return h.map(v=>v.toString(16).padStart(8,'0')).join('');
  }
  async function digest(bytes, crypto=root.crypto) {
    if (!crypto?.subtle) return sha256Fallback(bytes);
    return [...new Uint8Array(await crypto.subtle.digest('SHA-256',bytes))].map(v=>v.toString(16).padStart(2,'0')).join('');
  }
  function policy(profile, requested, capabilities) {
    if (!['compat','threaded'].includes(profile)) throw Error('Unknown Web export profile');
    const logical=Math.max(1,Number(capabilities.logical_processors)||1);
    if (!capabilities.secure_context) throw Error('Sandfall Web requires HTTPS or a loopback secure origin (Godot 4.7)');
    if (profile==='threaded') {
      if (!capabilities.cross_origin_isolated) throw Error('Threaded Web requires COOP same-origin and COEP require-corp');
      if (!capabilities.shared_array_buffer || !capabilities.worker || !capabilities.shared_wasm_memory)
        throw Error('Threaded Web requires Worker, SharedArrayBuffer and shared WebAssembly memory');
    }
    let resolved=profile==='compat'?1:(logical<2?1:logical<4?2:logical<12?4:6);
    if (requested!==null && requested!=='auto') {
      if (!/^(1|2|4|6)$/.test(requested)) throw Error('Supported native worker requests: auto, 1, 2, 4, 6');
      resolved=Number(requested);
      if (profile==='compat' && resolved!==1) throw Error('Compatibility Web supports exactly one native worker');
      if (profile==='threaded' && resolved>logical) throw Error('Requested native workers exceed reported logical processors');
    }
    return {profile,requested_workers:requested??'auto',resolved_workers:resolved,capabilities};
  }
  function capabilities(env=root) {
    let shared=false;
    try { shared = typeof env.SharedArrayBuffer==='function' &&
      new env.WebAssembly.Memory({initial:1,maximum:1,shared:true}).buffer instanceof env.SharedArrayBuffer; } catch (_) {}
    return {secure_context:env.isSecureContext===true,cross_origin_isolated:env.crossOriginIsolated===true,
      shared_array_buffer:typeof env.SharedArrayBuffer==='function',worker:typeof env.Worker==='function',
      shared_wasm_memory:shared,logical_processors:env.navigator.hardwareConcurrency||1};
  }
  async function workerProbe(env=root) {
    const url=env.URL.createObjectURL(new env.Blob(['postMessage("sandfall-worker-ready")'],{type:'text/javascript'}));
    let worker;
    try {
      await new Promise((resolve,reject)=>{
        const timer=env.setTimeout(()=>reject(Error('Worker startup did not complete')),10000);
        try {
          worker=new env.Worker(url);
          worker.onmessage=e=>{env.clearTimeout(timer);e.data==='sandfall-worker-ready'?resolve():reject(Error('Unexpected Worker probe reply'));};
          worker.onerror=()=>{env.clearTimeout(timer);reject(Error('Worker startup refused by browser or host policy'));};
        } catch(error) {env.clearTimeout(timer);reject(error);}
      });
    } finally {worker?.terminate();env.URL.revokeObjectURL(url);}
  }
  const verifiedBytes=new Map(), blobUrls=new Map(), consumed=[];
  async function verifyAssets(expected,env=root) {
    const verified=[];
    for(const asset of expected.assets) {
      if (!/^[A-Za-z0-9_.-]+$/.test(asset.path)) throw Error('Invalid exported resource path');
      const url=new env.URL(asset.path,env.location.href);
      const response=await env.fetch(url,{cache:'no-store',redirect:'error',signal:env.AbortSignal.timeout(30000)});
      if(!response.ok) throw Error('Missing runtime asset: '+asset.path+' (HTTP '+response.status+')');
      const mime=(response.headers.get('content-type')||'').split(';')[0].trim().toLowerCase();
      if(asset.mime && !asset.mime.includes(mime)) throw Error('Incorrect MIME for '+asset.path+': '+mime);
      const bytes=await response.arrayBuffer();
      if(bytes.byteLength!==asset.size || await digest(bytes,env.crypto)!==asset.sha256)
        throw Error('Runtime SHA-256/size mismatch: '+asset.path);
      verifiedBytes.set(url.href,{bytes,mime,asset});
      verified.push({path:asset.path,sha256:asset.sha256,size:bytes.byteLength,mime});
    }
    return verified;
  }
  function assetUrl(path,env=root) {
    const key=new env.URL(path,env.location.href).href;
    const entry=verifiedBytes.get(key);
    if(!entry) throw Error('Unverified runtime URL: '+path);
    if(!blobUrls.has(key)) blobUrls.set(key,env.URL.createObjectURL(new env.Blob([entry.bytes],{type:entry.mime})));
    consumed.push({path:entry.asset.path,sha256:entry.asset.sha256,via:'verified-blob'});
    return blobUrls.get(key);
  }
  function bindConsumedBytes(env=root) {
    const original=env.fetch.bind(env);
    env.fetch=async (request,options)=>{
      const address=new env.URL(typeof request==='string'||request instanceof env.URL?request:request.url,env.location.href).href;
      const entry=verifiedBytes.get(address);
      if(!entry) return original(request,options);
      if(options?.method && options.method!=='GET') throw Error('Runtime fetch must use GET');
      consumed.push({path:entry.asset.path,sha256:entry.asset.sha256,via:'verified-buffer'});
      return new env.Response(entry.bytes.slice(0),{status:200,headers:{'Content-Type':entry.mime,'Content-Length':String(entry.bytes.byteLength)}});
    };
  }
  function bindEngine(engine,env=root) {
    const original=engine.config.getModuleConfig.bind(engine.config);
    engine.config.getModuleConfig=(...args)=>{
      const config=original(...args), locate=config.locateFile;
      // Worklet fetches and pthread script loads do not call window.fetch.
      // The engine script and worklets therefore use verified immutable blobs.
      config.mainScriptUrlOrBlob=assetUrl('index.js',env);
      config.locateFile=path=>{const result=locate(path);return result.endsWith('.js')?assetUrl(result,env):result;};
      return config;
    };
  }
  async function run(expected,env=root) {
    const query=new env.URLSearchParams(env.location.search);
    if(query.getAll('workers').length>1) throw Error('Duplicate native worker request');
    const receipt=policy(expected.profile,query.get('workers'),capabilities(env));
    if(receipt.profile==='threaded') await workerProbe(env);
    receipt.assets=await verifyAssets(expected,env);
    bindConsumedBytes(env);
    receipt.source_commit=expected.source_commit; receipt.status='assets-and-host-verified';
    env.sandfallWebStartup=Object.freeze(receipt);
    return receipt;
  }
  root.SandfallWebPreflight=Object.freeze({run,policy,capabilities,digest,sha256Fallback,verifyAssets,
    assetUrl,bindEngine,consumed:()=>consumed.map(value=>({...value}))});
})(globalThis);
