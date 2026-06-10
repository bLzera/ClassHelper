import { describe, it, expect, beforeEach, vi } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'

import api from '@/lib/api'
import { useAssignmentsStore, type Assignment } from '@/stores/assignments'

vi.mock('@/lib/api', () => ({
  default: {
    get: vi.fn(),
  },
}))

function buildAssignment(overrides: Partial<Assignment> = {}): Assignment {
  return {
    id: 'a1',
    title: 'Tarefa 1',
    description: 'desc',
    due_date: '2026-06-20T00:00:00Z',
    state: 'CREATED',
    manual_priority: null,
    auto_priority: 2,
    course_id: 'c1',
    ...overrides,
  }
}

describe('assignments store', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    localStorage.clear()
    vi.clearAllMocks()
  })

  it('fetchDashboard popula a lista e desliga loading/error', async () => {
    const items = [buildAssignment({ id: 'a1' }), buildAssignment({ id: 'a2' })]
    vi.mocked(api.get).mockResolvedValue({ data: { assignments: items } })

    const store = useAssignmentsStore()
    await store.fetchDashboard()

    expect(api.get).toHaveBeenCalledWith('/dashboard')
    expect(store.assignments).toEqual(items)
    expect(store.loading).toBe(false)
    expect(store.error).toBe(false)
  })

  it('mantém loading=true enquanto a request não resolve', async () => {
    let resolveFn: (value: { data: { assignments: Assignment[] } }) => void = () => {}
    vi.mocked(api.get).mockReturnValue(
      new Promise((resolve) => {
        resolveFn = resolve
      }),
    )

    const store = useAssignmentsStore()
    const promise = store.fetchDashboard()

    expect(store.loading).toBe(true)

    resolveFn({ data: { assignments: [] } })
    await promise

    expect(store.loading).toBe(false)
  })

  it('em caso de erro marca error e mantém a lista vazia', async () => {
    vi.mocked(api.get).mockRejectedValue(new Error('boom'))

    const store = useAssignmentsStore()
    await store.fetchDashboard()

    expect(store.error).toBe(true)
    expect(store.assignments).toEqual([])
    expect(store.loading).toBe(false)
  })
})
