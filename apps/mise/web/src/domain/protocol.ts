// Production wire contract. Design fixtures and scenes are intentionally absent.
export type RuntimeTool='node'|'python'|'go'|'rust'|'zig'|'java'
export type RuntimeAbi='glibc'|'musl'|'native'
export type RuntimeArchitecture='x86_64'|'aarch64'
export type ProbeResult='passed'|'failed'|'unknown'
export interface ArtifactPin{
 url:string;sha256:string;format:'tar.gz'|'tar.xz'|'tar.zst'|'deb';strip:number;bytes?:number;component?:string
}
export interface CatalogEntry{
 id:string;tool:RuntimeTool;version:string;build:string;arch:RuntimeArchitecture;abi:RuntimeAbi
 source:string;availability:'available'|'unavailable';reason?:string;artifacts:ArtifactPin[]
 artifact_set:string;npm?:string;layout:'standard'|'python'|'rust-components'|'zig'
}
export interface RuntimeReceipt{
 schema_version:1;instance:string;entry:CatalogEntry;npm?:string;library?:string;artifact_set:string
 installed_at:number;verified:boolean;probes:Record<string,string>;mise_key:string;root:string
}
export interface AppRuntimeBinding{
 schema_version:1;instance:string;artifact_set:string;library?:string;receipt_sha256:string
}
export interface LibraryReceipt{
 schema_version:1;id:string;arch:RuntimeArchitecture;version:string;revision:string
 manifest_sha256:string;source:string;verified:boolean;missing?:boolean
}
export interface RuntimeState{
 schema_version:1;revision:number;catalog_revision:string;arch:RuntimeArchitecture
 path:string;online:boolean;free_bytes:number|null;free_inodes:number|null;cache_bytes:number|null
 storage_paths:string[];storage_default:string;storage_locked:boolean
 acceleration:boolean;gateway:boolean;runtimes:RuntimeReceipt[];libraries:LibraryReceipt[]
 defaults:Record<RuntimeTool,string|null>
 capabilities:Partial<Record<RuntimeTool,{enabled:boolean;reason?:string}>>
 tasks:Array<{id:string;status:'running'|'success'|'failed'|'canceled'|'interrupted';phase:string;logs:string[]}>
}
export type RuntimeRequest=
 |{op:'read'|'catalog'|'cache-clear'}
 |{op:'plan';entry:string;npm?:string;source:'origin'|'ks-cli'}
 |{op:'submit'|'inspect'|'remove'|'cancel'|'recover'|'wrap'|'library-remove';id:string}
 |{op:'settings';path:string;acceleration:boolean}
 |{op:'library-repair';id:string;source:'origin'|'ks-cli'}
 |{op:'ensure';entry:string;library?:string;source:'origin'|'ks-cli'}
 |{op:'prepare-user';uid:number;gid?:number}
export type RuntimeErrorCode='INVALID_INPUT'|'UNSUPPORTED'|'OFFLINE'|'NO_SPACE'|'BUSY'|'STALE_PLAN'|'INTEGRITY'|'PROBE_FAILED'|'INTERRUPTED'
export type RuntimeResponse<T>=
 |{schema_version:1;ok:true;value:T}
 |{schema_version:1;ok:false;error:{code:RuntimeErrorCode;message:string;phase?:string;task_id?:string}}
