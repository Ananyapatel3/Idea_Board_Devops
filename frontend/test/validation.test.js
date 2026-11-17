import test from 'node:test'
import assert from 'node:assert/strict'
import { normalizeIdeaContent } from '../src/validation.js'

test('trims idea content', () => {
  assert.equal(normalizeIdeaContent('  ship it  '), 'ship it')
})

test('rejects empty or whitespace-only content', () => {
  assert.equal(normalizeIdeaContent(''), null)
  assert.equal(normalizeIdeaContent('   '), null)
})

test('accepts the 1000-character limit and rejects longer content', () => {
  assert.equal(normalizeIdeaContent('x'.repeat(1000)).length, 1000)
  assert.equal(normalizeIdeaContent('x'.repeat(1001)), null)
})
