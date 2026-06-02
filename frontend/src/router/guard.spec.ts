import { describe, it, expect, beforeEach, vi } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'

import router from '@/router'
import { useAuthStore } from '@/stores/auth'

vi.mock('@/lib/api', () => ({
  default: {
    get: vi.fn(),
    interceptors: {
      request: { use: vi.fn() },
      response: { use: vi.fn() },
    },
  },
}))

describe('router guard', () => {
  beforeEach(async () => {
    setActivePinia(createPinia())
    localStorage.clear()
    await router.replace('/login')
    await router.isReady()
  })

  it('redireciona para /login ao acessar rota protegida sem token', async () => {
    await router.push('/dashboard')
    expect(router.currentRoute.value.name).toBe('login')
  })

  it('permite acesso a rota protegida com token', async () => {
    const store = useAuthStore()
    store.setToken('valid.jwt.token')

    await router.push('/dashboard')
    expect(router.currentRoute.value.name).toBe('dashboard')
  })
})
