<script setup lang="ts">
import { ref } from 'vue'

/**
 * `onSave` é o handler que persiste a nova prioridade; pode ser assíncrono.
 * É recebido como prop (e não via `emit`) porque precisamos await-ar a Promise
 * para controlar os estados de "salvando"/"erro" — `emit()` não retorna o valor
 * devolvido pelo listener do pai.
 */
const props = defineProps<{
  current: number | null
  onSave: (value: number) => Promise<void> | void
}>()

type Status = 'idle' | 'saving' | 'error'

// O valor pode ser `string` (estado inicial/vazio) ou `number` quando o
// `v-model` do <input type="number"> coage a entrada — daí a união de tipos.
const input = ref<string | number>(props.current !== null ? String(props.current) : '')
const status = ref<Status>('idle')
const validationError = ref<string | null>(null)

function isValid(raw: unknown): boolean {
  // `v-model` em <input type="number"> pode produzir `number` em runtime, então
  // normalizamos para string antes de validar (evita `raw.trim is not a function`).
  const trimmed = String(raw ?? '').trim()
  if (trimmed === '') {
    return false
  }
  // Apenas inteiros positivos (>= 1).
  if (!/^\d+$/.test(trimmed)) {
    return false
  }
  return Number(trimmed) >= 1
}

async function save(): Promise<void> {
  if (status.value === 'saving') {
    return
  }
  validationError.value = null

  if (!isValid(input.value)) {
    validationError.value = 'Informe um inteiro positivo.'
    return
  }

  const value = Number(String(input.value).trim())
  status.value = 'saving'
  try {
    await props.onSave(value)
    status.value = 'idle'
  } catch {
    status.value = 'error'
  }
}
</script>

<template>
  <form
    class="flex items-center gap-2"
    data-test="priority-editor"
    @submit.prevent="save"
  >
    <label
      class="sr-only"
      for="priority-input"
    >Prioridade manual</label>
    <input
      id="priority-input"
      v-model="input"
      data-test="priority-input"
      type="number"
      min="1"
      step="1"
      inputmode="numeric"
      class="w-20 rounded border border-gray-300 px-2 py-1 text-sm"
      :disabled="status === 'saving'"
    >
    <button
      type="submit"
      data-test="priority-save"
      class="rounded bg-indigo-600 px-3 py-1 text-sm font-medium text-white hover:bg-indigo-700 disabled:cursor-not-allowed disabled:opacity-60"
      :disabled="status === 'saving'"
    >
      <span v-if="status === 'saving'">Salvando...</span>
      <span v-else>Salvar</span>
    </button>

    <p
      v-if="validationError"
      data-test="priority-validation"
      class="text-xs text-red-700"
    >
      {{ validationError }}
    </p>
    <p
      v-else-if="status === 'error'"
      data-test="priority-error"
      class="text-xs text-red-700"
    >
      Falha ao salvar a prioridade.
    </p>
  </form>
</template>
