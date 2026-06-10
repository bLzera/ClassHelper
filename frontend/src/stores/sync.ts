import { defineStore } from 'pinia'
import api from '@/lib/api'

interface CoursesSyncResponse {
  synced: number
  courses: unknown[]
}

interface AssignmentsSyncResponse {
  synced: number
}

interface SyncState {
  loading: boolean
  error: boolean
  lastResult: number | null
}

export const useSyncStore = defineStore('sync', {
  state: (): SyncState => ({
    loading: false,
    error: false,
    lastResult: null,
  }),
  actions: {
    async syncCourses(): Promise<number> {
      this.loading = true
      this.error = false
      try {
        const response = await api.post<CoursesSyncResponse>('/courses/sync')
        this.lastResult = response.data.synced
        return response.data.synced
      } catch (err) {
        this.error = true
        throw err
      } finally {
        this.loading = false
      }
    },
    async syncAssignments(): Promise<number> {
      this.loading = true
      this.error = false
      try {
        const response = await api.post<AssignmentsSyncResponse>('/assignments/sync')
        this.lastResult = response.data.synced
        return response.data.synced
      } catch (err) {
        this.error = true
        throw err
      } finally {
        this.loading = false
      }
    },
  },
})
