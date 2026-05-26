import { createRouter, createWebHistory } from 'vue-router'
import HomeView from '@/views/HomeView.vue'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: '/',
      name: 'home',
      component: HomeView,
    },
  ],
})

// Placeholder do guard de autenticação — implementação real vem no épico F-3.
// router.beforeEach((to, from, next) => { ... })

export default router
