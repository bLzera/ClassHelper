<script setup lang="ts">
import { computed } from 'vue'
import type { Assignment } from '@/stores/assignments'

const props = defineProps<{
  assignment: Assignment
}>()

const effectivePriority = computed<number | null>(
  () => props.assignment.manual_priority ?? props.assignment.auto_priority,
)

const dateFormatter = new Intl.DateTimeFormat('pt-BR', {
  day: '2-digit',
  month: '2-digit',
  year: 'numeric',
})

const formattedDueDate = computed<string>(() => {
  if (!props.assignment.due_date) {
    return 'Sem prazo'
  }
  const date = new Date(props.assignment.due_date)
  if (Number.isNaN(date.getTime())) {
    return 'Sem prazo'
  }
  return dateFormatter.format(date)
})
</script>

<template>
  <article class="rounded-lg border border-gray-200 bg-white p-4 shadow-sm">
    <h2 class="text-lg font-semibold text-gray-900">{{ assignment.title }}</h2>
    <p
      v-if="assignment.description"
      class="mt-1 text-sm text-gray-600"
    >
      {{ assignment.description }}
    </p>
    <div class="mt-3 flex flex-wrap items-center gap-4 text-sm text-gray-500">
      <span class="inline-flex items-center gap-1">
        <span class="font-medium text-gray-700">Prazo:</span>
        {{ formattedDueDate }}
      </span>
      <span class="inline-flex items-center gap-1">
        <span class="font-medium text-gray-700">Prioridade:</span>
        <template v-if="effectivePriority !== null">{{ effectivePriority }}</template>
        <span
          v-else
          class="text-gray-400"
        >Sem prioridade</span>
      </span>
    </div>
  </article>
</template>
