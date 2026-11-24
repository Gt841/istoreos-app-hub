local contract=assert(loadfile(arg[1]))()
local n=0
local function test(name,fn) local ok,e=pcall(fn);if not ok then error(name..': '..tostring(e)) end;n=n+1;print('ok '..n..' '..name) end
local function rejects(fn) assert(not pcall(fn),'expected rejection') end
local function clone(x) if type(x)~='table' then return x end;local r={};for k,v in pairs(x) do r[k]=clone(v) end;return r end
local hash=string.rep('a',64)
local e={id='node-24.22.1-x86_64-glibc',tool='node',version='24.22.1',build='upstream1',arch='x86_64',abi='glibc',availability='available',source='https://nodejs.org/dist/v24.22.1/SHASUMS256.txt',artifacts={{url='https://nodejs.org/dist/v24.22.1/node.tar.xz',sha256=hash,format='tar.xz',strip=1}},artifact_set=hash,npm='11.12.1',layout='standard'}
test('catalog entry',function()assert(contract.entry(e)==e)end)
test('npm variant has distinct identity',function()assert(contract.instance_id(e,nil,'glibc-2.39-r1')~=contract.instance_id(e,'10.9.2','glibc-2.39-r1'))end)
test('library revision has distinct identity',function()assert(contract.instance_id(e,nil,'glibc-2.39-r1')~=contract.instance_id(e,nil,'glibc-2.39-r2'))end)
test('artifact digest has distinct identity',function()local a=clone(e);a.artifact_set=string.rep('b',64);assert(contract.instance_id(e,nil,'g1')~=contract.instance_id(a,nil,'g1'))end)
test('no implicit GNU library',function()rejects(function()contract.instance_id(e)end)end)
test('musl cannot take GNU library',function()local a=clone(e);a.abi='musl';rejects(function()contract.instance_id(a,nil,'g1')end)end)
for _,path in ipairs({'/root/runtime','/tmp/runtime','/mnt','/mnt/a/../b','/mnt/a/./b','/mnt//a','/mnt/a/','/mnt/a\nb','/mnt/a;touch'})do test('reject path '..string.format('%q',path),function()rejects(function()contract.path(path)end)end)end
test('valid persistent path',function()assert(contract.path('/mnt/disk/Runtime')=='/mnt/disk/Runtime')end)
for _,change in ipairs({{arch='mips'},{abi='native'},{version='latest'},{version='24'},{layout='unknown'},{artifact_set='bad'},{npm='11'}})do test('reject catalog mismatch',function()local a=clone(e);for k,v in pairs(change)do a[k]=v end;rejects(function()contract.entry(a)end)end)end
test('unknown field rejected',function()local a=clone(e);a.command='echo injected';rejects(function()contract.entry(a)end)end)
test('HTTP artifact rejected',function()local a=clone(e);a.artifacts[1].url='http://nodejs.org/file';rejects(function()contract.entry(a)end)end)
test('URL userinfo rejected',function()local a=clone(e);a.artifacts[1].url='https://x@y/file';rejects(function()contract.entry(a)end)end)
test('non Node npm rejected',function()local a=clone(e);a.tool='python';a.layout='python';rejects(function()contract.entry(a)end)end)
test('Java build identity',function()local a=clone(e);a.tool='java';a.npm=nil;a.version='temurin-21.0.9+10';assert(contract.entry(a));a.version='temurin-21';rejects(function()contract.entry(a)end)end)
test('unavailable requires reason',function()local a=clone(e);a.availability='unavailable';a.artifacts=nil;rejects(function()contract.entry(a)end);a.reason='no upstream asset';assert(contract.entry(a));rejects(function()contract.instance_id(a,nil,'g1')end)end)
test('explicit source required',function()rejects(function()contract.request({op='plan',entry=e.id})end)end)
test('pip independent choice rejected',function()rejects(function()contract.request({op='plan',entry=e.id,source='origin',pip='25'})end)end)
test('global default mutation rejected',function()rejects(function()contract.request({op='set-default',id=e.id})end)end)
test('arbitrary shell rejected',function()rejects(function()contract.request({op='exec',command='sh -c whatever'})end)end)
test('boolean settings required',function()rejects(function()contract.request({op='settings',path='/mnt/a',acceleration='true'})end)end)
test('valid read request',function()assert(contract.request({op='read'}))end)
local p={schema_version=1,id='plan-1',revision=2,catalog_revision=hash,entry=e.id,instance=contract.instance_id(e,nil,'g1'),source='origin',created=100,expires=400,path='/mnt/disk/Runtime'}
test('valid bounded plan',function()assert(contract.plan(p,2,200))end)
test('stale plan',function()rejects(function()contract.plan(p,3,200)end)end)
test('expired plan',function()rejects(function()contract.plan(p,2,400)end)end)
test('future plan',function()rejects(function()contract.plan(p,2,99)end)end)
test('lifetime bounded',function()local a=clone(p);a.expires=401;rejects(function()contract.plan(a,2,200)end)end)
test('binding pins app instance',function()assert(contract.binding({schema_version=1,instance=p.instance,artifact_set=hash,receipt_sha256=hash,library='g1'}))end)
test('binding does not select global',function()rejects(function()contract.binding({schema_version=1,instance='latest',artifact_set=hash,receipt_sha256=hash,global=true})end)end)
local receipt={schema_version=1,instance=p.instance,entry=e,npm=e.npm,library='g1',artifact_set=hash,installed_at=100,verified=true,probes={version='passed',arch='passed',abi='passed',launcher='passed'},mise_key='istore-'..p.instance,root='/mnt/disk/Runtime'}
test('verified receipt',function()assert(contract.receipt(receipt))end)
test('unknown capability cannot claim verified',function()local r=clone(receipt);r.probes.launcher='unknown';rejects(function()contract.receipt(r)end)end)
test('receipt cannot alter instance',function()local r=clone(receipt);r.npm='10.9.2';rejects(function()contract.receipt(r)end)end)
test('receipt cannot alter library',function()local r=clone(receipt);r.library='g2';rejects(function()contract.receipt(r)end)end)
test('receipt cannot alter digest',function()local r=clone(receipt);r.artifact_set=string.rep('b',64);rejects(function()contract.receipt(r)end)end)
test('receipt cannot set registry alias',function()local r=clone(receipt);r.mise_key='latest';rejects(function()contract.receipt(r)end)end)
test('unverified receipt records unknown probe',function()local r=clone(receipt);r.verified=false;r.probes.launcher='unknown';assert(contract.receipt(r))end)
test('Rust registration bypasses rustup backend',function()assert(contract.registration_tool('rust')=='http:istore-rust');assert(contract.registration_tool('node')=='node')end)
print('passed='..n)
