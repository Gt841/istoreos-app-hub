local root,base=arg[1],arg[2]
package.path='/usr/share/mise-runtime/lib/?.lua;'..package.path
local s=require('system');local store=require('store')
local work=base..'/native-helper';s.mkdir(work,448)
local r
for _,id in ipairs(store.list(root..'/environments'))do local v=s.decode(root..'/environments/'..id..'/receipt.json');if v and v.verified and v.entry.abi=='glibc'then r=v;break end end
assert(r)
local helper='/usr/share/mise-runtime/native/bin/exec-user'
local env={MISE_RUNTIME_ROOT=root,ISTORE_RUNTIME_HOME=root..'/users/65001/home',ISTORE_RUNTIME_ACCELERATION='origin'}
local results={}
local function run(name,argv,expected,options)
 options=options or{};options.env=env;options.output=work..'/output';options.timeout=10
 local rc=s.run(argv,options);assert(rc==expected,name..': '..rc..' '..(s.read(work..'/output')or''))
 results[#results+1]={name=name,exit=rc,passed=true}
end
s.write(work..'/input','stdin preserved\n')
local js=[[const a=require('node:assert/strict'),f=require('node:fs');a.equal(process.getuid(),65001);a.equal(process.getgid(),65001);a.ok(!process.getgroups().includes(0));a.match(f.readFileSync('/proc/self/status','utf8'),/^Groups:\s*\n/m);a.equal(process.argv[1],'two words');a.equal(f.readFileSync(0,'utf8'),'stdin preserved\n');console.log(JSON.stringify({uid:process.getuid(),gid:process.getgid(),groups:process.getgroups(),node:process.version,home:process.env.HOME}));]]
run('real UID/GID, no inherited root groups, argv/stdin',{helper,'65001','65001',r.instance,'node','-e',js,'two words'},0,{stdin=work..'/input'})
local identity=s.json.parse(s.read(work..'/output'));assert(identity)
run('exact native exit status',{helper,'65001','65001',r.instance,'node','-e','process.exit(37)'},37)
run('reject UID zero',{helper,'0','65001',r.instance,'node','--version'},126)
run('reject GID zero',{helper,'65001','0',r.instance,'node','--version'},126)
run('reject signed/invalid identity',{helper,'-1','65001',r.instance,'node','--version'},126)
run('non-root caller cannot select another UID',{helper,'65002','65002',r.instance,'node','--version'},126,{uid=65001,gid=65001})
local marker=work..'/must-not-execute';assert(not s.fs.lstat(marker))
local value='$(touch '..marker..') `touch '..marker..'` $HOME'
s.write(work..'/credentials','touch '..marker..'\nOPENAI_API_KEY='..s.json.stringify(value)..'\n')
run('application env is literal data, not root shell code',{'/usr/bin/lua','/usr/share/openclawmgr/env-value.lua',work..'/credentials','OPENAI_API_KEY'},0)
assert(s.read(work..'/output')==value and not s.fs.lstat(marker))
assert(s.fs.symlink(work..'/credentials',work..'/credential-link'))
run('reject credential symlink',{'/usr/bin/lua','/usr/share/openclawmgr/env-value.lua',work..'/credential-link','OPENAI_API_KEY'},1)
assert(s.fs.unlink(work..'/credential-link'))
s.write(base..'/native-helper-result.json',{passed=true,identity=identity,results=results})
print(s.json.stringify({passed=true,identity=identity,results=results}))
