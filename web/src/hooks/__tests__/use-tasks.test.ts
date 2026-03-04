import { describe, it, expect } from 'vitest'
import { taskKeys } from '@/hooks/use-tasks'

describe('taskKeys', () => {
  it('all key starts with "tasks"', () => {
    expect(taskKeys.all).toEqual(['tasks'])
  })

  it('agentTasks includes agent id', () => {
    expect(taskKeys.agentTasks('agent-1')).toEqual(['tasks', 'agent', 'agent-1'])
  })

  it('runnerTasks includes runner id', () => {
    expect(taskKeys.runnerTasks('runner-1')).toEqual(['tasks', 'runner', 'runner-1'])
  })

  it('available returns consistent key', () => {
    expect(taskKeys.available()).toEqual(['tasks', 'available'])
  })

  it('detail includes task id', () => {
    expect(taskKeys.detail('task-1')).toEqual(['tasks', 'detail', 'task-1'])
  })

  it('deliverables uses separate namespace', () => {
    expect(taskKeys.deliverables('task-1')).toEqual(['deliverables', 'task-1'])
  })

  it('applications uses separate namespace', () => {
    expect(taskKeys.applications('task-1')).toEqual(['applications', 'task-1'])
  })

  it('keys are referentially stable for same input', () => {
    // Important for React Query cache invalidation
    const key1 = taskKeys.detail('task-1')
    const key2 = taskKeys.detail('task-1')
    expect(key1).toEqual(key2)
  })
})
