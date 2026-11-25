// In-memory design service. No filesystem, subprocess or device access.
import type {Language,Libc,Architecture,Scene,Runtime,Task,Plan,State} from '../domain/runtime.ts'
import {runtimeId,versions,tools,abiLabel,rustHost,versionLabel,bundledNpm,isDefault} from '../domain/runtime.ts'
export * from '../domain/runtime.ts'
export const scenes:Scene[]=['ready','first','accel','integrity','native','interrupted','offline','python-tools','python-unknown']
export function fixture(scene:Scene='ready',arch:Architecture='x86_64'):State{
 const runtime=(language:Language,version:string,libc:Libc):Runtime=>({id:runtimeId(language,version,libc,arch),language,version,libc,arch,npm:language==='node'?bundledNpm(version):'',...(language==='python'?{pythonTools:{pipVersion:scene==='python-unknown'?null:'25.0.1',venv:scene==='python-unknown'?'unknown' as const:'passed' as const,source:'design' as const}}:{}),size:tools[language].size,verified:!(language==='python'&&scene==='python-unknown')})
 const runtimes=scene==='first'?[]:[runtime('node','24.21.0','glibc'),runtime('node','24.22.1','glibc'),runtime('node','24.21.0','musl'),runtime('python','3.12.10','musl'),runtime('python','3.13.3','glibc'),runtime('go','1.27.4','native'),runtime('rust','1.91.1','musl'),runtime('zig','0.17.1','native'),runtime('java','temurin-21.0.9+10','glibc')]
 const state:State={revision:1,scene,arch,path:scene==='first'?'':'/mnt/data/Configs/Runtime',online:scene!=='offline',acceleration:true,gateway:scene!=='accel',free:8192,cache:240,glibc:scene!=='first',runtimes,defaults:{node:scene==='first'?null:runtimeId('node','24.21.0','musl',arch),python:scene==='first'?null:runtimeId('python','3.12.10','musl',arch),go:scene==='first'?null:runtimeId('go','1.27.4','native',arch),rust:scene==='first'?null:runtimeId('rust','1.91.1','musl',arch),zig:scene==='first'?null:runtimeId('zig','0.17.1','native',arch),java:scene==='first'?null:runtimeId('java','temurin-21.0.9+10','glibc',arch)},tasks:[],plans:[]}
 if(scene==='interrupted')state.tasks.push({id:'interrupted-example',kind:'install',title:'安装 Python 3.13.3 · musl',status:'interrupted',phase:2,phases:['准备','下载','校验','功能验证','提交'],started:Date.now()-30000,logs:['示例：设备重启，候选尚未提交。','原有应用和环境保持不变。'],result:'需要清理中断候选，再重新安装。',failure:''})
 return state
}
function demand(value:unknown,message:string):asserts value{if(!value)throw Error(message)}
function available(s:State){demand(s.path,'请先设置持久存储位置');demand(s.online,'运行时目录离线，请恢复挂载后重试');demand(!s.tasks.some(t=>t.status==='running'),'已有任务在运行，请先查看任务');demand(!s.tasks.some(t=>t.status==='interrupted'),'请先恢复中断任务')}
export function makePlan(s:State,input:Record<string,unknown>,now=Date.now()):Plan{
 available(s)
 demand(input.kind==='install','应用版本由应用自行管理，此处不支持切换或修改全局默认')
 const source=input.source==='origin'?'origin':'ks-cli'
 demand(source!=='ks-cli'||s.gateway,'KSpeeder 不可用，可选择源站下载')
 const p:Plan={id:crypto.randomUUID(),revision:s.revision,expires:now+300000,kind:'install',summary:[],source}
 {
  const language=input.language as Language,version=String(input.version),libc=input.libc as Libc
  demand(Object.hasOwn(tools,language),'请选择语言');demand(versions[language].includes(version),'该版本不在示例目录中');demand(tools[language].abis.includes(libc),'该语言不支持此运行环境')
  demand(!(s.arch==='aarch64'&&language==='node'&&version==='22.16.0'&&libc==='musl'),'示例目录未提供此 ARM64 musl 组合，请选择其他版本')
  demand(language!=='python'||!Object.hasOwn(input,'pip'),'配套 pip 不提供独立版本选择，请在应用虚拟环境中管理');const npm=language==='node'?String(input.npm||bundledNpm(version)):''
  demand(language!=='node'||(version.startsWith('22.')?npm==='10.9.2':['11.12.1','10.9.2'].includes(npm)),'npm 版本与选定 Node 不兼容')
  const r:Runtime={id:runtimeId(language,version,libc,s.arch),language,version,libc,arch:s.arch,npm,...(language==='python'?{pythonTools:{pipVersion:null,venv:'unknown' as const,source:'design' as const}}:{}),size:tools[language].size,verified:false}
  demand(!s.runtimes.some(x=>x.id===r.id),'这个环境已经安装，请查看环境详情');demand(s.free>=2048,'可用空间不足，安装至少预留 2 GiB')
  p.runtime=r;p.summary=[`${tools[language].name} ${versionLabel(language,version)}${npm?' / npm '+npm:''}`,`${s.arch} · ${libc==='glibc'?'私有 glibc 2.39':libc==='musl'?'宿主 musl':abiLabel(libc)}`,libc==='native'?(language==='go'?'标准 Go 工具链，不安装私有 glibc；CGO 需另备 C 工具链':'标准 Zig 工具链，不安装私有 glibc；产物目标由命令指定'):libc==='glibc'&&!s.glibc?'同时准备 glibc 2.39 与 C++ 运行库':'复用已验证的公共运行库',`预计环境占用 ${r.size} MiB；预留工作空间 2 GiB`,source==='ks-cli'?'通过 ks-cli 加速，保留完整性校验':'从源站下载，保留完整性校验','完成后生成专属 wrap 入口，不修改全局默认或应用配置'];if(language==='python')p.summary.splice(2,0,'包含配套 pip，支持虚拟环境；无需选择 pip 版本','准备并验证 pip/venv：创建隔离候选、离线初始化 pip、检查版本与基础功能，失败不提交','应用依赖安装到持久分区的独立虚拟环境，不写入共享 Python');if(language==='java')p.summary.splice(2,0,'发行版：Eclipse Temurin · 完整 JDK，固定构建号；本轮只提供 glibc','JVM 用户目录与临时目录在持久磁盘；不安装 Maven/Gradle');if(language==='rust')p.summary.splice(2,0,`宿主 ${rustHost(s.arch,libc)}；minimal：rustc / cargo / rust-std，不附加组件或交叉目标`)
 }
 s.plans=[...s.plans.filter(x=>x.expires>now),p].slice(-20);return p
}
export function submitPlan(s:State,id:string,now=Date.now()):Task{
 available(s);const p=s.plans.find(p=>p.id===id);demand(p&&p.expires>now&&p.revision===s.revision,'安装内容已变化或复核过期，请重新检查')
 if(p.runtime)demand(!s.runtimes.some(r=>r.id===p.runtime!.id),'这个环境已经安装')
 const t:Task={id:crypto.randomUUID(),kind:'install',title:`安装 ${tools[p.runtime!.language].name} ${versionLabel(p.runtime!.language,p.runtime!.version)} · ${abiLabel(p.runtime!.libc)}`,status:'running',phase:0,phases:['准备','下载','完整性校验',p.runtime!.language==='python'?'配套 pip/venv 准备与验证':'功能验证','生成 wrap'],started:now,logs:['已接受任务；关闭网页不会取消。',p.source==='ks-cli'?'下载策略：ks-cli；校验保持启用。':'下载策略：源站；校验保持启用。'],result:'',runtime:p.runtime,failure:s.tasks.some(t=>t.status==='failed'&&t.failure===s.scene)?'':s.scene}
 s.tasks.unshift(t);s.plans=[];s.revision++;return t
}
export function tick(s:State,now=Date.now(),step=1200){
 for(const t of s.tasks.filter(t=>t.status==='running')){
  const phase=Math.min(Math.floor((now-t.started)/step),t.phases.length)
  while(t.phase<phase&&t.status==='running'){
   t.phase++;
   t.logs.push(`${t.phases[t.phase-1]}：完成（模拟）`)
   const failed=(t.failure==='integrity'&&t.phase===3)||(t.failure==='native'&&t.phase===4)||(t.failure==='python-tools'&&t.runtime?.language==='python'&&t.phase===4)
   if(failed){t.status='failed';t.failedPhase=t.phase-1;t.logs[t.logs.length-1]=`${t.phases[t.phase-1]}：失败（模拟）`;t.result=t.failure==='python-tools'?'配套 pip/venv 验证失败，候选已清理，未提交环境。':t.failure==='integrity'?'包摘要不匹配，候选已清除，原有环境保持不变。':'原生模块检查失败，候选已清除，原有环境保持不变。';t.logs.push(t.result);t.finished=now;s.revision++;break}
   if(t.phase===t.phases.length){
    if(t.runtime){t.runtime.verified=true;if(t.runtime.language==='python')t.runtime.pythonTools={pipVersion:'25.0.1',venv:'passed',source:'design'};s.runtimes.push(t.runtime);s.free-=t.runtime.size;if(t.runtime.libc==='glibc')s.glibc=true}
    if(t.kind==='library-repair')s.glibc=true
    t.status='success';t.result='环境已安装并验证，专属 wrap 已准备；全局默认和应用配置保持不变。';t.logs.push(t.result);t.finished=now;s.revision++
   }
  }
 }
}
export function command(s:State,action:string,input:Record<string,unknown>,now=Date.now()):unknown{
 switch(action){
  case 'plan':return makePlan(s,input,now)
  case 'submit':return submitPlan(s,String(input.id),now)
  case 'cancel':{const t=s.tasks.find(t=>t.id===input.id);demand(t?.status==='running','任务已经结束');t.status='canceled';t.finished=now;t.result='已安全取消，候选已清理；原有环境和应用保持不变。';t.logs.push(t.result);s.revision++;return t}
  case 'recover':{const t=s.tasks.find(t=>t.id===input.id);demand(t?.status==='interrupted','任务无需恢复');t.status='canceled';t.finished=now;t.result='中断候选已清理，可以重新安装；未自动重放任务。';t.logs.push(t.result);s.revision++;return t}
  case 'remove':{available(s);const r=s.runtimes.find(r=>r.id===input.id);demand(r,'环境不存在');demand(!isDefault(s,r.id),'该环境是 mise 全局默认，不能清理；此页不修改全局默认');s.runtimes=s.runtimes.filter(x=>x.id!==r.id);s.free+=r.size;s.revision++;return null}
  case 'library-remove':available(s);demand(!s.runtimes.some(r=>r.libc==='glibc'),'仍有 glibc 环境引用此运行库');s.glibc=false;s.revision++;return null
  case 'library-repair':{
   available(s);const t:Task={id:crypto.randomUUID(),kind:'library-repair',title:'检查 / 修复 glibc 运行库',status:'running',phase:0,phases:['检查引用','准备固定来源','完整性校验','验证运行库','提交'],started:now,logs:['设计样例：按固定版本恢复公共库。'],result:'',failure:''}
   s.tasks.unshift(t);s.revision++;return t
  }
  case 'cache-clear':available(s);s.free+=s.cache;s.cache=0;s.revision++;return null
  case 'settings':{
   availableSettings(s);const path=String(input.path||'').replace(/\/$/,'')
   demand(/^\/mnt\/[A-Za-z0-9_./-]+$/.test(path)&&!path.split('/').some(x=>x==='..'||x==='.'),'请选择 /mnt 下的持久目录，不支持空格、回退路径或临时目录')
   if(path!==s.path){
    const repositories=s.repositories||(s.repositories={})
    if(s.path)repositories[s.path]=structuredClone({runtimes:s.runtimes,defaults:s.defaults,tasks:s.tasks,cache:s.cache,glibc:s.glibc,free:s.free})
    Object.assign(s,structuredClone(repositories[path]||{runtimes:[],defaults:{node:null,python:null,go:null,rust:null,zig:null,java:null},tasks:[],cache:0,glibc:false,free:8192}))
    s.plans=[];s.online=true
   }
   s.path=path;s.acceleration=input.acceleration===true;s.revision++;return null
  }
  default:throw Error('不支持的预览操作')
 }
}
function availableSettings(s:State){demand(!s.tasks.some(t=>['running','interrupted'].includes(t.status)),'请先处理当前任务')}
