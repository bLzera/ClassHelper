import { describe, it, expect, beforeEach, vi } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'

import api from '@/lib/api'
import { useAuthStore } from '@/stores/auth'

vi.mock('@/lib/api', () => ({
  default: {
    get: vi.fn(),
  },
}))

const TOKEN_KEY = 'classhelper_token'

describe('auth store', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    localStorage.clear()
    vi.clearAllMocks()
  })

  it('setToken persiste o token no localStorage e marca isAuthenticated', () => {
    const store = useAuthStore()
    store.setToken('abc.def.ghi')

    expect(store.token).toBe('abc.def.ghi')
    expect(localStorage.getItem(TOKEN_KEY)).toBe('abc.def.ghi')
    expect(store.isAuthenticated).toBe(true)
  })

  it('logout limpa token + user do estado e do localStorage', () => {
    const store = useAuthStore()
    store.setToken('abc.def.ghi')
    store.user = {
      id: '1',
      email: 'a@b.com',
      name: 'Test',
      created_at: '2026-01-01T00:00:00Z',
    }

    store.logout()

    expect(store.token).toBeNull()
    expect(store.user).toBeNull()
    expect(localStorage.getItem(TOKEN_KEY)).toBeNull()
    expect(store.isAuthenticated).toBe(false)
  })

  it('fetchMe chama GET /auth/me e popula user', async () => {
    const userData = {
      id: '42',
      email: 'gabriel@example.com',
      name: 'Gabriel',
      created_at: '2026-06-02T00:00:00Z',
    }
    vi.mocked(api.get).mockResolvedValue({ data: userData })

    const store = useAuthStore()
    await store.fetchMe()

    expect(api.get).toHaveBeenCalledWith('/auth/me')
    expect(store.user).toEqual(userData)
  })
})
