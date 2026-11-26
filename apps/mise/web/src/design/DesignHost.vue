<template>
 <div class="design-host ordered-home home-semantic-colors" :data-preview-ready="ready" :data-preview-generation="generation">
  <QuickstartHost>
   <div class="design-content-region" data-quickstart-content><div class="qs-product">
    <RuntimeApp v-if="route.path==='/mise'" :key="generation" class="mise-surface" :data-theme="effective" :service="service" @ready="ready=true"/>
    <section v-else class="preview-destination mise-surface" :data-theme="effective"><h1>系统导航预览</h1><p>此预览提供运行时环境交互，其他系统功能由实际 iStoreOS 管理。</p><button @click="router.push('/mise')">返回运行时环境</button></section>
   </div></div>
  </QuickstartHost>
  <details class="design-controls"><summary>预览场景</summary><div><p>仅演示交互，不执行真实安装。切换场景会重置本会话的示例任务。</p><label>场景<select aria-label="预览场景" v-model="scene"><option v-for="s in choices" :key="s.id" :value="s.id">{{s.title}}</option></select></label><label>示例架构<select aria-label="示例架构" v-model="arch"><option value="x86_64">x86_64</option><option value="aarch64">ARM64</option></select></label><button @click="reset" :disabled="!ready">{{ready?'载入场景':'正在载入…'}}</button><p v-if="error" role="alert">{{error}}</p><small>运行时版本和兼容状态均为设计样例，不表示设备验收通过。</small></div></details>
 </div>
</template>
<script setup lang="ts">
import {onMounted,onUnmounted,ref} from 'vue'
import {useRoute,useRouter} from 'vue-router'
import QuickstartHost from '../quickstart/design/IStoreHostShellPrototype.vue'
import {getTheme,subscribeTheme} from '../quickstart/utils/theme'
import RuntimeApp from '../RuntimeApp.vue'
import {service} from './service'
import type {Scene,Architecture} from '../domain/runtime'
const route=useRoute(),router=useRouter(),generation=ref(0),ready=ref(false),effective=ref(getTheme()),scene=ref<Scene>('ready'),arch=ref<Architecture>('x86_64'),error=ref('')
const choices=[{id:'ready',title:'已有多个环境'},{id:'first',title:'首次使用'},{id:'accel',title:'KSpeeder 不可用'},{id:'integrity',title:'安装摘要校验失败'},{id:'native',title:'原生模块检查失败'},{id:'interrupted',title:'设备重启后任务中断'},{id:'offline',title:'存储目录离线'},{id:'python-tools',title:'Python pip/venv 验证失败'},{id:'python-unknown',title:'Python 工具状态未读取'}]
async function reset(){ready.value=false;try{await service.scene(scene.value,arch.value);generation.value++;error.value=''}catch(e){error.value=(e as Error).message;ready.value=true}}
let unsubscribe=()=>{}
onMounted(async()=>{unsubscribe=subscribeTheme(s=>effective.value=s.effective);try{const state=await service.read();scene.value=state.scene;arch.value=state.arch}catch{}});onUnmounted(()=>unsubscribe())
</script>
