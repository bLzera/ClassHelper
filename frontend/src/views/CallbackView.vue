<script setup lang="ts">
import { onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const router = useRouter()
const authStore = useAuthStore()

onMounted(async () => {
  const params = new URLSearchParams(location.hash.slice(1))
  const token = params.get('token')
  const error = params.get('error')

  if (token) {
    authStore.setToken(token)
    // Remove o token do fragment do URL.
    history.replaceState(null, '', location.pathname)
    try {
      await authStore.fetchMe()
    } catch {
      // Se /auth/me falhar, o interceptor 401 cuida do logout.
    }
    router.replace('/dashboard')
    return
  }

  if (error) {
    router.replace('/login')
    return
  }

  router.replace('/login')
})
</script>

<template>
  <main class="flex min-h-screen flex-col items-center justify-center p-8">
    <p class="text-gray-600">Autenticando...</p>
  </main>
</template>
