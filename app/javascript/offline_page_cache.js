export const OFFLINE_PAGE_CACHE_SUFFIX = "-pages"

export async function clearOfflinePageCache() {
  if ("caches" in window) {
    const keys = await caches.keys()
    await Promise.all(
      keys
        .filter((key) => key.startsWith("lifepoints-") && key.endsWith(OFFLINE_PAGE_CACHE_SUFFIX))
        .map((key) => caches.delete(key))
    )
  }

  if (!("serviceWorker" in navigator)) return

  try {
    const registration = await navigator.serviceWorker.ready
    registration.active?.postMessage({ type: "CLEAR_PAGE_CACHE" })
  } catch (_error) {
    /* SW not registered */
  }
}

export function withOfflinePageCacheClearTimeout(promise, ms = 1000) {
  return Promise.race([promise, new Promise((resolve) => setTimeout(resolve, ms))])
}

export function bindOfflinePageCacheForUser(userId) {
  const storageKey = "lpPageCacheUserId"
  const next = String(userId)

  try {
    const prev = localStorage.getItem(storageKey)
    if (prev !== next) {
      void clearOfflinePageCache()
      localStorage.setItem(storageKey, next)
    }
  } catch (_error) {
    /* private mode */
  }
}

export function clearOfflinePageCacheUserBinding() {
  try {
    localStorage.removeItem("lpPageCacheUserId")
  } catch (_error) {
    /* private mode */
  }
}
