-- Real ks-cli module and signed sumdb verification with a fresh application UID.
local root,base,uid=assert(arg[1]),assert(arg[2]),assert(tonumber(arg[3]))
package.path='/usr/share/mise-runtime/lib/?.lua;'..package.path
local s=require('system');local fs=s.fs
require('store').validate(root);require('store').filesystem(base)
assert(not fs.lstat(base));s.mkdir(base,493);s.mkdir(base..'/private',448)
assert(not fs.lstat(root..'/users/'..uid),'Fresh test UID required')
local report={scope='real public wrap -> ks-cli -> KSpeeder -> module + signed sumdb',arch=s.nixio.uname().machine,uid=uid,checks={}}
local function check(name,ok,details)
 report.checks[#report.checks+1]={name=name,passed=not not ok,details=details};s.write(base..'/result.json',report);assert(ok,name)
end
local function configs()
 local out={}
 for _,name in ipairs({'mise','istoreenhance','agentflow'})do
  local file='/etc/config/'..name;out[name]=fs.stat(file)and s.sha(file,base..'/private')or false
 end
 return out
end
local function main()
 local before=configs();local r
 for _,id in ipairs(require('store').list(root..'/environments'))do
  local value=s.decode(root..'/environments/'..id..'/receipt.json')
  if value and value.verified and value.entry.tool=='go'and value.entry.version=='1.26.10'then r=value;break end
 end
 assert(r);report.instance=r.instance
 s.write(base..'/private/request.json',{op='prepare-user',uid=uid,gid=uid})
 check('prepare dedicated persistent HOME',s.run({'/usr/sbin/mise-runtime','request'},{env={MISE_RUNTIME_ROOT=root},stdin=base..'/private/request.json',output=base..'/private/prepare.json',timeout=30})==0)
 local home=root..'/users/'..uid..'/home';local project=base..'/project'
 s.mkdir(project,448);assert(fs.chown(project,uid,uid))
 s.write(project..'/go.mod','module istore.local/accelerated-probe\n\ngo 1.26.10\n\nrequire github.com/google/uuid v1.6.0\n',420);assert(fs.chown(project..'/go.mod',uid,uid))
 check('fresh client module and sumdb caches',not fs.lstat(home..'/.cache/go')and not fs.lstat(home..'/.local/go'))
 local function run(args,label)
  local stdout=base..'/private/'..label..'.stdout';local stderr=base..'/private/'..label..'.stderr'
  local argv={'/bin/sh','-c','exec "$@" 2>"$GO_PROBE_STDERR"','go-probe','/usr/share/mise-runtime/native/bin/exec-user',tostring(uid),tostring(uid),r.instance,'go'}
  for _,v in ipairs(args)do argv[#argv+1]=v end
  local rc=s.run(argv,{cwd=project,env={MISE_RUNTIME_ROOT=root,ISTORE_RUNTIME_ACCELERATION='ks-cli',GOSUMDB='sum.golang.org',GONOSUMDB='',GOPRIVATE='',GOINSECURE='',GO_PROBE_STDERR=stderr,HTTPS_PROXY='',https_proxy='',HTTP_PROXY='',http_proxy='',ALL_PROXY='',all_proxy='',NO_PROXY='',no_proxy=''},output=stdout,timeout=150})
  return rc,s.read(stdout)or'',s.read(stderr)or''
 end
 local rc,out,trace=run({'env','GOSUMDB','GONOSUMDB','GOPRIVATE'},'env')
 check('official checksum database enabled without bypasses',rc==0 and out=='sum.golang.org\n\n\n',out)
 rc,out,trace=run({'mod','download','-x','-json','github.com/google/uuid@v1.6.0'},'download')
 report.download_exit=rc
 check('real accelerated Go download succeeds',rc==0,rc~=0 and trace or nil)
 local value=s.json.parse(out)
 check('module and go.mod hashes reported',value and value.Path=='github.com/google/uuid'and value.Version=='v1.6.0'and value.Sum:sub(1,3)=='h1:'and value.GoModSum:sub(1,3)=='h1:')
 check('module cache stays in caller HOME',value.Dir:sub(1,#home+1)==home..'/')
 check('sumdb protocol traverses KSpeeder',trace:find('https://dl-golang.linkease.net:5443/sumdb/sum.golang.org/supported',1,true)and trace:find('/sumdb/sum.golang.org/lookup/',1,true)and trace:find('/sumdb/sum.golang.org/tile/',1,true))
 check('no direct sum.golang.org request',not trace:find('# get https://sum.golang.org/',1,true))
 local sums=s.read(project..'/go.sum')or''
 check('project records both verified hashes',sums:find('github.com/google/uuid v1.6.0 '..value.Sum,1,true)and sums:find('github.com/google/uuid v1.6.0/go.mod '..value.GoModSum,1,true))
 rc,out,trace=run({'mod','verify'},'verify')
 check('native Go verifies cached module contents',rc==0 and out:find('all modules verified',1,true),out)
 local after=configs();local same=true;for key,v in pairs(before)do if after[key]~=v then same=false end end
 check('host service and mise configurations unchanged',same)
 report.module={path=value.Path,version=value.Version,sum=value.Sum,go_mod_sum=value.GoModSum}
 report.config_sha256=after;report.passed=true;s.write(base..'/result.json',report);print(s.json.stringify(report))
end
local ok,err=pcall(main)
if not ok then report.passed=false;report.error=type(err)=='table'and err.message or tostring(err);s.write(base..'/result.json',report);io.stderr:write(report.error..'\n');os.exit(1)end
