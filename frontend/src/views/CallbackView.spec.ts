import { describe, it, expect, beforeEach, vi } from 'vitest'
import { flushPromises, mount } from '@vue/test-utils'
import { setActivePinia, createPinia } from 'pinia'
import { createRouter, createWebHistory } from 'vue-router'

import api from '@/lib/api'
import CallbackView from '@/views/CallbackView.vue'
import { useAuthStore } from '@/stores/auth'

vi.mock('@/lib/api', () => ({
  default: {
    get: vi.fn(),
  },
}))

function buildRouter() {
  return createRouter({
    history: createWebHistory(),
    routes: [
      { path: '/login', name: 'login', component: { template: '<div />' } },
      { path: '/dashboard', name: 'dashboard', component: { template: '<div />' } },
      { path: '/auth/callback', name: 'callback', component: CallbackView },
    ],
  })
}

describe('CallbackView', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    localStorage.clear()
    vi.clearAllMocks()
    window.location.hash = ''
  })

  it('com #token no hash, seta token e redireciona para /dashboard', async () => {
    vi.mocked(api.get).mockResolvedValue({
      data: { id: '1', email: 'a@b.com', name: 'A', created_at: '2026-01-01T00:00:00Z' },
    })

    const router = buildRouter()
    await router.push('/auth/callback')
    await router.isReady()
    const replace = vi.spyOn(router, 'replace')

    // O hash precisa ser setado DEPOIS da navegação do router (que reseta
    // location.hash no jsdom) e ANTES do mount, para que o onMounted o leia.
    window.location.hash = '#token=jwt.token.value'
    mount(CallbackView, { global: { plugins: [router] } })
    await flushPromises()

    const store = useAuthStore()
    expect(store.token).toBe('jwt.token.value')
    expect(replace).toHaveBeenCalledWith('/dashboard')
  })

  it('com #error no hash, não seta token e redireciona para /login', async () => {
    const router = buildRouter()
    await router.push('/auth/callback')
    await router.isReady()
    const replace = vi.spyOn(router, 'replace')

    window.location.hash = '#error=oauth_error'
    mount(CallbackView, { global: { plugins: [router] } })
    await flushPromises()

    const store = useAuthStore()
    expect(store.token).toBeNull()
    expect(replace).toHaveBeenCalledWith('/login')
  })
})
