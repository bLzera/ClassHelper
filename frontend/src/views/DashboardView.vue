<script setup lang="ts">
import { onMounted } from 'vue'
import { storeToRefs } from 'pinia'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { useAssignmentsStore } from '@/stores/assignments'
import { useSyncStore } from '@/stores/sync'
import AssignmentCard from '@/components/AssignmentCard.vue'
import SyncButton from '@/components/SyncButton.vue'

const router = useRouter()
const authStore = useAuthStore()
const assignmentsStore = useAssignmentsStore()
const syncStore = useSyncStore()
const { assignments, loading, error } = storeToRefs(assignmentsStore)

onMounted(() => {
  assignmentsStore.fetchDashboard()
})

function logout(): void {
  authStore.logout()
  router.replace('/login')
}

function syncCourses(): Promise<number> {
  return syncStore.syncCourses()
}

function syncAssignments(): Promise<number> {
  return syncStore.syncAssignments()
}

async function syncAll(): Promise<number> {
  await syncStore.syncCourses()
  return syncStore.syncAssignments()
}

async function refreshDashboard(): Promise<void> {
  await assignmentsStore.fetchDashboard()
}
</script>

<template>
  <main class="mx-auto min-h-screen w-full max-w-3xl p-8">
    <header class="mb-6 flex items-center justify-between">
      <h1 class="text-2xl font-bold">Dashboard</h1>
      <button
        type="button"
        class="rounded bg-gray-200 px-4 py-2 font-medium text-gray-800 hover:bg-gray-300"
        @click="logout"
      >
        Sair
      </button>
    </header>

    <section
      class="mb-6 flex flex-wrap gap-3"
      data-test="sync-controls"
    >
      <SyncButton
        data-test="sync-courses"
        label="Sincronizar cursos"
        :action="syncCourses"
        @success="refreshDashboard"
      />
      <SyncButton
        data-test="sync-assignments"
        label="Sincronizar tarefas"
        :action="syncAssignments"
        @success="refreshDashboard"
      />
      <SyncButton
        data-test="sync-all"
        label="Sincronizar tudo"
        :action="syncAll"
        @success="refreshDashboard"
      />
    </section>

    <p
      v-if="loading"
      data-test="loading"
      class="text-gray-600"
    >
      Carregando tarefas...
    </p>

    <p
      v-else-if="error"
      data-test="error"
      class="rounded border border-red-200 bg-red-50 p-4 text-red-700"
    >
      Não foi possível carregar as tarefas. Tente novamente.
    </p>

    <p
      v-else-if="assignments.length === 0"
      data-test="empty"
      class="text-gray-600"
    >
      Nenhuma tarefa por aqui.
    </p>

    <ul
      v-else
      class="flex flex-col gap-3"
    >
      <li
        v-for="assignment in assignments"
        :key="assignment.id"
      >
        <AssignmentCard :assignment="assignment" />
      </li>
    </ul>
  </main>
</template>
