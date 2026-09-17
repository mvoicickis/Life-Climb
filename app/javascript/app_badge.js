// Home-screen app icon badge (Badging API). No-op when unsupported (Android Chrome, older Safari).

export function syncAppBadge(count) {
  try {
    if (typeof navigator === "undefined") return

    const n = Number.parseInt(String(count), 10)
    if (!Number.isFinite(n) || n <= 0) {
      if (typeof navigator.clearAppBadge === "function") {
        navigator.clearAppBadge()
      }
      return
    }

    if (typeof navigator.setAppBadge === "function") {
      navigator.setAppBadge(n)
    }
  } catch (_error) {
    /* unsupported or denied */
  }
}
