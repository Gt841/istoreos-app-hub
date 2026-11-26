<template>
 <dialog role="dialog" ref="element" class="mise-dialog" :aria-labelledby="id" @cancel.prevent="emit('close')" @keydown="trap">
  <header><h2 :id="id">{{title}}</h2><div class="dialog-actions"><button class="icon-button" aria-label="关闭窗口" @click="emit('close')">×</button></div></header>
  <div class="dialog-body"><slot/></div>
  <footer v-if="$slots.footer"><slot name="footer"/></footer>
 </dialog>
</template>
<script setup lang="ts">
import {ref,onMounted,onBeforeUnmount,useId} from 'vue'
defineProps<{title:string}>();const emit=defineEmits<{close:[]}>(),id=useId(),element=ref<HTMLDialogElement>();let opener:HTMLElement|null=null
onMounted(()=>{opener=document.activeElement as HTMLElement;element.value?.showModal();const field=element.value?.querySelector<HTMLElement>('[autofocus],input,select');(field||element.value?.querySelector<HTMLElement>('button'))?.focus()})
onBeforeUnmount(()=>{element.value?.close();queueMicrotask(()=>{if(opener?.isConnected)opener.focus()})})
function trap(e:KeyboardEvent){if(e.key!=='Tab')return;const list=Array.from(element.value!.querySelectorAll<HTMLElement>('button:not(:disabled),input:not(:disabled),select:not(:disabled),textarea,a[href],summary')).filter(x=>x.getClientRects().length);const first=list[0],last=list[list.length-1];if(e.shiftKey&&document.activeElement===first){e.preventDefault();last?.focus()}else if(!e.shiftKey&&document.activeElement===last){e.preventDefault();first?.focus()}}
</script>

<style scoped src="../styles/quickstart/dialog.css"></style>

<!-- Keep the copied QuickStart visuals; isolate native modal mechanics from
     the LuCI host's universal margin reset and global header/footer rules. -->
<style scoped>
.mise-dialog{position:fixed;inset:0;margin:auto;max-width:calc(100vw - 32px);max-height:calc(100dvh - 32px);overflow:hidden}
.mise-dialog>header,.mise-dialog>footer{position:relative;inset:auto;flex:none;color:inherit}
.mise-dialog>header::before,.mise-dialog>header::after{content:none;display:none}
.mise-dialog>footer{white-space:normal}
.dialog-body{min-width:0;overflow:auto;overscroll-behavior:contain}
</style>
