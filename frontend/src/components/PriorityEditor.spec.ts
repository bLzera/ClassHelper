import { describe, it, expect, vi } from 'vitest'
import { flushPromises, mount } from '@vue/test-utils'

import PriorityEditor from '@/components/PriorityEditor.vue'

describe('PriorityEditor', () => {
  it('pré-preenche o input com a prioridade atual', () => {
    const wrapper = mount(PriorityEditor, {
      props: { current: 3, onSave: vi.fn() },
    })
    const input = wrapper.find('[data-test="priority-input"]').element as HTMLInputElement
    expect(input.value).toBe('3')
  })

  it('input vazio quando não há prioridade atual', () => {
    const wrapper = mount(PriorityEditor, {
      props: { current: null, onSave: vi.fn() },
    })
    const input = wrapper.find('[data-test="priority-input"]').element as HTMLInputElement
    expect(input.value).toBe('')
  })

  it('ao salvar um inteiro positivo chama onSave com o valor numérico', async () => {
    const onSave = vi.fn().mockResolvedValue(undefined)
    const wrapper = mount(PriorityEditor, { props: { current: null, onSave } })

    await wrapper.find('[data-test="priority-input"]').setValue('2')
    await wrapper.find('[data-test="priority-editor"]').trigger('submit')
    await flushPromises()

    expect(onSave).toHaveBeenCalledWith(2)
  })

  it('valor inválido (não positivo) não chama onSave e mostra feedback de validação', async () => {
    const onSave = vi.fn().mockResolvedValue(undefined)
    const wrapper = mount(PriorityEditor, { props: { current: null, onSave } })

    await wrapper.find('[data-test="priority-input"]').setValue('0')
    await wrapper.find('[data-test="priority-editor"]').trigger('submit')
    await flushPromises()

    expect(onSave).not.toHaveBeenCalled()
    expect(wrapper.find('[data-test="priority-validation"]').exists()).toBe(true)
  })

  it('valor vazio não chama onSave e mostra feedback de validação', async () => {
    const onSave = vi.fn().mockResolvedValue(undefined)
    const wrapper = mount(PriorityEditor, { props: { current: null, onSave } })

    await wrapper.find('[data-test="priority-input"]').setValue('')
    await wrapper.find('[data-test="priority-editor"]').trigger('submit')
    await flushPromises()

    expect(onSave).not.toHaveBeenCalled()
    expect(wrapper.find('[data-test="priority-validation"]').exists()).toBe(true)
  })

  it('valor não inteiro (decimal) não chama onSave e mostra feedback de validação', async () => {
    const onSave = vi.fn().mockResolvedValue(undefined)
    const wrapper = mount(PriorityEditor, { props: { current: null, onSave } })

    await wrapper.find('[data-test="priority-input"]').setValue('1.5')
    await wrapper.find('[data-test="priority-editor"]').trigger('submit')
    await flushPromises()

    expect(onSave).not.toHaveBeenCalled()
    expect(wrapper.find('[data-test="priority-validation"]').exists()).toBe(true)
  })

  it('enquanto onSave não resolve, desabilita o botão e mostra "Salvando..."', async () => {
    let resolveFn: () => void = () => {}
    const onSave = vi.fn(
      () =>
        new Promise<void>((resolve) => {
          resolveFn = resolve
        }),
    )
    const wrapper = mount(PriorityEditor, { props: { current: null, onSave } })

    await wrapper.find('[data-test="priority-input"]').setValue('2')
    await wrapper.find('[data-test="priority-editor"]').trigger('submit')

    const button = wrapper.find('[data-test="priority-save"]')
    expect(button.text()).toContain('Salvando...')
    expect((button.element as HTMLButtonElement).disabled).toBe(true)

    resolveFn()
    await flushPromises()
    expect(button.text()).toContain('Salvar')
  })

  it('se onSave rejeitar (ex: 404), exibe feedback de erro sem quebrar', async () => {
    const onSave = vi.fn().mockRejectedValue({ response: { status: 404 } })
    const wrapper = mount(PriorityEditor, { props: { current: null, onSave } })

    await wrapper.find('[data-test="priority-input"]').setValue('2')
    await wrapper.find('[data-test="priority-editor"]').trigger('submit')
    await flushPromises()

    expect(wrapper.find('[data-test="priority-error"]').exists()).toBe(true)
  })
})
