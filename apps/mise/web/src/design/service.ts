import type {DesignService} from '../services/runtime'
async function request(path:string,body?:unknown){const r=await fetch('/__design/api/'+path,{credentials:'same-origin',headers:body?{'Content-Type':'application/json'}:{},method:body?'POST':'GET',body:body?JSON.stringify(body):undefined});const result=await r.json();if(!r.ok)throw Error(result.error||'预览数据暂时不可用');return result}
export const service:DesignService={read:()=>request('state'),act:(action,input={})=>request('action',{action,input}),scene:(scene,arch)=>request('scene',{scene,arch})}
