import type {CatalogEntry,LibraryReceipt,RuntimeReceipt,RuntimeRequest,RuntimeResponse} from '../domain/protocol'
import {tools,abiLabel,versionLabel} from './labels'
import type {State,Runtime,RawTask,Plan,Language} from './model'
type WireState={schema_version:1;revision:number;arch:State['arch'];path:string;managed_home?:string;storage_paths?:string[];storage_default?:string;storage_locked?:boolean;online:boolean;storage_error?:string;free_bytes:number|null;cache_bytes:number|null;acceleration:boolean;gateway:boolean;runtimes:RuntimeReceipt[];libraries:LibraryReceipt[];measurements:Record<string,{size_bytes:number|null}>;library_references:Record<string,number>;defaults:Record<string,string|null>;defaults_known:State['defaultsKnown'];default_pins:Record<string,Record<string,boolean>>;default_paths:Record<string,boolean>;default_library:string;capabilities:State['capabilities'];tasks:RawTask[];warnings:string[]}
const messages:Record<string,string>={BUSY:'当前操作受保护或有任务未完成',STALE_PLAN:'安装计划已过期，请重新检查',NO_SPACE:'磁盘空间或 inode 不足',OFFLINE:'存储或后端不可用',UNSUPPORTED:'当前组合尚不支持',INTEGRITY:'完整性检查未通过',PROBE_FAILED:'环境验证未通过',FORBIDDEN:'没有操作权限'}
export class LiveService{
 readonly writable:boolean
 private entries:CatalogEntry[]=[]
 private sequence=0
 constructor(private endpoint:string,private token:string,writable:boolean){this.writable=writable}
 async request<T>(request:RuntimeRequest):Promise<T>{
  const response=await fetch(this.endpoint,{method:'POST',credentials:'same-origin',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:new URLSearchParams({token:this.token,request:JSON.stringify(request)}),cache:'no-store',redirect:'error'})
  if(!(response.headers.get('content-type')||'').includes('application/json'))throw Error(response.status===403?'会话校验失败或权限不足，请重新登录。':'后端未返回有效 JSON，请检查插件是否完整安装。')
  const value=await response.json()as RuntimeResponse<T>
  if(value.schema_version!==1)throw Error('运行时接口版本不兼容，请更新配套插件。')
  if(!value.ok)throw Error(`${messages[value.error.code]||'操作失败'}：${value.error.message}`)
  return value.value
 }
 async read():Promise<State>{
  const stamp=++this.sequence
  if(!this.entries.length){const c=await this.request<{entries:CatalogEntry[]}>({op:'catalog'});if(!Array.isArray(c.entries))throw Error('运行时目录格式不兼容');this.entries=c.entries}
  const raw=await this.request<WireState>({op:'read'})
  if(!['x86_64','aarch64'].includes(raw.arch)||!Array.isArray(raw.runtimes)||!Array.isArray(raw.tasks)||!Array.isArray(raw.libraries))throw Error('运行时状态格式不兼容')
  const catalog=this.entries.filter(e=>e.arch===raw.arch)
  const convert=(receipt:RuntimeReceipt):Runtime=>({id:receipt.instance,entryId:receipt.entry.id,language:receipt.entry.tool,version:receipt.entry.version,libc:receipt.entry.abi,arch:receipt.entry.arch,npm:receipt.npm||'',library:receipt.library,size:raw.measurements[receipt.instance]?.size_bytes==null?null:raw.measurements[receipt.instance].size_bytes!/1048576,verified:receipt.verified,default:!!(raw.default_pins[receipt.entry.tool]?.[receipt.mise_key]||raw.default_paths[receipt.root+'/environments/'+receipt.instance]),probes:receipt.probes,installed:receipt.installed_at,...(receipt.entry.tool==='python'?{pythonTools:{pipVersion:receipt.probes.pip_version||null,venv:receipt.probes.venv||'unknown',source:'probe'as const}}:{})})
  const runtimes=raw.runtimes.map(convert),defaults:State['defaults']={},defaultLabels:State['defaultLabels']={}
  for(const language of Object.keys(tools)as Language[]){
   const value=raw.defaults[language],r=runtimes.find(r=>r.language===language&&(r.id===value||'istore-'+r.id===value))
   if(r){defaults[language]=r.id;defaultLabels[language]=`${tools[language].name} ${r.version} · ${abiLabel(r.libc)}`}
   else defaultLabels[language]=!raw.defaults_known[language]?'尚未确定默认版本':value?`${tools[language].name} ${value}（外部环境）`:'尚未配置默认版本'
  }
  const phases=['starting','library','download','extract','probe','registration','committed'],labels=['准备安装','准备运行库','下载并校验','解包环境','验证运行能力','登记固定版本','提交完成']
  const tasks=raw.tasks.map(t=>{
   const e=catalog.find(e=>e.id===t.plan?.entry),phase=Math.max(0,phases.indexOf(t.phase))
   const result=t.result,installed=result&&typeof result==='object'?runtimes.find(r=>r.id===result.instance):undefined
   const candidate=e&&t.plan?{id:t.plan.instance,entryId:e.id,language:e.tool,version:e.version,libc:e.abi,arch:e.arch,npm:e.npm||'',size:null,verified:false,default:false,probes:{},installed:0}as Runtime:undefined
   return{id:t.id,title:t.plan?.kind==='library-repair'?'检查 / 修复 glibc 运行库':e?`${t.plan?.kind==='ensure'?'准备':'安装'} ${tools[e.tool].name} ${versionLabel(e.tool,e.version)}`:'安装任务',status:t.status,phase,failedPhase:t.status==='failed'?phase:undefined,phases:labels,started:t.started,logs:Array.isArray(t.logs)?t.logs:[],result:t.error?.message||(t.status==='success'?(t.plan?.kind==='library-repair'?'运行库检查 / 修复完成，请重启相关应用':'安装完成'):t.status==='canceled'?'任务已取消，候选已清理':''),library:t.plan?.kind==='library-repair'?t.plan.library:undefined,runtime:installed||candidate}
  })
  return{stamp,revision:raw.revision,arch:raw.arch,path:raw.path,managedHome:raw.managed_home,storagePaths:Array.isArray(raw.storage_paths)?raw.storage_paths.filter(p=>typeof p==="string"):[],storageDefault:raw.storage_default||"",storageLocked:raw.storage_locked??false,online:raw.online,storageError:raw.storage_error,acceleration:raw.acceleration,gateway:raw.gateway,free:raw.free_bytes===null?null:raw.free_bytes/1048576,cache:raw.cache_bytes===null?null:raw.cache_bytes/1048576,catalog,runtimes,libraries:raw.libraries.map(l=>({...l,references:raw.library_references[l.id]||0})),defaults,defaultLabels,defaultsKnown:raw.defaults_known,defaultLibrary:raw.default_library,capabilities:raw.capabilities,tasks,warnings:raw.warnings||[]}
 }
 async plan(entry:CatalogEntry,source:'origin'|'ks-cli'):Promise<Plan>{
  const p=await this.request<{id:string;instance:string}>({op:'plan',entry:entry.id,source})
  return{...p,summary:[`${tools[entry.tool].name} ${versionLabel(entry.tool,entry.version)}`,`${entry.arch} · ${abiLabel(entry.abi)}`,...(entry.npm?[`npm ${entry.npm}`]:[]),'使用锁定来源并核验 SHA256','不改变现有应用的固定版本；安装完成后生成专属 wrap']}
 }
 async act(op:'submit'|'remove'|'cancel'|'recover'|'library-remove'|'cache-clear',id?:string){
  return this.request<{id?:string}>(op==='cache-clear'?{op}:{op,id:id!})
 }
 async repairLibrary(id:string,source:'origin'|'ks-cli'){return this.request<{task:{id:string}}>({op:'library-repair',id,source})}
 async settings(path:string,acceleration:boolean){return this.request({op:'settings',path,acceleration})}
 async wrap(id:string){const text=await this.request<string>({op:'wrap',id});if(typeof text!=='string'||!text.startsWith('#!/bin/sh'))throw Error('固定入口不存在，环境可能已经清理。');return text}
}
