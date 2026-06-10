import { describe, it, expect, vi } from 'vitest'
import { flushPromises, mount } from '@vue/test-utils'

import SyncButton from '@/components/SyncButton.vue'

describe('SyncButton', () => {
  it('renderiza o label recebido em estado idle', () => {
    const wrapper = mount(SyncButton, {
      props: { label: 'Sincronizar cursos', action: vi.fn().mockResolvedValue(0) },
    })

    expect(wrapper.find('[data-test="sync-button"]').text()).toContain('Sincronizar cursos')
    expect(wrapper.find('[data-test="sync-loading"]').exists()).toBe(false)
  })

  it('ao clicar chama a action recebida via prop', async () => {
    const action = vi.fn().mockResolvedValue(3)
    const wrapper = mount(SyncButton, {
      props: { label: 'Sincronizar tarefas', action },
    })

    await wrapper.find('[data-test="sync-button"]').trigger('click')
    await flushPromises()

    expect(action).toHaveBeenCalledTimes(1)
  })

  it('enquanto a action não resolve, exibe loading e desabilita o botão (sem disparo duplo)', async () => {
    let resolveFn: (value: number) => void = () => {}
    const action = vi.fn().mockReturnValue(
      new Promise<number>((resolve) => {
        resolveFn = resolve
      }),
    )
    const wrapper = mount(SyncButton, {
      props: { label: 'Sincronizar cursos', action },
    })

    const button = wrapper.find('[data-test="sync-button"]')
    await button.trigger('click')

    expect(wrapper.find('[data-test="sync-loading"]').exists()).toBe(true)
    expect((button.element as HTMLButtonElement).disabled).toBe(true)

    // clique extra enquanto carrega não deve disparar a action de novo
    await button.trigger('click')
    expect(action).toHaveBeenCalledTimes(1)

    resolveFn(3)
    await flushPromises()

    expect((button.element as HTMLButtonElement).disabled).toBe(false)
  })

  it('em sucesso exibe feedback "N sincronizados" e emite o evento success', async () => {
    const action = vi.fn().mockResolvedValue(7)
    const wrapper = mount(SyncButton, {
      props: { label: 'Sincronizar tudo', action },
    })

    await wrapper.find('[data-test="sync-button"]').trigger('click')
    await flushPromises()

    const success = wrapper.find('[data-test="sync-success"]')
    expect(success.exists()).toBe(true)
    expect(success.text()).toContain('7 sincronizados')
    expect(wrapper.emitted('success')).toEqual([[7]])
  })

  it('em erro exibe feedback de erro, não emite success e volta o botão ao estado idle', async () => {
    const action = vi.fn().mockRejectedValue(new Error('network'))
    const wrapper = mount(SyncButton, {
      props: { label: 'Sincronizar cursos', action },
    })

    const button = wrapper.find('[data-test="sync-button"]')
    await button.trigger('click')
    await flushPromises()

    expect(wrapper.find('[data-test="sync-error"]').exists()).toBe(true)
    expect(wrapper.emitted('success')).toBeUndefined()
    expect(wrapper.find('[data-test="sync-loading"]').exists()).toBe(false)
    expect((button.element as HTMLButtonElement).disabled).toBe(false)
  })
})
