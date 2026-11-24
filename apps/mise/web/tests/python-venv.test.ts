import {test} from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import {spawnSync} from 'node:child_process'
import {wrapScript,pythonProjectCommands,venvPathError} from '../src/domain/wrap.ts'
import {fixture,runtimeId,type Runtime} from '../src/design/model.ts'

test('project commands validate persistent locations and quote application paths',()=>{const r=fixture().runtimes.find(r=>r.language==='python')!;const store='/mnt/data/Runtime';for(const p of ['/root/venv','/tmp/a','/mnt/a/../a','/mnt/data/Runtime','/mnt/data/Runtime/environments/a','/mnt/data/Runtime/wrap/x','/mnt/data/Runtime/mise/x','/mnt/a\nvenv']){assert.ok(venvPathError(store,p));assert.deepEqual(pythonProjectCommands(store,r,p),[])}const p="/mnt/app data/it's a venv";assert.equal(venvPathError(store,p),'');const commands=pythonProjectCommands(store,r,p);assert.equal(commands.length,4);assert.match(commands[0],/--create-venv/);assert.match(commands[1],/--venv .* pip install -r requirements.txt/);assert.ok(commands[0].includes("'\\''"))})

// Uses actual local CPython in an SSD sandbox, not mock JSON. No PyPI access,
// host Python modification, firmware or private GNU loader is involved.
test('real CPython offline venv creation, isolated pip, children, stdin, receipt rejection and rollback',{timeout:120000},()=>{
 const probe=spawnSync('/usr/bin/python3',['-c','import sys,ensurepip,venv;print(".".join(map(str,sys.version_info[:3])))'],{encoding:'utf8'})
 assert.equal(probe.status,0,probe.stderr)
 const version=probe.stdout.trim(),sandbox=fs.mkdtempSync(path.join(os.tmpdir(),'mise-real-venv-')),mount=path.join(sandbox,'mnt'),store=path.join(mount,'runtime'),sdk=path.join(store,'environments',`python-${version}-x86_64-glibc`),entry=path.join(sandbox,'wrap.sh'),target=path.join(mount,"app data/it's a venv")
 const r:Runtime={id:runtimeId('python',version,'glibc','x86_64'),language:'python',version,libc:'glibc',arch:'x86_64',npm:'',size:0,verified:true}
 const sdkEntry=path.join(sdk,'bin/python3'),calls=path.join(sandbox,'sdk-calls.log')
 const sdkScript=`#!/bin/sh\nprintf '%s\\n' call >> '${calls}'\nexec /usr/bin/python3 "$@"\n`
 try{
  fs.mkdirSync(path.dirname(sdkEntry),{recursive:true});fs.writeFileSync(sdkEntry,sdkScript,{mode:0o755})
  fs.writeFileSync(entry,wrapScript('/mnt/runtime',r).replaceAll('/mnt',mount),{mode:0o755})
  const env={...process.env,HOME:'/root',VIRTUAL_ENV:'',PYTHONPATH:'/foreign',PYTHONHOME:'/foreign',PYTHONUSERBASE:'/foreign',PIP_NO_INDEX:'1',PIP_DISABLE_PIP_VERSION_CHECK:'1',PYTHONDONTWRITEBYTECODE:'1',PIP_USER:'yes',PIP_PREFIX:'/foreign',PIP_TARGET:'/foreign'}
  const run=(args:string[],extra:Record<string,string>={},input?:string)=>spawnSync('/bin/sh',[entry,...args],{env:{...env,...extra},encoding:'utf8',input,timeout:30000})
  const create=run(['--create-venv',target]);assert.equal(create.status,0,create.stdout+create.stderr);assert.ok(fs.existsSync(path.join(target,'.istore-python-runtime.json')))
  const code='import sys,os,site,json;print(json.dumps(dict(prefix=sys.prefix,base=sys.base_prefix,exe=sys.executable,home=os.environ["HOME"],cache=os.environ["PIP_CACHE_DIR"],tmp=os.environ["TMPDIR"],user=site.ENABLE_USER_SITE)))'
  const result=run(['--venv',target,'python','-c',code]);assert.equal(result.status,0,result.stderr);const value=JSON.parse(result.stdout);assert.equal(value.prefix,target);assert.notEqual(value.base,target);assert.equal(value.exe,path.join(target,'bin/python3'));assert.equal(value.user,false);assert.ok(value.home.startsWith(store));assert.ok(value.cache.startsWith(value.home));assert.ok(value.tmp.startsWith(value.home))
  const pip=run(['--venv',target,'pip','--version']);assert.equal(pip.status,0,pip.stderr);assert.ok(pip.stdout.includes(target));assert.equal(run(['pip','install','missing-package']).status,2)
  const shared=run(['python','-m','pip','install','--no-index','missing-package']);assert.notEqual(shared.status,0);assert.match(shared.stderr,/virtualenv|virtual environment/i)
  const wheel=path.join(sandbox,'istore_isolation_probe-0.0.1-py3-none-any.whl')
  const makeWheel=spawnSync('/usr/bin/python3',['-c',`import zipfile,sys
files={
'istore_isolation_probe.py':'def main():\\n import sys;print(sys.prefix)\\n',
'istore_isolation_probe-0.0.1.dist-info/METADATA':'Metadata-Version: 2.1\\nName: istore-isolation-probe\\nVersion: 0.0.1\\n',
'istore_isolation_probe-0.0.1.dist-info/WHEEL':'Wheel-Version: 1.0\\nGenerator: istore-offline-test\\nRoot-Is-Purelib: true\\nTag: py3-none-any\\n',
'istore_isolation_probe-0.0.1.dist-info/entry_points.txt':'[console_scripts]\\nistore-isolation-probe = istore_isolation_probe:main\\n',
'istore_isolation_probe-0.0.1.dist-info/RECORD':''}
with zipfile.ZipFile(sys.argv[1],'w') as archive:
 for name,body in files.items():archive.writestr(name,body)
`,wheel],{encoding:'utf8'});assert.equal(makeWheel.status,0,makeWheel.stderr)
  const requirements=path.join(sandbox,'requirements.txt');fs.writeFileSync(requirements,wheel+'\n')
  const install=run(['--venv',target,'pip','install','--no-index','-r',requirements]);assert.equal(install.status,0,install.stderr)
  const imported=run(['--venv',target,'python','-c','import istore_isolation_probe;istore_isolation_probe.main()']);assert.equal(imported.status,0,imported.stderr);assert.equal(imported.stdout.trim(),target)
  assert.notEqual(run(['python','-c','import istore_isolation_probe']).status,0,'application packages must not enter shared Python')
  const consoleScript=run(['--venv',target,'--shell','-c','istore-isolation-probe']);assert.equal(consoleScript.status,0,consoleScript.stderr);assert.equal(consoleScript.stdout.trim(),target)
  const active=run(['pip','--version'],{VIRTUAL_ENV:target});assert.equal(active.status,0,active.stderr);assert.ok(active.stdout.includes(target))
  const shell=run(['--venv',target,'--shell','-c','python3 -c '+JSON.stringify(code)]);assert.equal(shell.status,0,shell.stderr);assert.equal(JSON.parse(shell.stdout).prefix,target)
  const stdin=run(['--venv',target,'python','-'],{},code);assert.equal(stdin.status,0,stdin.stderr);assert.equal(JSON.parse(stdin.stdout).prefix,target)
  const child=run(['--venv',target,'python','-c','import subprocess,sys;subprocess.run([sys.executable,"-c","import sys;print(sys.prefix)"],check=True)']);assert.equal(child.status,0,child.stderr);assert.equal(child.stdout.trim(),target)
  assert.ok(fs.readFileSync(calls,'utf8').split('\n').length>12,'venv children must traverse fixed SDK launcher')
  const receipt=path.join(target,'.istore-python-runtime.json'),original=fs.readFileSync(receipt,'utf8');const data=JSON.parse(original);fs.writeFileSync(receipt,JSON.stringify({...data,runtime:'other-runtime'}));const wrong=run(['--venv',target,'pip','--version']);assert.notEqual(wrong.status,0);assert.match(wrong.stderr,/另一个运行时/);fs.writeFileSync(receipt,original)
  const preserve=path.join(target,'keep');fs.writeFileSync(preserve,'keep');assert.notEqual(run(['--create-venv',target]).status,0);assert.equal(fs.readFileSync(preserve,'utf8'),'keep')
  for(const unsafe of ['/root/a',path.join(store,'environments/new'),mount+'/app/../bad'])assert.notEqual(run(['--create-venv',unsafe]).status,0)
  const foreign=path.join(mount,'unregistered');fs.mkdirSync(foreign);const bad=run(['pip','--version'],{VIRTUAL_ENV:foreign});assert.notEqual(bad.status,0);assert.match(bad.stderr,/未通过/)
  const outside=path.join(sandbox,'outside');fs.mkdirSync(outside);fs.symlinkSync(outside,path.join(mount,'outside-link'));assert.notEqual(run(['--create-venv',path.join(mount,'outside-link/new')]).status,0);assert.ok(!fs.existsSync(path.join(outside,'new')))
  const modified=path.join(target,'bin/python3');fs.appendFileSync(modified,'# changed\n');assert.notEqual(run(['--venv',target,'python','-c','print(1)']).status,0)
  // A loader wrapper that discards venv identity must fail instead of
  // launching shared Python and installing packages in the wrong prefix.
  fs.writeFileSync(sdkEntry,sdkScript.replace('exec /usr/bin/python3','unset __PYVENV_LAUNCHER__\nexec /usr/bin/python3'),{mode:0o755})
  const lostPath=path.join(mount,'lost-launcher-context');const lost=run(['--create-venv',lostPath]);assert.notEqual(lost.status,0);assert.match(lost.stderr,/未回退共享 Python/);assert.ok(!fs.existsSync(lostPath))
  // Force a pip bootstrap failure; only the fresh candidate may be cleaned.
  fs.writeFileSync(sdkEntry,sdkScript.replace('exec /usr/bin/python3',`if [ "\${2:-}" = ensurepip ]; then exit 17; fi\nexec /usr/bin/python3`),{mode:0o755})
  const failed=path.join(mount,'failed-venv');const failure=run(['--create-venv',failed]);assert.notEqual(failure.status,0);assert.ok(!fs.existsSync(failed));assert.equal(fs.readFileSync(preserve,'utf8'),'keep')
 }finally{fs.rmSync(sandbox,{recursive:true,force:true})}
})
