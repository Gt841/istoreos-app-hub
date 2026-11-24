const fs=require('node:fs'),path=require('node:path'),{execFileSync}=require('node:child_process');
const root=path.resolve(__dirname,'..'),web=path.join(root,'apps/mise/web'),deps=path.join(process.env.BUILD_CACHE_WORK_DIR,'mise-web-deps');
if(Number(process.versions.node.split('.')[0])<24)throw Error('Node 24+ is required');
fs.mkdirSync(deps,{recursive:true});
const link=path.join(web,'node_modules'),target=path.join(deps,'node_modules');
if(fs.lstatSync(link,{throwIfNoEntry:false})){
 if(!fs.lstatSync(link).isSymbolicLink()||fs.readlinkSync(link)!==target)throw Error('Existing node_modules is not owned by this preview; preserve it and choose an isolated checkout');
}
for(const name of ['package.json','package-lock.json'])fs.copyFileSync(path.join(web,name),path.join(deps,name));
execFileSync('npm',['ci','--ignore-scripts','--prefer-offline','--no-audit','--no-fund'],{cwd:deps,stdio:'inherit'});
if(!fs.existsSync(link))fs.symlinkSync(target,link,'dir');
console.log(`mise dependencies: ${fs.realpathSync(link)}`);
