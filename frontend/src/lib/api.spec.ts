import { describe, it, expect, beforeEach, vi } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'

describe('api response interceptor', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    localStorage.clear()
    vi.resetModules()
  })

  it('um 401 dispara logout (limpa o token)', async () => {
    const api = (await import('@/lib/api')).default
    const { useAuthStore } = await import('@/stores/auth')

    const store = useAuthStore()
    store.setToken('expired.jwt.token')
    expect(store.isAuthenticated).toBe(true)

    // Recupera o callback de erro registrado no response interceptor.
    const handlers = (
      api.interceptors.response as unknown as {
        handlers: Array<{ rejected?: (e: unknown) => unknown }>
      }
    ).handlers
    const rejected = handlers.find((h) => h.rejected)?.rejected
    expect(rejected).toBeTypeOf('function')

    const error = { response: { status: 401 } }
    await expect(rejected!(error)).rejects.toBe(error)

    expect(store.token).toBeNull()
    expect(store.isAuthenticated).toBe(false)
    expect(localStorage.getItem('classhelper_token')).toBeNull()
  })
})
