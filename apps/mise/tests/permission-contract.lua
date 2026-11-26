package.path='/usr/share/mise-runtime/lib/?.lua;'..package.path
local s=require('system');local base=assert(arg[1]);assert(not s.fs.lstat(base))
s.mkdir(base,493);s.write(base..'/public','public\n',420);s.write(base..'/private','private\n')
local actual={directory=s.fs.stat(base).modedec,public=s.fs.stat(base..'/public').modedec,private=s.fs.stat(base..'/private').modedec}
local report={passed=actual.directory==755 and actual.public==644 and actual.private==600,actual=actual,expected={directory=755,public=644,private=600},scope='real writes under caller umask077; explicit shared modes and private default'}
print(s.json.stringify(report));assert(report.passed,'Explicit resource permissions were masked by caller umask')
