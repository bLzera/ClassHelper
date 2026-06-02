<script setup lang="ts">
function loginWithGoogle(): void {
  window.location.href = `${import.meta.env.VITE_API_BASE_URL}/auth/login`
}
</script>

<template>
  <main class="flex min-h-screen flex-col items-center justify-center gap-6 p-8">
    <h1 class="text-2xl font-bold">ClassHelper</h1>
    <p class="text-gray-600">Entre para organizar suas tarefas do Classroom.</p>
    <button
      type="button"
      class="rounded bg-blue-600 px-6 py-3 font-medium text-white hover:bg-blue-700"
      @click="loginWithGoogle"
    >
      Entrar com Google
    </button>
  </main>
</template>
