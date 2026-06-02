<script setup lang="ts">
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const router = useRouter()
const authStore = useAuthStore()

function logout(): void {
  authStore.logout()
  router.replace('/login')
}
</script>

<template>
  <main class="flex min-h-screen flex-col items-center justify-center gap-6 p-8">
    <h1 class="text-2xl font-bold">Dashboard</h1>
    <button
      type="button"
      class="rounded bg-gray-200 px-4 py-2 font-medium text-gray-800 hover:bg-gray-300"
      @click="logout"
    >
      Sair
    </button>
  </main>
</template>
