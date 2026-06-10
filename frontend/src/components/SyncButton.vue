<script setup lang="ts">
import { ref } from 'vue'

const props = defineProps<{
  label: string
  action: () => Promise<number>
}>()

const emit = defineEmits<{
  (e: 'success', synced: number): void
}>()

type Status = 'idle' | 'loading' | 'success' | 'error'

const status = ref<Status>('idle')
const syncedCount = ref<number | null>(null)

async function run(): Promise<void> {
  if (status.value === 'loading') {
    return
  }
  status.value = 'loading'
  try {
    const synced = await props.action()
    syncedCount.value = synced
    status.value = 'success'
    emit('success', synced)
  } catch {
    status.value = 'error'
  }
}
</script>

<template>
  <div class="flex flex-col gap-1">
    <button
      type="button"
      data-test="sync-button"
      class="rounded bg-indigo-600 px-4 py-2 font-medium text-white hover:bg-indigo-700 disabled:cursor-not-allowed disabled:opacity-60"
      :disabled="status === 'loading'"
      @click="run"
    >
      <span v-if="status === 'loading'" data-test="sync-loading">Sincronizando...</span>
      <span v-else>{{ label }}</span>
    </button>

    <p
      v-if="status === 'success'"
      data-test="sync-success"
      class="text-sm text-green-700"
    >
      {{ syncedCount }} sincronizados
    </p>

    <p
      v-else-if="status === 'error'"
      data-test="sync-error"
      class="text-sm text-red-700"
    >
      Falha ao sincronizar. Tente novamente.
    </p>
  </div>
</template>
