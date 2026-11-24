import type {CatalogEntry,LibraryReceipt,RuntimeReceipt,RuntimeTool,RuntimeAbi} from '../domain/protocol'
export type Language=RuntimeTool
export type Libc=RuntimeAbi
export type Runtime={id:string;entryId:string;language:Language;version:string;libc:Libc;arch:'x86_64'|'aarch64';npm:string;library?:string;size:number|null;verified:boolean;default:boolean;probes:Record<string,string>;installed:number;pythonTools?:{pipVersion:string|null;venv:string;source:'probe'}}
export type Task={id:string;title:string;status:'running'|'success'|'failed'|'canceled'|'interrupted';phase:number;failedPhase?:number;phases:string[];started:number;logs:string[];result:string;runtime?:Runtime}
export type Plan={id:string;instance:string;summary:string[]}
export type State={stamp:number;revision:number;arch:'x86_64'|'aarch64';path:string;online:boolean;storageError?:string;acceleration:boolean;gateway:boolean;free:number|null;cache:number|null;catalog:CatalogEntry[];runtimes:Runtime[];libraries:Array<LibraryReceipt&{references:number}>;defaults:Partial<Record<Language,string>>;defaultLabels:Partial<Record<Language,string>>;defaultsKnown:Partial<Record<Language,boolean>>;capabilities:Partial<Record<Language,{enabled:boolean;reason?:string}>>;defaultLibrary:string;tasks:Task[];warnings:string[]}
export type RawTask={id:string;status:Task['status'];phase:string;started:number;logs:string[];error?:{message:string};result?:RuntimeReceipt|string;plan?:{entry:string;instance:string;source:string};cleaned?:boolean}
export function isDefault(s:State,id:string){return s.runtimes.find(r=>r.id===id)?.default===true}
export function quote(value:string){return "'"+value.replaceAll("'","'\\''")+"'"}
export function usageCommands(store:string,r:Runtime){
 const path=quote(store+'/wrap/'+r.id)
 const commands:Record<Language,string[]>={node:['node --version','npm --version'],python:['python --version','pip --version'],go:['go version','go env GOPATH GOCACHE'],rust:['rustc --version','cargo --version'],zig:['zig version','zig env'],java:['java -version','javac -version','jar --version']}
 return [...commands[r.language].map(c=>`${path} ${c}`),`${path} --shell`]
}
export function venvPathError(store:string,target:string){
 if(!target.startsWith('/mnt/')||target.includes('//')||target.endsWith('/')||target.split('/').some(x=>x==='.'||x==='..')||/[\x00-\x1f:]/.test(target))return '请选择 /mnt 下规范的应用数据目录，不支持回退、冒号或控制字符。'
 const path=target.replace(/\/+/g,'/').replace(/\/$/,''),root=store.replace(/\/$/,'')
 if(path===root||root.startsWith(path+'/')||['environments','mise','wrap','libraries','tasks','plans','cache','work','network'].some(p=>path===root+'/'+p||path.startsWith(root+'/'+p+'/')))return '不能使用共享 SDK 或管理目录。'
 return ''
}
export function pythonProjectCommands(store:string,r:Runtime,target:string){
 if(r.language!=='python'||venvPathError(store,target))return[]
 const p=quote(store+'/wrap/'+r.id),v=quote(target)
 return [`${p} --create-venv ${v}`,`${p} --venv ${v} pip install -r requirements.txt`,`${p} --venv ${v} python app.py`,`${p} --venv ${v} --shell`]
}
export function sizeLabel(value:number|null){return value===null?'尚未测量':`${value.toFixed(1)} MiB`}
