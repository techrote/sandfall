#!/usr/bin/env python3
"""Retain original Actions payloads, failing closed on source/digest/name drift."""
import base64,gzip,hashlib,io,json,os,pathlib,stat,subprocess,urllib.request,urllib.parse,zipfile
BASE='533a3de6352074f0cd68faca94417e80f041080e'
API='https://api.github.com/repos/techrote/sandfall'
TOKEN=os.environ['GH_TOKEN']
ROOT=pathlib.Path('prepared-source')
PREFIX=pathlib.Path('docs/audits/sf-m2-2026-10-31/qualification-533a3de6')
OUT=ROOT/PREFIX

class SafeRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        assert urllib.parse.urlparse(newurl).scheme == 'https'
        out=super().redirect_request(req, fp, code, msg, headers, newurl)
        if urllib.parse.urlparse(req.full_url).netloc != urllib.parse.urlparse(newurl).netloc:
            out.remove_header('Authorization')
        return out

OPENER=urllib.request.build_opener(SafeRedirect())

def api(suffix):
    request=urllib.request.Request(API+suffix,headers={'Authorization':'Bearer '+TOKEN,'Accept':'application/vnd.github+json'})
    with OPENER.open(request,timeout=60) as response:return response.read()

def digest(value):return hashlib.sha256(value).hexdigest()

def write_json(path,value):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(value,indent=2,sort_keys=True)+'\n')

run=json.loads(api('/actions/runs/41163426571'))
assert run['head_sha']==BASE and run['status']=='completed' and run['conclusion']=='success'
jobs=json.loads(api('/actions/runs/41163426571/jobs?per_page=100'))
assert len(jobs['jobs'])==7 and all(j['head_sha']==BASE and j['conclusion']=='success' for j in jobs['jobs'])
raw=gzip.decompress(base64.b64decode(pathlib.Path('sf-m2-closure-packet.b64').read_text()))
assert digest(raw)=='0809d42698cac1a57437e46c29b8e7a147909fc92f018df058508eb03e9e5a4a'
packet=json.loads(raw)
assert packet['base']==BASE
allowed={'README.md','docs/SF-M2-AUTHORING-HISTORY.md','docs/SANDFALL-V1-ARCHITECTURE-IMPLEMENTATION.md','docs/audits/2026-10-31-sf-m2-authoring-history.md',str(PREFIX/'independent-recomputation.json')}
assert set(packet['files'])==allowed
subprocess.run(['git','worktree','add','--detach',str(ROOT),BASE],check=True)
pathlib.Path('reviewed-docs.patch').write_text(packet['patch'])
subprocess.run(['git','-C',str(ROOT),'apply','--index','../reviewed-docs.patch'],check=True)
for path,sha in packet['files'].items():assert digest((ROOT/path).read_bytes())==sha,path
OUT.mkdir(parents=True,exist_ok=True)
write_json(OUT/'full-source-run.json',run);write_json(OUT/'full-source-jobs.json',jobs)
# Published API digest and exact original workflow SHA authenticate each zip.
fixed=[
 (13026546788,'original-800-fail','1e2a5c045083bbc22fbd006286f08ccaeb8822ba4be8c0e7c9a1bcf14319a664',41158379128,'3a008a55d62958d74b33889d90088e0d2898321a'),
 (13026681081,'original-640-fail','bfd890f0983154aaecea6038f84208c95ee3ce87292203322e1230655b02d9e8',41158379128,'3a008a55d62958d74b33889d90088e0d2898321a'),
 (13027812297,'repair1-800-fail','e9ab27addd6ce4be0b1e767ddb8825bc0fc6fe88455929dd6776be82e1cc6017',41162500529,'51a4ea598bb5b4e62cfd0ef2814374af23f9d903'),
 (13027917238,'repair1-640-fail','a3d08e4eb4d0700446b8bc18ddcbe0d6544fd42c6152fc179f35cc95712550f9',41162500529,'51a4ea598bb5b4e62cfd0ef2814374af23f9d903'),
 (13027163779,'verified-reuse-800-pass','83bd5771b8b3bda4beb6dd9eb8c4e113f6cfe3e44f7d1779cb1c90abfa43bd06',41162933990,'5dd4939907b4b78bcff7dab0880a8ed32a60da4c'),
 (13028231557,'verified-reuse-640-pass','e20af3fff24dfcb7a2341dedd5622ee5f2224d1fdd32d725e62ba810c2f7dc58',41162933990,'5dd4939907b4b78bcff7dab0880a8ed32a60da4c'),
]
listing=json.loads(api('/actions/runs/41163426571/artifacts?per_page=100'))
write_json(OUT/'full-source-artifacts.json',listing)
names={'sandfall-sf-m2-source-native','sandfall-sf-m2-build-evidence','sandfall-sf-m2-legacy-600-contract',*[f'sandfall-sf-m2-{h}-{w}x{ht}-dpr{d}' for h in ('sf_m1_browser','sf_m2_browser') for w,ht,d in ((800,450,1),(640,400,2))]}
selected=[a for a in listing['artifacts'] if a['name'] in names]
assert {a['name'] for a in selected}==names
for a in selected:fixed.append((a['id'],'full-'+a['name'],a['digest'].removeprefix('sha256:'),41163426571,BASE))
manifest={'schema':'sandfall-sf-m2-evidence-custody-v1','qualified_source':BASE,'qualified_run':41163426571,'scope':'Original mixed-cohort evidence; verify each embedded build/harness identity, not just publishing workflow head. Gzip is lossless storage, not a new execution. No threaded or human visual claim.','artifacts':[],'payloads':[]}
for aid,label,sha,rid,workflowsha in fixed:
    info=json.loads(api(f'/actions/artifacts/{aid}'))
    assert info['digest']=='sha256:'+sha and not info['expired']
    assert info['workflow_run']['id']==rid and info['workflow_run']['head_sha']==workflowsha
    data=api(f'/actions/artifacts/{aid}/zip')
    assert digest(data)==sha and len(data)==info['size_in_bytes'],aid
    manifest['artifacts'].append({'label':label,'id':aid,'run_id':rid,'workflow_head':workflowsha,'zip_sha256':sha,'zip_bytes':len(data),'metadata':info})
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        seen=set();total=0
        for item in archive.infolist():
            if item.is_dir():continue
            path=pathlib.PurePosixPath(item.filename)
            assert not path.is_absolute() and '..' not in path.parts and '\\' not in item.filename
            assert item.filename.casefold() not in seen and not stat.S_ISLNK(item.external_attr>>16)
            seen.add(item.filename.casefold());total+=item.file_size
            assert item.file_size<32*1024*1024 and total<96*1024*1024
            # Retain only original evidence, never execute downloaded scripts.
            assert path.suffix.lower() in {'.json','.log','.txt','.png'},path
            original=archive.read(item)
            assert len(original)==item.file_size
            stored=gzip.compress(original,mtime=0) if path.suffix!='.png' else original
            relative=pathlib.Path(label)/pathlib.Path(*path.parts)
            if stored is not original:relative=pathlib.Path(str(relative)+'.gz')
            target=OUT/relative;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(stored)
            manifest['payloads'].append({'artifact_id':aid,'artifact_member':item.filename,'stored_path':relative.as_posix(),'storage':'gzip' if stored is not original else 'original','original_sha256':digest(original),'original_bytes':len(original),'stored_sha256':digest(stored),'stored_bytes':len(stored)})
write_json(OUT/'manifest.json',manifest)
(OUT/'README.md').write_text('''# SF-M2 source-qualified evidence custody\n\nQualified source: `533a3de6352074f0cd68faca94417e80f041080e`.\n\n`manifest.json` binds every original artifact/run/head and original payload byte to its retained file. Original text payloads use deterministic gzip, preserving native trailing whitespace; decompression must match the original digest. PNGs are byte-preserved. Original and intermediate failures remain failures. The two verified-reuse cohorts execute harness 533a3de6 against build 3a008a55; the full-source cohort freshly builds and executes 533a3de6. Transport workflow heads do not replace embedded source identities.\n\nThe full-source API receipts and artifact inventory are retained separately. Runnable dedicated/legacy exports are not vendored here; their exact GitHub artifact IDs, original ZIP digests and expiry are in `full-source-artifacts.json`. After expiry, build and qualify a new source-matched export.\n\nThe legacy600 receipt is functional evidence and must not turn a missing screenshot into visual acceptance. The dedicated ordinary lanes provide original PNGs. Broad desktop/threaded/unisolated-hosting and owner human visual acceptance remain separate. Historical 164-test native results are not newly executed full SF-M2 tests.\n\n`independent-recomputation.json` is a derived local verification of the earlier passing reused-artifact cohort, not a fabricated original runner receipt.\n''')
# Reverify every retained payload after writing, including lossless encoding.
for p in manifest['payloads']:
    data=(OUT/p['stored_path']).read_bytes();assert digest(data)==p['stored_sha256']
    raw=gzip.decompress(data) if p['storage']=='gzip' else data
    assert digest(raw)==p['original_sha256'] and len(raw)==p['original_bytes']
subprocess.run(['git','-C',str(ROOT),'add','--',str(PREFIX)],check=True)
paths=subprocess.check_output(['git','-C',str(ROOT),'diff','--cached','--name-only'],text=True).splitlines()
assert all(p in allowed or p.startswith(str(PREFIX)+'/') for p in paths)
subprocess.run(['git','-C',str(ROOT),'diff','--cached','--check'],check=True)
print(json.dumps({'artifacts':len(manifest['artifacts']),'payloads':len(manifest['payloads']),'changed_files':len(paths),'retained_bytes':sum(p['stored_bytes'] for p in manifest['payloads'])}))
