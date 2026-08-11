// Shared PWA install prompt store — capture beforeinstallprompt once so
// Today tip and Settings can both call promptInstall().

let deferredPrompt = null
let capturing = false
const listeners = new Set()

function notify(detail = {}) {
  listeners.forEach((fn) => {
    try {
      fn(detail)
    } catch (_error) {
      /* ignore listener errors */
    }
  })
}

export function ensureCapture() {
  if (capturing || typeof window === "undefined") return
  capturing = true

  window.addEventListener("beforeinstallprompt", (event) => {
    event.preventDefault()
    deferredPrompt = event
    notify({ available: true })
  })

  window.addEventListener("appinstalled", () => {
    deferredPrompt = null
    notify({ installed: true })
  })
}

export function isStandalonePwa() {
  if (typeof window === "undefined" || !window.matchMedia) return false
  return window.matchMedia("(display-mode: standalone)").matches
}

export function canPrompt() {
  return deferredPrompt != null
}

export function onInstallPromptChange(fn) {
  listeners.add(fn)
  return () => listeners.delete(fn)
}

export async function promptInstall() {
  if (!deferredPrompt) return { outcome: "unavailable" }

  const event = deferredPrompt
  deferredPrompt = null

  try {
    await event.prompt()
    const choice = await event.userChoice
    return { outcome: choice?.outcome || "dismissed" }
  } catch (_error) {
    return { outcome: "error" }
  }
}
