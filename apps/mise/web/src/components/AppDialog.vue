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

<!-- Upstream shade has 16px padding; native dialog needs the equivalent viewport limit. -->
<style scoped>.mise-dialog{max-width:calc(100vw - 32px)}</style>
