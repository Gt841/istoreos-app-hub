local root,base=assert(arg[1]),assert(arg[2])
package.path='/usr/share/mise-runtime/lib/?.lua;'..package.path
local s=require('system');local a=require('artifacts');local work=base..'/archive-names';s.mkdir(work,448)
local report={checks={},scope='real official Go tar listings and malicious path regression'}
local function check(name,ok)
 report.checks[#report.checks+1]={name=name,passed=not not ok};s.write(work..'/result.json',report);assert(ok,name)
end
local header='-rw-r--r-- 0/0 1 2026-01-01 00:00:00 '
for _,path in ipairs({'package/mod/rsc.io_!c!g!o.txt','package/test/Þfoo.go'})do check('accept '..path,a.check_listing(header..path..'\n',1)==1)end
for _,path in ipairs({'package/../escape','/etc/shadow','package/file with space','package/file\tname','package/file\nname','package/back\\slash','package/escaped\\303\\236name','package/quoted"name','package/control'..string.char(1)})do
 local ok,err=pcall(a.check_listing,header..path..'\n',1);check('reject unsafe name '..#report.checks,not ok and type(err)=='table'and err.code=='INTEGRITY')
end
for _,list in ipairs({
 'lrwxrwxrwx 0/0 0 2026-01-01 00:00:00 package/bin/link -> ../../../outside\n',
 'lrwxrwxrwx 0/0 0 2026-01-01 00:00:00 package/bin -> lib\n'..header..'package/bin/write\n',
 header..'package/duplicate\n'..header..'package/duplicate\n',
 'hrw-r--r-- 0/0 1 2026-01-01 00:00:00 package/hardlink\n'
})do local ok,err=pcall(a.check_listing,list,1);check('reject link/duplicate/type '..#report.checks,not ok and type(err)=='table'and err.code=='INTEGRITY')end
check('accept internal symlink',a.check_listing('lrwxrwxrwx 0/0 0 2026-01-01 00:00:00 package/bin/npm -> ../lib/npm.js\n',1)==1)
for _,entry in ipairs(s.decode('/usr/share/mise-runtime/catalog.json').entries)do
 if entry.tool=='go'and entry.arch==s.nixio.uname().machine then
  local artifact=entry.artifacts[1]
  local rc,list=s.capture({'tar','--numeric-owner','--full-time','--quoting-style=escape','-tvf',root..'/cache/'..artifact.sha256},work,120)
  check(entry.id..' complete official archive accepted',rc==0 and a.check_listing(list,artifact.strip)>1000)
 end
end
report.passed=true;s.write(work..'/result.json',report);print(s.json.stringify(report))
