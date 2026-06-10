import { describe, it, expect, beforeEach, vi } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'

import api from '@/lib/api'
import { useAssignmentsStore, type Assignment } from '@/stores/assignments'

vi.mock('@/lib/api', () => ({
  default: {
    get: vi.fn(),
    patch: vi.fn(),
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

  describe('updatePriority', () => {
    it('chama PATCH /assignments/:id/priority com { manual_priority } e atualiza o item local', async () => {
      const a1 = buildAssignment({ id: 'a1', title: 'A1', manual_priority: null, auto_priority: 5 })
      const a2 = buildAssignment({ id: 'a2', title: 'A2', manual_priority: null, auto_priority: 1 })
      vi.mocked(api.get).mockResolvedValue({ data: { assignments: [a1, a2] } })

      const store = useAssignmentsStore()
      await store.fetchDashboard()

      const updated = { ...a1, manual_priority: 1 }
      vi.mocked(api.patch).mockResolvedValue({ data: updated })

      await store.updatePriority('a1', 1)

      expect(api.patch).toHaveBeenCalledWith('/assignments/a1/priority', { manual_priority: 1 })
      const stored = store.assignments.find((a) => a.id === 'a1')
      expect(stored?.manual_priority).toBe(1)
    })

    it('reordena a lista pela prioridade efetiva após o update (manual tem precedência)', async () => {
      const a1 = buildAssignment({ id: 'a1', title: 'A1', manual_priority: null, auto_priority: 1 })
      const a2 = buildAssignment({ id: 'a2', title: 'A2', manual_priority: null, auto_priority: 2 })
      const a3 = buildAssignment({ id: 'a3', title: 'A3', manual_priority: null, auto_priority: 3 })
      vi.mocked(api.get).mockResolvedValue({ data: { assignments: [a1, a2, a3] } })

      const store = useAssignmentsStore()
      await store.fetchDashboard()

      // a3 ganha manual_priority 0 → deve ir para o topo da lista.
      vi.mocked(api.patch).mockResolvedValue({ data: { ...a3, manual_priority: 0 } })
      await store.updatePriority('a3', 0)

      expect(store.assignments.map((a) => a.id)).toEqual(['a3', 'a1', 'a2'])
    })

    it('propaga o erro (ex: 404) sem alterar a lista', async () => {
      const a1 = buildAssignment({ id: 'a1', manual_priority: null, auto_priority: 2 })
      vi.mocked(api.get).mockResolvedValue({ data: { assignments: [a1] } })

      const store = useAssignmentsStore()
      await store.fetchDashboard()

      const error = { response: { status: 404 } }
      vi.mocked(api.patch).mockRejectedValue(error)

      await expect(store.updatePriority('a1', 3)).rejects.toBe(error)
      expect(store.assignments[0].manual_priority).toBeNull()
    })
  })
})
