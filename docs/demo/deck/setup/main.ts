import { defineAppSetup } from '@slidev/types'

export default defineAppSetup(({ app }) => {
  // Hook for future global injections (analytics, theme switches, etc.)
  void app
})
