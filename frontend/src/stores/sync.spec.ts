import { describe, it, expect, beforeEach, vi } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'

import api from '@/lib/api'
import { useSyncStore } from '@/stores/sync'

vi.mock('@/lib/api', () => ({
  default: {
    post: vi.fn(),
  },
}))

describe('sync store', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    localStorage.clear()
    vi.clearAllMocks()
  })

  it('syncCourses chama POST /courses/sync e popula lastResult', async () => {
    vi.mocked(api.post).mockResolvedValue({ data: { synced: 3, courses: [] } })

    const store = useSyncStore()
    const result = await store.syncCourses()

    expect(api.post).toHaveBeenCalledWith('/courses/sync')
    expect(result).toBe(3)
    expect(store.lastResult).toBe(3)
    expect(store.loading).toBe(false)
    expect(store.error).toBe(false)
  })

  it('syncAssignments chama POST /assignments/sync e popula lastResult', async () => {
    vi.mocked(api.post).mockResolvedValue({ data: { synced: 5 } })

    const store = useSyncStore()
    const result = await store.syncAssignments()

    expect(api.post).toHaveBeenCalledWith('/assignments/sync')
    expect(result).toBe(5)
    expect(store.lastResult).toBe(5)
    expect(store.loading).toBe(false)
    expect(store.error).toBe(false)
  })

  it('mantém loading=true enquanto a request não resolve', async () => {
    let resolveFn: (value: { data: { synced: number; courses: unknown[] } }) => void = () => {}
    vi.mocked(api.post).mockReturnValue(
      new Promise((resolve) => {
        resolveFn = resolve
      }),
    )

    const store = useSyncStore()
    const promise = store.syncCourses()

    expect(store.loading).toBe(true)

    resolveFn({ data: { synced: 1, courses: [] } })
    await promise

    expect(store.loading).toBe(false)
  })

  it('em caso de erro marca error, propaga a exceção e desliga loading', async () => {
    vi.mocked(api.post).mockRejectedValue(new Error('boom'))

    const store = useSyncStore()
    await expect(store.syncCourses()).rejects.toThrow('boom')

    expect(store.error).toBe(true)
    expect(store.loading).toBe(false)
  })

  it('uma sincronização bem-sucedida limpa o error de uma tentativa anterior', async () => {
    vi.mocked(api.post).mockRejectedValueOnce(new Error('boom'))
    const store = useSyncStore()
    await expect(store.syncAssignments()).rejects.toThrow('boom')
    expect(store.error).toBe(true)

    vi.mocked(api.post).mockResolvedValueOnce({ data: { synced: 2 } })
    await store.syncAssignments()

    expect(store.error).toBe(false)
    expect(store.lastResult).toBe(2)
  })
})
