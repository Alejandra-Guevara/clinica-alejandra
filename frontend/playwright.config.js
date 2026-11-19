import { defineConfig } from '@playwright/test'

export default defineConfig({
  testDir: './e2e',
  workers: 1,
  expect: { timeout: 15_000 },
  fullyParallel: true,
  reporter: 'list',
  use: { baseURL: 'http://127.0.0.1:4176', trace: 'retain-on-failure' },
  webServer: {
    command: 'npm run dev -- --host 127.0.0.1 --port 4176 --strictPort',
    url: 'http://127.0.0.1:4176',
    reuseExistingServer: false,
    timeout: 30_000,
  },
})
