import {test} from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import {spawnSync} from 'node:child_process'
import {wrapScript,usageCommands} from '../src/domain/wrap.ts'
import {tools} from '../src/domain/catalog.ts'
import {runtimeId,type Runtime} from '../src/domain/runtime.ts'
import {fixture} from '../src/design/model.ts'
test('wrap rejects non-persistent/injected paths and malformed environment IDs',()=>{const r=fixture().runtimes[0];for(const p of ['/root','/tmp/a','/mnt/a/../root',"/mnt/x';touch x"]){assert.throws(()=>wrapScript(p,r))}assert.throws(()=>wrapScript('/mnt/data',{...r,id:'node;echo bad'}));assert.match(usageCommands('/mnt/data',r)[0],/node --version/)})
const extra:Runtime[]=[]
for(const arch of ['x86_64','aarch64'] as const){const java=fixture('ready',arch).runtimes.find(r=>r.language==='java')!;extra.push({...java,version:'temurin-25.0.1+8',id:runtimeId('java','temurin-25.0.1+8','glibc',arch)});const rust=fixture('ready',arch).runtimes.find(r=>r.language==='rust')!;extra.push({...rust,libc:'glibc',id:runtimeId('rust',rust.version,'glibc',arch)});if(arch==='aarch64')extra.push(...fixture('ready',arch).runtimes.filter(r=>['go','rust','zig','java'].includes(r.language)))}
for(const r of [...fixture().runtimes,...extra]){
 test(`fixed ${r.id} wrapper routes tools and persists HOME/cache without changing caller`,()=>{
  const sandbox=fs.mkdtempSync(path.join(os.tmpdir(),'mise-wrap-')),store=path.join(sandbox,'mnt/data/runtime'),runtime=path.join(store,'environments',r.id),entry=path.join(sandbox,'wrap.sh')
  try{
   fs.mkdirSync(path.join(runtime,'bin'),{recursive:true})
   const tool=tools[r.language].binary
   fs.writeFileSync(path.join(runtime,'bin',tool),'#!/usr/bin/node\nconsole.log(JSON.stringify({args:process.argv.slice(2),home:process.env.HOME,cache:process.env.MISE_CACHE_DIR,data:process.env.MISE_DATA_DIR,config:process.env.MISE_CONFIG_DIR,id:process.env.ISTORE_RUNTIME_ID,libc:process.env.npm_config_libc,prefix:process.env.npm_config_prefix,pythonPath:process.env.PYTHONPATH,userBase:process.env.PYTHONUSERBASE,goRoot:process.env.GOROOT,goPath:process.env.GOPATH,goBin:process.env.GOBIN,goCache:process.env.GOCACHE,goMod:process.env.GOMODCACHE,goTmp:process.env.GOTMPDIR,goToolchain:process.env.GOTOOLCHAIN,goEnv:process.env.GOENV,cgo:process.env.CGO_ENABLED,rustup:process.env.RUSTUP_HOME,rustToolchain:process.env.RUSTUP_TOOLCHAIN,autoInstall:process.env.RUSTUP_AUTO_INSTALL,cargoHome:process.env.CARGO_HOME,cargoTarget:process.env.CARGO_TARGET_DIR,rustc:process.env.RUSTC,tmp:process.env.TMPDIR,zigLib:process.env.ZIG_LIB_DIR,zigGlobal:process.env.ZIG_GLOBAL_CACHE_DIR,zigLocal:process.env.ZIG_LOCAL_CACHE_DIR,javaHome:process.env.JAVA_HOME,jdkHome:process.env.JDK_HOME,javaOptions:process.env.JAVA_TOOL_OPTIONS}));\n',{mode:0o755})
   if(r.language==='go')fs.copyFileSync(path.join(runtime,'bin','go'),path.join(runtime,'bin','gofmt'))
   if(r.language==='rust')for(const binary of ['cargo','rustdoc'])fs.copyFileSync(path.join(runtime,'bin','rustc'),path.join(runtime,'bin',binary))
   if(r.language==='java')for(const binary of ['javac','jar'])fs.copyFileSync(path.join(runtime,'bin','java'),path.join(runtime,'bin',binary))
   // Map the sandbox's /mnt to SSD temp storage; preserve the generated shell logic.
   fs.writeFileSync(entry,wrapScript('/mnt/data/runtime',r).replaceAll('/mnt',path.join(sandbox,'mnt')),{mode:0o755})
   const env={...process.env,HOME:'/root',PYTHONPATH:'/foreign/python',PYTHONHOME:'/foreign',ISTORE_RUNTIME_HOME:'',CGO_ENABLED:'',GOROOT:'/foreign',GOTOOLCHAIN:'auto',GOCACHE:'/foreign/cache',GOMODCACHE:'/foreign/mod',CARGO_HOME:'/foreign/cargo',CARGO_TARGET_DIR:'/foreign/target',RUSTUP_HOME:'/foreign/rustup',RUSTUP_TOOLCHAIN:'nightly',RUSTC:'/foreign/rustc',ZIG_LIB_DIR:'/foreign/lib',ZIG_GLOBAL_CACHE_DIR:'/foreign/zig',ZIG_LOCAL_CACHE_DIR:'/foreign/zig-local',JAVA_HOME:'/foreign/jdk',JAVA_TOOL_OPTIONS:'-Xmx128m'}
   const result=spawnSync('/bin/sh',[entry,tool==='python3'?'python':tool,'--version'],{env,encoding:'utf8'})
   assert.equal(result.status,0,result.stderr);const value=JSON.parse(result.stdout)
   assert.equal(value.home,process.getuid!()===0?path.join(store,'home'):path.join(store,'users',String(process.getuid!()),'home'));assert.equal(value.id,r.id);assert.equal(value.data,path.join(store,'mise',`${r.arch}-${r.libc}`));assert.ok(value.config.startsWith(store));assert.ok(value.cache.startsWith(value.home));assert.equal(env.HOME,'/root')
   if(r.language==='java'){assert.equal(value.javaHome,runtime);assert.equal(value.jdkHome,runtime);assert.ok(value.tmp.startsWith(value.home));assert.ok(value.javaOptions.startsWith('-Xmx128m '));assert.ok(value.javaOptions.includes('-Duser.home="'+value.home+'"'));assert.ok(value.javaOptions.includes('-Djava.io.tmpdir="'+value.tmp+'"'));const jar=spawnSync('/bin/sh',[entry,'jar','--create','--file','a file.jar'],{env,encoding:'utf8'});assert.equal(jar.status,0,jar.stderr);assert.deepEqual(JSON.parse(jar.stdout).args,['--create','--file','a file.jar']);const ownHome=path.join(sandbox,'mnt/application data');const own=spawnSync('/bin/sh',[entry,'java','-version'],{env:{...env,ISTORE_RUNTIME_HOME:ownHome},encoding:'utf8'});assert.equal(own.status,0,own.stderr);assert.ok(JSON.parse(own.stdout).javaOptions.includes('-Duser.home="'+ownHome+'"'));const badHome=path.join(sandbox,'mnt/invalid"home');const bad=spawnSync('/bin/sh',[entry,'java'],{env:{...env,ISTORE_RUNTIME_HOME:badHome},encoding:'utf8'});assert.notEqual(bad.status,0);assert.ok(!fs.existsSync(badHome))}else if(r.language==='rust'){assert.equal(value.rustup,path.join(store,'rustup',`${r.arch}-${r.libc}`));assert.equal(value.rustToolchain,`${r.version}-${r.arch}-unknown-linux-${r.libc==='glibc'?'gnu':'musl'}`);assert.equal(value.autoInstall,'0');assert.equal(value.rustc,path.join(runtime,'bin','rustc'));for(const key of ['cargoHome','cargoTarget','tmp'])assert.ok(value[key].startsWith(value.home),key);assert.ok(!fs.existsSync(value.rustup),'wrap must not mutate the shared toolchain inventory')}else if(r.language==='zig'){assert.equal(value.zigLib,path.join(runtime,'lib'));for(const key of ['zigGlobal','zigLocal','tmp'])assert.ok(value[key].startsWith(value.home),key);const cc=spawnSync('/bin/sh',[entry,'zig','cc','-target','aarch64-linux-musl','a file.c'],{env,encoding:'utf8'});assert.equal(cc.status,0,cc.stderr);assert.deepEqual(JSON.parse(cc.stdout).args,['cc','-target','aarch64-linux-musl','a file.c'])}else if(r.language==='go'){assert.equal(value.goRoot,runtime);assert.equal(value.goToolchain,'local');assert.equal(value.goEnv,'off');assert.equal(value.cgo,'0');for(const k of ['goPath','goBin','goCache','goMod','goTmp'])assert.ok(value[k].startsWith(value.home),k);assert.ok(value.goBin.includes(r.id));const explicit=spawnSync('/bin/sh',[entry,'go','env'],{env:{...env,CGO_ENABLED:'1'},encoding:'utf8'});assert.equal(explicit.status,0,explicit.stderr);assert.equal(JSON.parse(explicit.stdout).cgo,'1')}else if(r.language==='node')assert.equal(value.libc,r.libc);else{assert.equal(value.pythonPath,undefined);assert.equal(value.userBase,undefined)}
   const packageTool=spawnSync('/bin/sh',[entry,r.language==='java'?'javac':r.language==='rust'?'cargo':r.language==='zig'?'zig':r.language==='go'?'gofmt':r.language==='node'?'npm':'pip','--version'],{env,encoding:'utf8'});assert.equal(packageTool.status,0,packageTool.stderr);const argv=JSON.parse(packageTool.stdout).args;assert.ok(['go','rust','zig','java'].includes(r.language)?argv[0]==='--version':r.language==='node'?argv[0].endsWith('/npm-cli.js'):argv.slice(0,2).join(' ')==='-m pip')
   const shell=spawnSync('/bin/sh',[entry,'--shell','-c',`${tool} child-probe`],{env,encoding:'utf8'});assert.equal(shell.status,0,shell.stderr);assert.deepEqual(JSON.parse(shell.stdout).args,['child-probe'])
   if(r.language==='rust'||r.language==='zig'){const cwd=path.join(sandbox,'other-project');fs.mkdirSync(cwd);const other=spawnSync('/bin/sh',[entry,tool,'--version'],{cwd,env,encoding:'utf8'});assert.equal(other.status,0,other.stderr);const otherValue=JSON.parse(other.stdout);const key=r.language==='rust'?'cargoTarget':'zigLocal';assert.notEqual(otherValue[key],value[key]);assert.ok(otherValue[key].startsWith(value.home))}
   const ownHome=path.join(sandbox,'mnt/application-data');const app=spawnSync('/bin/sh',[entry,tool==='python3'?'python':tool],{env:{...env,ISTORE_RUNTIME_HOME:ownHome},encoding:'utf8'});assert.equal(app.status,0,app.stderr);assert.equal(JSON.parse(app.stdout).home,ownHome)
   const invalid=spawnSync('/bin/sh',[entry,tool==='python3'?'python':tool],{env:{...env,ISTORE_RUNTIME_HOME:'/root'},encoding:'utf8'});assert.notEqual(invalid.status,0)
  }finally{fs.rmSync(sandbox,{recursive:true,force:true})}
 })
}
test('missing runtime fails before creating the requested HOME',()=>{const sandbox=fs.mkdtempSync(path.join(os.tmpdir(),'mise-missing-'));try{const p=path.join(sandbox,'wrap.sh');fs.writeFileSync(p,wrapScript('/mnt/missing',fixture().runtimes[0]).replaceAll('/mnt',path.join(sandbox,'mnt')));const r=spawnSync('/bin/sh',[p,'node'],{encoding:'utf8'});assert.notEqual(r.status,0);assert.ok(!fs.existsSync(path.join(sandbox,'mnt')))}finally{fs.rmSync(sandbox,{recursive:true,force:true})}})

test('wrap validates complete identity and language-specific ABI',()=>{const r=fixture().runtimes.find(r=>r.language==='go')!;assert.match(usageCommands('/mnt/data',r)[0],/go version/);assert.throws(()=>wrapScript('/mnt/data',{...r,libc:'musl'}));assert.throws(()=>wrapScript('/mnt/data',{...r,version:'1.0; echo injected'}));assert.throws(()=>wrapScript('/mnt/data',{...r,id:r.id.replace('1.27.4','1.26.10')}))})

test('Rust/Zig usage commands select fixed tools instead of package managers from other languages',()=>{for(const language of ['rust','zig'] as const){const r=fixture().runtimes.find(r=>r.language===language)!;const commands=usageCommands('/mnt/data',r);assert.match(commands[0],language==='rust'?/rustc --version/:/zig version/);assert.match(commands[1],language==='rust'?/cargo --version/:/zig env/);assert.ok(commands.every(c=>!c.includes(' pip ')&&!c.includes(' npm ')))}})

test('Java wrap has four fixed commands and rejects ambiguous or injected version identities',()=>{const r=fixture().runtimes.find(r=>r.language==='java')!;const lines=usageCommands('/mnt/data',r);assert.equal(lines.length,4);assert.match(lines[0],/java -version/);assert.match(lines[1],/javac -version/);assert.match(lines[2],/jar --version/);assert.match(lines[3],/--shell/);for(const version of ['21','latest','temurin-25','zulu-25.0.1+8','temurin-25.0.1+8;id'])assert.throws(()=>wrapScript('/mnt/data',{...r,version,id:runtimeId('java',version,'glibc',r.arch)}))})

// Exercise both branches without changing the host UID or system HOME.
test('preview wrap selects administrator Runtime/home and keeps ordinary users separate',()=>{
 const sandbox=fs.mkdtempSync(path.join(os.tmpdir(),'mise-home-'))
 try{
  const r=fixture().runtimes.find(r=>r.language==='node')!,store=path.join(sandbox,'mnt/Configs/Runtime'),runtime=path.join(store,'environments',r.id),bin=path.join(sandbox,'bin'),entry=path.join(sandbox,'wrap')
  fs.mkdirSync(path.join(runtime,'bin'),{recursive:true});fs.mkdirSync(bin)
  fs.writeFileSync(path.join(runtime,'bin','node'),'#!/bin/sh\nprintf "%s\\n" "$HOME"\n',{mode:0o755})
  fs.writeFileSync(entry,wrapScript('/mnt/Configs/Runtime',r).replaceAll('/mnt',path.join(sandbox,'mnt')))
  for(const uid of [0,65001]){
   fs.writeFileSync(path.join(bin,'id'),'#!/bin/sh\nprintf "%s\\n" '+uid+'\n',{mode:0o755})
   const result=spawnSync('/bin/sh',[entry,'node'],{env:{...process.env,HOME:'/root',ISTORE_RUNTIME_HOME:'',PATH:bin+':/usr/bin:/bin'},encoding:'utf8'})
   assert.equal(result.status,0,result.stderr);assert.equal(result.stdout.trim(),uid===0?path.join(store,'home'):path.join(store,'users',String(uid),'home'))
  }
 }finally{fs.rmSync(sandbox,{recursive:true,force:true})}
})
