import { defineStore } from 'pinia'
import api from '@/lib/api'

export interface Assignment {
  id: string
  title: string
  description: string | null
  due_date: string | null
  state: string
  manual_priority: number | null
  auto_priority: number | null
  course_id: string
}

interface DashboardResponse {
  assignments: Assignment[]
}

/**
 * Prioridade efetiva de uma assignment, espelhando a regra do backend:
 * manual_priority tem precedência sobre auto_priority (menor número = maior prioridade).
 */
function effectivePriority(assignment: Assignment): number | null {
  return assignment.manual_priority ?? assignment.auto_priority
}

/**
 * Ordena por prioridade efetiva ascendente, com nulls (sem prioridade) por último,
 * desempatando por título para uma ordem estável.
 */
function sortByEffectivePriority(assignments: Assignment[]): Assignment[] {
  return [...assignments].sort((a, b) => {
    const pa = effectivePriority(a)
    const pb = effectivePriority(b)
    if (pa === null && pb === null) {
      return a.title.localeCompare(b.title)
    }
    if (pa === null) {
      return 1
    }
    if (pb === null) {
      return -1
    }
    if (pa !== pb) {
      return pa - pb
    }
    return a.title.localeCompare(b.title)
  })
}

interface AssignmentsState {
  assignments: Assignment[]
  loading: boolean
  error: boolean
}

export const useAssignmentsStore = defineStore('assignments', {
  state: (): AssignmentsState => ({
    assignments: [],
    loading: false,
    error: false,
  }),
  actions: {
    async fetchDashboard(): Promise<void> {
      this.loading = true
      this.error = false
      try {
        const response = await api.get<DashboardResponse>('/dashboard')
        this.assignments = response.data.assignments
      } catch {
        this.error = true
        this.assignments = []
      } finally {
        this.loading = false
      }
    },

    /**
     * Atualiza a manual_priority de uma assignment via PATCH e reflete o resultado
     * localmente, reordenando a lista pela prioridade efetiva (sem refazer o GET /dashboard).
     * Lança o erro de volta para o chamador (componente) tratar o feedback.
     */
    async updatePriority(id: string, value: number): Promise<void> {
      const response = await api.patch<Assignment>(`/assignments/${id}/priority`, {
        manual_priority: value,
      })
      const updated = response.data
      const index = this.assignments.findIndex((a) => a.id === id)
      if (index !== -1) {
        this.assignments[index] = updated
        this.assignments = sortByEffectivePriority(this.assignments)
      }
    },
  },
})
