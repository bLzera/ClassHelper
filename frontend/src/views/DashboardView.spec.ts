import { describe, it, expect, beforeEach, vi } from 'vitest'
import { flushPromises, mount } from '@vue/test-utils'
import { setActivePinia, createPinia } from 'pinia'
import { createRouter, createWebHistory } from 'vue-router'

import api from '@/lib/api'
import DashboardView from '@/views/DashboardView.vue'
import AssignmentCard from '@/components/AssignmentCard.vue'
import type { Assignment } from '@/stores/assignments'

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
    due_date: '2026-06-20T12:00:00Z',
    state: 'CREATED',
    manual_priority: null,
    auto_priority: 2,
    course_id: 'c1',
    ...overrides,
  }
}

function buildRouter() {
  return createRouter({
    history: createWebHistory(),
    routes: [
      { path: '/login', name: 'login', component: { template: '<div />' } },
      { path: '/dashboard', name: 'dashboard', component: DashboardView },
    ],
  })
}

async function mountView() {
  const router = buildRouter()
  await router.push('/dashboard')
  await router.isReady()
  return mount(DashboardView, { global: { plugins: [router] } })
}

describe('DashboardView', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    localStorage.clear()
    vi.clearAllMocks()
  })

  it('ao montar chama GET /dashboard e renderiza um card por item, na ordem recebida', async () => {
    const items = [
      buildAssignment({ id: 'a1', title: 'Primeira' }),
      buildAssignment({ id: 'a2', title: 'Segunda' }),
      buildAssignment({ id: 'a3', title: 'Terceira' }),
    ]
    vi.mocked(api.get).mockResolvedValue({ data: { assignments: items } })

    const wrapper = await mountView()
    await flushPromises()

    expect(api.get).toHaveBeenCalledWith('/dashboard')
    const cards = wrapper.findAllComponents(AssignmentCard)
    expect(cards).toHaveLength(3)
    expect(cards.map((c) => c.props('assignment').title)).toEqual([
      'Primeira',
      'Segunda',
      'Terceira',
    ])
  })

  it('cada card mostra título, data formatada e prioridade efetiva (manual ?? auto)', async () => {
    const items = [
      buildAssignment({
        id: 'a1',
        title: 'Com manual',
        manual_priority: 1,
        auto_priority: 9,
      }),
    ]
    vi.mocked(api.get).mockResolvedValue({ data: { assignments: items } })

    const wrapper = await mountView()
    await flushPromises()

    const card = wrapper.findComponent(AssignmentCard)
    const text = card.text()
    expect(text).toContain('Com manual')
    expect(text).toContain('20/06/2026')
    // manual_priority (1) tem precedência sobre auto_priority (9)
    expect(text).toContain('1')
    expect(text).not.toContain('Sem prioridade')
  })

  it('exibe "sem prioridade" quando manual e auto são null', async () => {
    const items = [
      buildAssignment({
        id: 'a1',
        manual_priority: null,
        auto_priority: null,
      }),
    ]
    vi.mocked(api.get).mockResolvedValue({ data: { assignments: items } })

    const wrapper = await mountView()
    await flushPromises()

    expect(wrapper.findComponent(AssignmentCard).text()).toContain('Sem prioridade')
  })

  it('estado de loading: enquanto a request não resolve, exibe indicador de carregamento', async () => {
    vi.mocked(api.get).mockReturnValue(new Promise(() => {}))

    const wrapper = await mountView()

    expect(wrapper.find('[data-test="loading"]').exists()).toBe(true)
    expect(wrapper.findComponent(AssignmentCard).exists()).toBe(false)
  })

  it('estado vazio: assignments [] exibe mensagem de nenhuma tarefa', async () => {
    vi.mocked(api.get).mockResolvedValue({ data: { assignments: [] } })

    const wrapper = await mountView()
    await flushPromises()

    const empty = wrapper.find('[data-test="empty"]')
    expect(empty.exists()).toBe(true)
    expect(empty.text()).toContain('Nenhuma tarefa')
    expect(wrapper.findComponent(AssignmentCard).exists()).toBe(false)
  })

  it('estado de erro: falha na request exibe mensagem de erro sem quebrar', async () => {
    vi.mocked(api.get).mockRejectedValue(new Error('network'))

    const wrapper = await mountView()
    await flushPromises()

    const errorEl = wrapper.find('[data-test="error"]')
    expect(errorEl.exists()).toBe(true)
    expect(wrapper.findComponent(AssignmentCard).exists()).toBe(false)
  })
})
