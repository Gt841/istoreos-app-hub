import type {State,Plan,Scene,Architecture} from '../domain/runtime'
export interface RuntimeService{
 read():Promise<State>
 act(action:string,input?:Record<string,unknown>):Promise<{state:State;value:Plan|null}>
}
export interface DesignService extends RuntimeService{scene(scene:Scene,arch:Architecture):Promise<{state:State;value:null}>}
