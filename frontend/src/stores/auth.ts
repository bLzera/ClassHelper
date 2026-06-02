import { defineStore } from 'pinia'
import api from '@/lib/api'

const TOKEN_KEY = 'classhelper_token'

export interface User {
  id: string
  email: string
  name: string
  created_at: string
}

interface AuthState {
  token: string | null
  user: User | null
}

export const useAuthStore = defineStore('auth', {
  state: (): AuthState => ({
    token: localStorage.getItem(TOKEN_KEY),
    user: null,
  }),
  getters: {
    isAuthenticated: (state): boolean => !!state.token,
  },
  actions: {
    setToken(token: string): void {
      this.token = token
      localStorage.setItem(TOKEN_KEY, token)
    },
    async fetchMe(): Promise<void> {
      const response = await api.get<User>('/auth/me')
      this.user = response.data
    },
    logout(): void {
      this.token = null
      this.user = null
      localStorage.removeItem(TOKEN_KEY)
    },
  },
})
