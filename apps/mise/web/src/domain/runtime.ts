import type {Language,Libc} from './catalog.ts'
export {tools,languages,versions,abiLabel,rustHost,versionLabel,validVersion,bundledNpm,type Language,type Libc} from './catalog.ts'
export type Architecture='x86_64'|'aarch64'
export type Scene='ready'|'first'|'accel'|'integrity'|'native'|'interrupted'|'offline'|'python-tools'|'python-unknown'
export type PythonTools={pipVersion:string|null;venv:'passed'|'failed'|'unknown';source:'probe'|'design'}
export type Runtime={id:string;language:Language;version:string;libc:Libc;arch:Architecture;npm:string;pythonTools?:PythonTools;size:number;verified:boolean}
export type Task={id:string;kind:'install';title:string;status:'running'|'success'|'failed'|'canceled'|'interrupted';phase:number;failedPhase?:number;phases:string[];started:number;finished?:number;logs:string[];result:string;runtime?:Runtime;failure:string}
export type Plan={id:string;revision:number;expires:number;kind:'install';runtime?:Runtime;summary:string[];source:'ks-cli'|'origin'}
export type State={revision:number;scene:Scene;arch:Architecture;path:string;online:boolean;acceleration:boolean;gateway:boolean;free:number;cache:number;glibc:boolean;runtimes:Runtime[];defaults:Record<Language,string|null>;tasks:Task[];plans:Plan[]}
export function runtimeId(language:Language,version:string,libc:Libc,arch:Architecture){return `${language}-${version}-${arch}-${libc}`}

export function isDefault(s:State,id:string){return Object.values(s.defaults).includes(id)}
