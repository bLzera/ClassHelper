import axios from 'axios'

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

export default api
