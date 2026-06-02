import axios from 'axios'
import { useAuthStore } from '@/stores/auth'

const api = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL,
})

// Injeta o JWT (quando presente) no header Authorization de cada requisição.
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('classhelper_token')
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

// Resposta 401 → sessão inválida: faz logout (limpa token + user).
api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      useAuthStore().logout()
    }
    return Promise.reject(error)
  },
)

export default api
