local share,root,mise,ks,base=unpack(arg)
package.path=share..'/lib/?.lua;'..package.path
local sys=require('system');local store=require('store');local n,fs=sys.nixio,sys.fs
local ctx=store.open(root);local work=root..'/work/node-runtime-tests';sys.mkdir(work,448)
local count=0
local function test(name,fn)
  local ok,err=pcall(fn)
  if not ok then io.stderr:write('FAIL '..name..' '..(type(err)=='table'and sys.json.stringify(err)or tostring(err))..'\n');os.exit(1)end
  count=count+1;print('PASS '..count..' '..name);io.stdout:flush()
end
local function run(r,command,args,options)
  options=options or{};local argv={root..'/wrap/'..r.instance,command}
  for _,a in ipairs(args or{})do argv[#argv+1]=a end
  local env={HOME='/root',PATH='/not-a-runtime',NODE_OPTIONS='--require=/not-a-module',NODE_PATH='/not-a-module',
    XDG_STATE_HOME='/root/wrong',MISE_STATE_DIR='/root/wrong',MISE_NODE_VERSION='0.0.0',NPM_CONFIG_PREFIX='/root/wrong',NPM_CONFIG_CACHE='/root/wrong',
    ISTORE_RUNTIME_ACCELERATION=options.policy or'origin',ISTORE_RUNTIME_KS_CLI=ks}
  for k,v in pairs(options.env or{})do env[k]=v end
  local output=options.output or(work..'/out')
  local rc=sys.run(argv,{env=env,uid=options.uid,gid=options.uid,output=output,stdin=options.stdin,timeout=options.timeout or 90,cwd=options.cwd})
  return rc,sys.read(output)or''
end
local receipts={}
for _,id in ipairs(store.list(root..'/environments'))do
  local r=sys.decode(root..'/environments/'..id..'/receipt.json')
  if r and r.verified and r.entry.tool=='node'and fs.access(root..'/wrap/'..id,'x')then receipts[#receipts+1]=r end
end
test('two Node versions and both ABIs plus independent npm coexist',function()
  local versions,abis,npms={},{},{}
  for _,r in ipairs(receipts)do versions[r.entry.version]=true;abis[r.entry.abi]=true;npms[r.npm]=true end
  assert(#receipts==5 and versions['24.21.0']and versions['24.22.1']and abis.glibc and abis.musl and npms['11.12.1'])
end)
local first
for _,r in ipairs(receipts)do
  if r.entry.abi=='glibc'and r.entry.version=='24.21.0'and r.npm~='11.12.1'then first=r end
  test(r.entry.id..' fixed node with conflicting HOME PATH and Node options',function()
    local rc,out=run(r,'node',{'-e','console.log(JSON.stringify({version:process.version,home:process.env.HOME,prefix:process.env.npm_config_prefix,tmp:process.env.TMPDIR,state:process.env.XDG_STATE_HOME,miseState:process.env.MISE_STATE_DIR,glibc:process.report.getReport().header.glibcVersionRuntime||null}))'})
    assert(rc==0,out);local v=sys.json.parse(out);assert(v.version=='v'..r.entry.version and v.home==root..'/users/0/home')
    assert(v.prefix==v.home..'/.local/npm/'..r.instance and v.tmp:sub(1,#v.home)==v.home)
    assert(v.state==v.home..'/.local/state'and v.miseState==v.home..'/.local/state/mise')
    assert((r.entry.abi=='glibc')==(v.glibc~=nil))
  end)
  test(r.entry.id..' actual matching npm',function()local rc,out=run(r,'npm',{'--version'});assert(rc==0 and out:gsub('%s+$','')==r.npm,out)end)
  test(r.entry.id..' literal arguments and stdin',function()
    sys.write(work..'/stdin','stdin with spaces\n')
    local rc,out=run(r,'node',{'-e','console.log(JSON.stringify({args:process.argv.slice(1),input:require("fs").readFileSync(0,"utf8")}))','--','argument with spaces',"quote'and\"double",'$(literal)'},{stdin=work..'/stdin'})
    assert(rc==0,out);local v=sys.json.parse(out);assert(v.args[1]=='argument with spaces'and v.args[2]=="quote'and\"double"and v.args[3]=='$(literal)'and v.input=='stdin with spaces\n')
  end)
  test(r.entry.id..' execFile and fork retain version',function()
    sys.write(work..'/fork.cjs','process.send({version:process.version,home:process.env.HOME});process.disconnect();\n',420)
    local js='const c=require("child_process");if(c.execFileSync(process.execPath,["-p","process.version"],{encoding:"utf8"}).trim()!==process.version)process.exit(3);const child=c.fork(process.argv[1],[],{stdio:["ignore","ignore","inherit","ipc"]});child.on("message",m=>console.log(JSON.stringify(m)));child.on("exit",code=>{if(code)process.exitCode=code});'
    local rc,out=run(r,'node',{'-e',js,work..'/fork.cjs'});assert(rc==0,out);assert(sys.json.parse(out).version=='v'..r.entry.version,out)
  end)
  test(r.entry.id..' shell resolves fixed Node and npm',function()
    local rc,out=run(r,'--shell',{'-c','node --version; npm --version'})
    assert(rc==0 and out=='v'..r.entry.version..'\n'..r.npm..'\n',out)
  end)
end
assert(first)
test('custom persistent HOME supports spaces and quotes',function()
  local home=base.."/Homes/Project's data"
  local rc,out=run(first,'node',{'-p','process.env.HOME'},{env={ISTORE_RUNTIME_HOME=home}})
  assert(rc==0 and out:gsub('%s+$','')==home,out)
end)
test('symlink and writable private HOME rejected before write',function()
  local target=base..'/Homes/unsafe';sys.mkdir(target,511);fs.chmod(target,'777')
  local link=base..'/Homes/link';if not fs.lstat(link)then assert(fs.symlink(target,link))end
  for _,home in ipairs({target,link,'/mnt/mise-not-mounted/home',root..'/environments/home'})do
    local rc=run(first,'node',{'--version'},{env={ISTORE_RUNTIME_HOME=home}});assert(rc~=0)
  end
  assert(not fs.lstat(target..'/.cache'))
end)
local function prepare(uid)
  sys.write(work..'/user.json',{op='prepare-user',uid=uid})
  assert(sys.run({'/usr/bin/lua',share..'/main.lua','request'},{stdin=work..'/user.json',output=work..'/prepared.json',
    env={MISE_RUNTIME_ROOT=root,MISE_RUNTIME_MISE_BIN=mise},timeout=20})==0)
end
for _,uid in ipairs({65001,65002})do prepare(uid)end
test('unprivileged UID executes fixed runtime without changing shared SDK',function()
  for _,uid in ipairs({65001,65002})do
    local out=root..'/users/'..uid..'/output'
    local rc,data=run(first,'--shell',{'-c','test ! -w "$1/bin/node.real" && node -p process.env.HOME','probe',root..'/environments/'..first.instance},{uid=uid,output=out})
    assert(rc==0 and data:gsub('%s+$','')==root..'/users/'..uid..'/home',data)
  end
end)
test('accessible project cwd is preserved',function()
  local cwd=base..'/Projects/owned-cwd';sys.mkdir(cwd,448)
  local rc,out=run(first,'node',{'-p','process.cwd()'},{cwd=cwd});assert(rc==0 and out:gsub('%s+$','')==cwd,out)
end)
test('npm origin install uses UID prefix and remains invisible to another UID',function()
  local uid=65001;local rc,out=run(first,'npm',{'install','--global','is-number@7.0.0','--no-audit','--no-fund'},{uid=uid,output=root..'/users/'..uid..'/npm-origin.log',timeout=180})
  assert(rc==0,out)
  local prefix=root..'/users/'..uid..'/home/.local/npm/'..first.instance
  assert(sys.decode(prefix..'/lib/node_modules/is-number/package.json').version=='7.0.0')
  local code='try{require(process.argv[1]);process.exit(2)}catch(e){console.log("private")}'
  rc,out=run(first,'node',{'-e',code,prefix..'/lib/node_modules/is-number'},{uid=65002,output=root..'/users/65002/isolation.log'})
  assert(rc==0 and out=='private\n',out)
end)
test('npm accelerated install keeps its fixed SDK and native integrity',function()
  local uid=65002;local rc,out=run(first,'npm',{'install','--global','is-number@7.0.0','--no-audit','--no-fund'},{uid=uid,policy='ks-cli',output=root..'/users/'..uid..'/npm-accelerated.log',timeout=180})
  assert(rc==0,out)
  local prefix=root..'/users/'..uid..'/home/.local/npm/'..first.instance
  assert(sys.decode(prefix..'/lib/node_modules/is-number/package.json').version=='7.0.0')
end)
test('npm lifecycle executes fixed Node and literal project destination',function()
  local project=base.."/Projects/space project's app";sys.mkdir(project,448)
  local rc,out=run(first,'npm',{'install','--prefix',project,base..'/lifecycle.tgz','--foreground-scripts','--no-audit','--no-fund'},{timeout=120})
  assert(rc==0,out)
  local value=sys.decode(project..'/node_modules/mise-lifecycle-fixture/installed.json')
  assert(value.version=='v'..first.entry.version and value.execPath==root..'/environments/'..first.instance..'/bin/node')
end)
test('bare SDK removal never falls back to system Node',function()
  local path=root..'/environments/'..first.instance..'/bin/node.real';assert(fs.rename(path,path..'.absent'))
  local ok,err=pcall(function()local rc=run(first,'node',{'--version'});assert(rc~=0)end)
  assert(fs.rename(path..'.absent',path));if not ok then error(err)end
end)
print('passed='..count)
