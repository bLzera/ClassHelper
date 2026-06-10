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
  },
})
