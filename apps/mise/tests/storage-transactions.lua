-- Real-device integration tests. Requires an explicitly task-owned empty root.
local share,root,fixture_path,mise_bin,ks_cli,admin=unpack(arg)
package.path=share..'/lib/?.lua;'..package.path
local sys=require('system')
local store=require('store')
local artifacts=require('artifacts')
local tasks=require('tasks')
local libraries=require('libraries')
local defaults=require('defaults')
local contract=require('contract')
local n,fs=sys.nixio,sys.fs
local count=0
local function test(name,fn)
  local ok,err=pcall(fn)
  if not ok then
    io.stderr:write('FAIL '..name..' '..(type(err)=='table' and sys.json.stringify(err)or tostring(err))..'\n');os.exit(1)
  end
  count=count+1;print('PASS '..count..' '..name);io.stdout:flush()
end
local function rejects(fn,code)
  local ok,err=pcall(fn);assert(not ok,'expected failure')
  if code then assert(type(err)=='table' and err.code==code,sys.json.stringify(err)or tostring(err))end
end
local ctx
test('unmounted path has no side effect',function()
  local p='/mnt/mise-unmounted-probe-'..n.getpid()..'/Runtime'
  rejects(function()store.open(p,true)end,'OFFLINE');assert(not fs.lstat(p:match('^(.*)/Runtime$')))
end)
test('uninitialized root cannot open implicitly',function()rejects(function()store.open(root)end,'OFFLINE')end)
test('explicit persistent storage initialization',function()ctx=store.open(root,true);assert(ctx.storage.free_bytes>2*1024^3)end)
local work=root..'/work/integration';sys.mkdir(work,448);local log=work..'/log';ctx.mise_bin=mise_bin;ctx.share=share
test('argument-preserving process execution',function()local rc,out=sys.capture({'/bin/echo','argument with spaces'},work);assert(rc==0 and out=='argument with spaces\n')end)
test('reject symlink root',function()assert(fs.symlink(root,work..'/link'));rejects(function()store.validate(work..'/link')end,'OFFLINE');fs.unlink(work..'/link')end)
test('insufficient byte budget',function()rejects(function()store.validate(root,2^60)end,'NO_SPACE')end)
test('insufficient inode budget',function()rejects(function()store.validate(root,0,2^50)end,'NO_SPACE')end)
test('state atomic write and revision',function()assert(store.state(ctx).revision==0);assert(store.bump(ctx)==1);assert(store.state(ctx).revision==1)end)
test('lock mutual exclusion and ownership',function()
  store.lock(ctx,{id='test-lock'});rejects(function()store.lock(ctx,{id='other'})end,'BUSY');rejects(function()store.unlock(ctx,'other')end,'BUSY');store.unlock(ctx,'test-lock')
end)
test('UUID mismatch refuses initialized root',function()
  local p=root..'/.storage.json';local original=assert(sys.read(p));local value=sys.decode(p);value.uuid='different-disk';sys.write(p,value)
  rejects(function()store.open(root)end,'OFFLINE');sys.write(p,original)
end)
for _,flag in ipairs({'noexec','ro'})do
  test('isolated bind mount rejects '..flag,function()
    local src=root..'/mount-source-'..flag;local dst=root..'/mount-target-'..flag;sys.mkdir(src,493);sys.mkdir(dst,493)
    assert(sys.run({'mount','--bind',src,dst})==0)
    local ok,err=pcall(function()
      assert(sys.run({'mount','-o','remount,bind,'..flag,src,dst})==0)
      rejects(function()store.validate(dst)end,'OFFLINE')
    end)
    assert(sys.run({'umount',dst})==0);if not ok then error(err)end
  end)
end
local fixture=assert(sys.decode(fixture_path));fixture.npm_integrity=nil
local archive
test('real origin artifact download and SHA256',function()
  archive=artifacts.download(ctx,fixture,'origin',work,log);assert(sys.sha(archive,work)==fixture.sha256)
end)
test('corrupt cache is refetched',function()
  sys.write(archive,'corrupt');assert(artifacts.download(ctx,fixture,'origin',work,log)==archive);assert(sys.sha(archive,work)==fixture.sha256)
end)
test('real accelerated artifact equals origin',function()
  local saved=work..'/saved-origin';assert(fs.rename(archive,saved))
  local p=artifacts.download(ctx,fixture,'ks-cli',work,log,{ks_cli=ks_cli,admin_url=admin,download_mode='accelerated'})
  assert(sys.sha(p,work)==sys.sha(saved,work))
end)
test('incorrect pin never commits cache',function()
  local wrong={};for k,v in pairs(fixture)do wrong[k]=v end;wrong.sha256=string.rep('0',64)
  rejects(function()artifacts.download(ctx,wrong,'origin',work,log)end,'INTEGRITY');assert(not fs.lstat(root..'/cache/'..wrong.sha256))
end)
test('verified archive extracts',function()
  artifacts.extract(archive,fixture,work..'/valid-package',work,log);assert(sys.read(work..'/valid-package/package.json'):find('is%-number'))
end)
test('reject corrupt archive before extraction',function()
  sys.write(work..'/invalid.tar.gz','invalid');rejects(function()artifacts.extract(work..'/invalid.tar.gz',fixture,work..'/invalid-target',work,log)end,'INTEGRITY');assert(not fs.lstat(work..'/invalid-target'))
end)
test('reject traversal listing',function()rejects(function()artifacts.check_listing('-rw-r--r-- 0/0 1 2026-01-01 00:00:00 package/../escape\n',1)end,'INTEGRITY')end)
test('reject absolute path listing',function()rejects(function()artifacts.check_listing('-rw-r--r-- 0/0 1 2026-01-01 00:00:00 /etc/shadow\n',0)end,'INTEGRITY')end)
test('reject escaping symlink listing',function()rejects(function()artifacts.check_listing('lrwxrwxrwx 0/0 0 2026-01-01 00:00:00 package/bin/link -> ../../../outside\n',1)end,'INTEGRITY')end)
test('accept internal SDK symlink',function()assert(artifacts.check_listing('lrwxrwxrwx 0/0 0 2026-01-01 00:00:00 package/bin/npm -> ../lib/npm.js\n',1)==1)end)
test('reject hardlinks and special nodes',function()
  for _,kind in ipairs({'h','b','c','p'})do rejects(function()artifacts.check_listing(kind..'rw-r--r-- 0/0 1 2026-01-01 00:00:00 package/file\n',1)end,'INTEGRITY')end
end)
local arch=n.uname().machine;local definition=libraries.definition(arch)
local library_options={ks_cli=ks_cli,admin_url=admin,download_mode='auto'}
test('private GNU library from pinned source inputs',function()
  local r=libraries.ensure(ctx,definition,'ks-cli',work,log,library_options);assert(r.verified and r.arch==arch);assert(libraries.check(ctx,r.id,work))
end)
test('wrong-architecture ELF rejected',function()
  rejects(function()libraries.elf(root..'/libraries/'..definition.id..'/ld.so',arch=='x86_64' and'aarch64'or'x86_64')end,'PROBE_FAILED')
end)
local first_manifest=sys.sha(root..'/libraries/'..definition.id..'/SHA256SUMS',work)
test('new library revision preserves old instance',function()
  local second=libraries.definition(arch,'r2');assert(libraries.ensure(ctx,second,'ks-cli',work,log,library_options).verified)
  assert(first_manifest==sys.sha(root..'/libraries/'..definition.id..'/SHA256SUMS',work))
end)
test('modified library fails verification',function()
  local p=root..'/libraries/'..definition.id..'/SOURCE.json';local original=assert(sys.read(p));sys.write(p,'changed')
  rejects(function()libraries.check(ctx,definition.id,work)end,'INTEGRITY');sys.write(p,original);assert(libraries.check(ctx,definition.id,work))
end)
local function wait(t)
  for _=1,200 do local current=tasks.get(ctx,t.id);if current.status~='running'then n.waitpid(t.owner.pid,'nohang');return current end;n.nanosleep(0,50000000)end
  error('task timed out')
end
test('task commit is durable and unlocks',function()
  local t=tasks.start(ctx,{instance='test'},function(c,task,w,l)tasks.phase(c,task,'preparing');sys.write(w..'/candidate','value');return {passed=true}end)
  local done=wait(t);assert(done.status=='success' and done.phase=='committed');assert(not fs.lstat(root..'/.lock'));assert(not fs.lstat(root..'/work/'..t.id))
end)
test('task failure retains error and old data',function()
  sys.write(root..'/old-data','preserve')
  local t=tasks.start(ctx,{},function(c,task,w,l)tasks.phase(c,task,'probe');sys.write(w..'/candidate','bad');sys.fail('PROBE_FAILED','injected probe failure')end)
  local done=wait(t);assert(done.status=='failed' and done.error.code=='PROBE_FAILED');assert(sys.read(root..'/old-data')=='preserve');assert(not fs.lstat(root..'/.lock'))
end)
local function slow(c,t,w,l)
  tasks.phase(c,t,'download')
  local rc=sys.run({'/bin/sh','-c','sleep 45 & wait'},{output=l,append=true})
  assert(rc==0)
end
test('cancel joins worker process group',function()
  local t=tasks.start(ctx,{},slow);n.nanosleep(0,200000000)
  local done=tasks.recover(ctx,t.id,true);assert(done.status=='canceled');assert(not fs.lstat(root..'/.lock'));assert(sys.read(root..'/old-data')=='preserve')
end)
test('hard interruption recovers surviving children',function()
  local t=tasks.start(ctx,{},slow);n.nanosleep(0,200000000);assert(n.kill(t.owner.pid,9));n.waitpid(t.owner.pid)
  local done=tasks.recover(ctx,t.id,false);assert(done.status=='canceled');assert(not fs.lstat(root..'/work/'..t.id));assert(not fs.lstat(root..'/.lock'))
end)
test('finished task recovery cannot replay install',function()
  local last=store.list(root..'/tasks');local id=last[#last];rejects(function()tasks.recover(ctx,id,false)end,'INVALID_INPUT')
end)
test('default resolution protects a real linked SDK',function()
  local entry=sys.decode(share..'/catalog.json').entries
  local e;for _,v in ipairs(entry)do if v.tool=='node' and v.arch==arch and v.abi=='musl'then e=v;break end end
  local instance=contract.instance_id(e);local key='istore-'..instance;local sdk=root..'/environments/'..instance
  sys.mkdir(sdk..'/bin',493);sys.write(sdk..'/bin/node','#!/bin/sh\necho protocol-fixture\n',493)
  local scope={home=work..'/default-home',data=work..'/default-data',config=work..'/default-config'}
  sys.mkdir(scope.home,448);sys.mkdir(scope.config,448);sys.write(scope.config..'/config.toml','[tools]\nnode="'..key..'"\n')
  local env={HOME=scope.home,MISE_DATA_DIR=scope.data,MISE_CONFIG_DIR=scope.config,MISE_CACHE_DIR=work..'/default-cache',MISE_HIDE_UPDATE_WARNING='1'}
  assert(sys.run({mise_bin,'link','node@'..key,sdk},{env=env,output=log,append=true,timeout=20})==0)
  ctx.default_scopes={scope};local d=defaults.read(ctx);assert(d.values.node==key)
  rejects(function()defaults.protect(ctx,{instance=instance,mise_key=key,entry=e})end,'BUSY');ctx.default_scopes=nil
end)
test('missing HOME cannot hide a global default',function()
  local scope={home=work..'/missing-default-home',data=work..'/default-data',config=work..'/default-config'}
  ctx.default_scopes={scope};local d=defaults.read(ctx);assert(d.known.node==false);assert(not fs.lstat(scope.home));ctx.default_scopes=nil
end)
test('separate UIDs cannot modify SDK or each other HOME',function()
  for _,uid in ipairs({65001,65002})do
    local home=root..'/users/'..uid..'/home';sys.mkdir(home,448)
    assert(fs.chown(root..'/users/'..uid,uid,uid));assert(fs.chmod(root..'/users/'..uid,'700'));assert(fs.chown(home,uid,uid))
  end
  local lib=root..'/libraries/'..definition.id
  for _,uid in ipairs({65001,65002})do
    local other=uid==65001 and 65002 or 65001
    local own=root..'/users/'..uid..'/home/file';local foreign=root..'/users/'..other..'/home/file'
    local code='test -r "$1/ld.so" && test ! -w "$1/ld.so" && echo own > "$2" && ! echo wrong > "$3"'
    assert(sys.run({'/bin/sh','-c',code,'probe',lib,own,foreign},{uid=uid,gid=uid,output=log,append=true})==0)
    assert(sys.read(own)=='own\n')
  end
end)
print('passed='..count)
