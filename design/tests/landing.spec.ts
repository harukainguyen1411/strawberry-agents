import { test, expect, Page } from '@playwright/test'
import path from 'path'

const FILE_URL = 'file://' + path.resolve(__dirname, '../darkstrawberry-landing.html')

// Helper: resolve a CSS variable value on an element
async function cssVar(page: Page, selector: string, varName: string): Promise<string> {
  return page.evaluate(
    ({ sel, v }) => {
      const el = document.querySelector(sel) as HTMLElement
      return getComputedStyle(el).getPropertyValue(v).trim()
    },
    { sel: selector, v: varName }
  )
}

// Helper: get computed color of an element
async function computedColor(page: Page, selector: string): Promise<string> {
  return page.evaluate((sel) => {
    const el = document.querySelector(sel) as HTMLElement
    return getComputedStyle(el).color
  }, selector)
}

test.beforeEach(async ({ page }) => {
  // Always start in dark mode — clear localStorage and force dark
  await page.goto(FILE_URL)
  await page.evaluate(() => localStorage.removeItem('ds-theme'))
  await page.goto(FILE_URL)
  // Page defaults to data-theme="dark" via the HTML attribute
  await expect(page.locator('html')).toHaveAttribute('data-theme', 'dark')
})

// ─────────────────────────────────────────────────
// 1. Button glow animation exists on CTA buttons
// ─────────────────────────────────────────────────
test('btn-primary has a glow animation applied', async ({ page }) => {
  const btn = page.locator('.btn-primary').first()
  await expect(btn).toBeVisible()

  const animationName = await btn.evaluate((el) =>
    getComputedStyle(el).animationName
  )
  expect(animationName).not.toBe('none')
  expect(animationName).toContain('pulse')
})

test('btn-ghost has a glow animation applied', async ({ page }) => {
  const btn = page.locator('.btn-ghost').first()
  await expect(btn).toBeVisible()

  const animationName = await btn.evaluate((el) =>
    getComputedStyle(el).animationName
  )
  expect(animationName).not.toBe('none')
  expect(animationName).toContain('pulse')
})

// ─────────────────────────────────────────────────
// 2. Dark/light mode toggle switches branding
// ─────────────────────────────────────────────────
test('theme toggle switches from dark to light mode', async ({ page }) => {
  await expect(page.locator('html')).toHaveAttribute('data-theme', 'dark')

  await page.click('.theme-toggle')

  await expect(page.locator('html')).toHaveAttribute('data-theme', 'light')
  await expect(page.locator('#toggle-label')).toHaveText('Dark mode')
})

test('theme toggle switches back from light to dark mode', async ({ page }) => {
  // Go to light first
  await page.click('.theme-toggle')
  await expect(page.locator('html')).toHaveAttribute('data-theme', 'light')

  await page.click('.theme-toggle')
  await expect(page.locator('html')).toHaveAttribute('data-theme', 'dark')
  await expect(page.locator('#toggle-label')).toHaveText('Light mode')
})

test('brand adjective reads "Dark" in dark mode', async ({ page }) => {
  const adj = page.locator('.brand-adj').first()
  await expect(adj).toHaveText('Dark')
})

test('brand adjective reads "White" in light mode', async ({ page }) => {
  await page.click('.theme-toggle')
  const adj = page.locator('.brand-adj').first()
  await expect(adj).toHaveText('White')
})

test('theme toggle sun icon visible in dark mode', async ({ page }) => {
  // In dark mode, the toggle shows the sun (to switch to light)
  const iconSvg = page.locator('#toggle-icon svg')
  await expect(iconSvg).toBeVisible()
})

test('theme toggle moon icon visible in light mode', async ({ page }) => {
  await page.click('.theme-toggle')
  const iconSvg = page.locator('#toggle-icon svg')
  await expect(iconSvg).toBeVisible()
})

test('localStorage persists theme across page reload', async ({ page }) => {
  await page.click('.theme-toggle')
  await expect(page.locator('html')).toHaveAttribute('data-theme', 'light')

  await page.goto(FILE_URL)
  await expect(page.locator('html')).toHaveAttribute('data-theme', 'light')
})

// ─────────────────────────────────────────────────
// 3. "Strawberry" text is always red in both modes
// ─────────────────────────────────────────────────
test('"Strawberry" in nav is red in dark mode', async ({ page }) => {
  // .nav-wordmark contains a span[style="color: var(--accent)"] wrapping "Strawberry"
  const redSpan = page.locator('.nav-wordmark span[style*="accent"]')
  await expect(redSpan).toBeVisible()
  const color = await computedColor(page, '.nav-wordmark span[style*="accent"]')
  // accent is #cc2e2e — rgb(204, 46, 46)
  expect(color).toContain('204')
})

test('"Strawberry" in nav is red in light mode', async ({ page }) => {
  await page.click('.theme-toggle')
  const color = await computedColor(page, '.nav-wordmark span[style*="accent"]')
  expect(color).toContain('204')
})

test('"Strawberry" in footer is red in dark mode', async ({ page }) => {
  const color = await computedColor(page, '.footer-wordmark span[style*="accent"]')
  expect(color).toContain('204')
})

test('"Strawberry" in footer is red in light mode', async ({ page }) => {
  await page.click('.theme-toggle')
  const color = await computedColor(page, '.footer-wordmark span[style*="accent"]')
  expect(color).toContain('204')
})

// ─────────────────────────────────────────────────
// 4. "Dark"/"White" matches primary text color
// ─────────────────────────────────────────────────
test('"Dark" brand adj is not red in dark mode', async ({ page }) => {
  // Should be var(--text) — white-ish, not the accent red
  const adj = page.locator('.brand-adj').first()
  const color = await adj.evaluate((el) => getComputedStyle(el).color)
  // Should NOT be rgb(204, 46, 46)
  expect(color).not.toBe('rgb(204, 46, 46)')
  // Should be close to white (high r,g,b values)
  const match = color.match(/rgb\((\d+), (\d+), (\d+)\)/)
  if (match) {
    const [, r, g, b] = match.map(Number)
    expect(r).toBeGreaterThan(200)
    expect(g).toBeGreaterThan(200)
    expect(b).toBeGreaterThan(200)
  }
})

test('"White" brand adj is not red in light mode', async ({ page }) => {
  await page.click('.theme-toggle')
  const adj = page.locator('.brand-adj').first()
  const color = await adj.evaluate((el) => getComputedStyle(el).color)
  expect(color).not.toBe('rgb(204, 46, 46)')
  // In light mode text should be dark (low r,g,b values)
  const match = color.match(/rgb\((\d+), (\d+), (\d+)\)/)
  if (match) {
    const [, r, g, b] = match.map(Number)
    expect(r).toBeLessThan(100)
    expect(g).toBeLessThan(100)
    expect(b).toBeLessThan(100)
  }
})

// ─────────────────────────────────────────────────
// 5. All "Browse Apps" buttons are consistent (btn-primary)
// ─────────────────────────────────────────────────
test('all Browse Apps buttons are btn-primary', async ({ page }) => {
  const browseLinks = page.locator('a:has-text("Browse Apps")')
  const count = await browseLinks.count()
  expect(count).toBeGreaterThan(0)

  for (let i = 0; i < count; i++) {
    const el = browseLinks.nth(i)
    await expect(el).toHaveClass(/btn-primary/)
  }
})

test('Browse Apps buttons all link to the apps portal', async ({ page }) => {
  const browseLinks = page.locator('a:has-text("Browse Apps")')
  const count = await browseLinks.count()

  for (let i = 0; i < count; i++) {
    const href = await browseLinks.nth(i).getAttribute('href')
    expect(href).toContain('apps.darkstrawberry.com')
  }
})

// ─────────────────────────────────────────────────
// 6. All "Request Your App" buttons are consistent (btn-ghost)
// ─────────────────────────────────────────────────
test('all Request Your App buttons are btn-ghost', async ({ page }) => {
  const requestBtns = page.locator('a:has-text("Request Your App")')
  const count = await requestBtns.count()
  expect(count).toBeGreaterThan(0)

  for (let i = 0; i < count; i++) {
    await expect(requestBtns.nth(i)).toHaveClass(/btn-ghost/)
  }
})

// ─────────────────────────────────────────────────
// 7. SVG icons render — no emoji fallbacks
// ─────────────────────────────────────────────────
test('theme toggle renders SVG, not emoji text', async ({ page }) => {
  const iconContent = await page.locator('#toggle-icon').textContent()
  // Should be empty text (SVG child, no text node)
  expect(iconContent?.trim()).toBe('')
  const svg = page.locator('#toggle-icon svg')
  await expect(svg).toBeVisible()
})

test('step icons render SVG', async ({ page }) => {
  const stepIcons = page.locator('.step-icon svg')
  const count = await stepIcons.count()
  expect(count).toBe(3)
  for (let i = 0; i < count; i++) {
    await expect(stepIcons.nth(i)).toBeVisible()
  }
})

test('diff point icons render SVG', async ({ page }) => {
  const diffIcons = page.locator('.diff-point-icon svg')
  const count = await diffIcons.count()
  expect(count).toBe(4)
  for (let i = 0; i < count; i++) {
    await expect(diffIcons.nth(i)).toBeVisible()
  }
})

test('app card icons render SVG', async ({ page }) => {
  const appIcons = page.locator('.app-icon svg')
  const count = await appIcons.count()
  expect(count).toBe(3)
  for (let i = 0; i < count; i++) {
    await expect(appIcons.nth(i)).toBeVisible()
  }
})

test('no emoji characters rendered in icon containers', async ({ page }) => {
  // Check that none of the icon wrapper elements contain raw emoji codepoints
  const hasEmoji = await page.evaluate(() => {
    const emojiPattern = /[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{27BF}]/u
    const iconEls = document.querySelectorAll(
      '.toggle-icon, .step-icon, .diff-point-icon, .app-icon'
    )
    for (const el of Array.from(iconEls)) {
      if (emojiPattern.test(el.textContent ?? '')) return true
    }
    return false
  })
  expect(hasEmoji).toBe(false)
})
