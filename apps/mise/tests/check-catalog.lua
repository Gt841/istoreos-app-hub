local contract=assert(loadfile(arg[1]))()
local json=require('luci.jsonc')
local f=assert(io.open(arg[2]));local catalog=assert(json.parse(f:read('*a')));f:close()
assert(catalog.schema_version==1);contract.digest(catalog.revision)
local ids,versions,combinations={},{},{}
for _,entry in ipairs(catalog.entries)do
 contract.entry(entry);assert(not ids[entry.id]);ids[entry.id]=true
 local id=contract.instance_id(entry,nil,entry.abi=='glibc' and 'glibc-2.39-r1' or nil)
 assert(#id<=240)
 local key=entry.tool..':'..entry.arch
 versions[key]=versions[key] or {};versions[key][entry.version]=true
 combinations[key..':'..entry.abi]=true
end
for tool,abis in pairs(contract.tools)do
 for _,arch in ipairs({'x86_64','aarch64'})do
  local key=tool..':'..arch;local n=0
  for _ in pairs(assert(versions[key]))do n=n+1 end
  assert(n>=2,'two versions required: '..key)
  for abi in pairs(abis)do assert(combinations[key..':'..abi],key..':'..abi)end
 end
end
print('catalog-entries='..#catalog.entries..' matrix=passed')
