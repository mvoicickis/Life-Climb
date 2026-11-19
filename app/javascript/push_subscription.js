import { isStandalonePwa } from "pwa_install_prompt"

export function isIos() {
  if (typeof navigator === "undefined") return false
  return /iPad|iPhone|iPod/.test(navigator.userAgent) ||
    (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1)
}

export function isAndroid() {
  if (typeof navigator === "undefined") return false
  return /Android/i.test(navigator.userAgent)
}

// Short browser label for phone-settings help copy.
export function detectPushBrowserName(ua = typeof navigator !== "undefined" ? navigator.userAgent : "") {
  const s = String(ua || "")
  if (/Edg\//i.test(s)) return "Edge"
  if (/OPR\/|Opera/i.test(s)) return "Opera"
  if (/SamsungBrowser/i.test(s)) return "Samsung Internet"
  if (/Firefox|FxiOS/i.test(s)) return "Firefox"
  if (/Brave/i.test(s)) return "Brave"
  try {
    if (typeof navigator !== "undefined" && navigator.brave && typeof navigator.brave.isBrave === "function") {
      return "Brave"
    }
  } catch (_error) {
    /* ignore */
  }
  if (/Chrome|CriOS|Chromium/i.test(s)) return "Chrome"
  return "your browser"
}

export function canEnablePushHere() {
  if (!("serviceWorker" in navigator) || !("PushManager" in window)) return false
  if (isIos() && !isStandalonePwa()) return false
  return true
}

export function urlBase64ToUint8Array(base64String) {
  const padding = "=".repeat((4 - (base64String.length % 4)) % 4)
  const base64 = (base64String + padding).replace(/-/g, "+").replace(/_/g, "/")
  const raw = atob(base64)
  const output = new Uint8Array(raw.length)
  for (let i = 0; i < raw.length; i++) output[i] = raw.charCodeAt(i)
  return output
}

export async function fetchJson(url, options = {}) {
  const token = document.querySelector("meta[name='csrf-token']")?.content
  const response = await fetch(url, {
    credentials: "same-origin",
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json",
      "X-CSRF-Token": token || ""
    },
    ...options
  })

  const payload = await response.json().catch(() => ({}))
  if (!response.ok) {
    const error = new Error(payload.error || "Request failed")
    error.payload = payload
    throw error
  }
  return payload
}

async function postSubscriptionToServer(subscription, subscribeUrl, timeZone = "") {
  const keys = subscription.toJSON().keys || {}
  const body = {
    subscription: {
      endpoint: subscription.endpoint,
      p256dh: keys.p256dh,
      auth: keys.auth
    }
  }
  const zone = timeZone.toString().trim()
  if (zone) body.time_zone = zone

  await fetchJson(subscribeUrl, {
    method: "POST",
    body: JSON.stringify(body)
  })
}

export async function getPushSubscriptionState() {
  if (!("serviceWorker" in navigator) || !("PushManager" in window)) {
    return { subscribed: false, permission: Notification.permission }
  }

  try {
    const registration = await navigator.serviceWorker.ready
    const subscription = await registration.pushManager.getSubscription()
    return {
      subscribed: !!subscription && Notification.permission === "granted",
      permission: Notification.permission,
      endpoint: subscription?.endpoint
    }
  } catch (_) {
    return { subscribed: false, permission: Notification.permission }
  }
}

export function requestNotificationPermission() {
  return Notification.requestPermission()
}

export async function prefetchPushResources(vapidUrl) {
  if (!canEnablePushHere()) {
    throw new Error("unsupported")
  }

  const registration = await navigator.serviceWorker.ready
  const { publicKey } = await fetchJson(vapidUrl)
  if (!publicKey) throw new Error("Missing VAPID public key")

  return { registration, publicKey }
}

export async function completePushSubscription({
  registration,
  publicKey,
  subscribeUrl,
  timeZone = ""
}) {
  const subscription = await registration.pushManager.subscribe({
    userVisibleOnly: true,
    applicationServerKey: urlBase64ToUint8Array(publicKey)
  })

  await postSubscriptionToServer(subscription, subscribeUrl, timeZone)
  return { ok: true, permission: "granted" }
}

export async function enablePushSubscription({ vapidUrl, subscribeUrl, timeZone = "", prefetched = null }) {
  if (!canEnablePushHere()) {
    throw new Error("unsupported")
  }

  const permission = await Notification.requestPermission()
  if (permission !== "granted") {
    return { ok: false, permission }
  }

  let registration
  let publicKey
  if (prefetched?.registration && prefetched?.publicKey) {
    registration = prefetched.registration
    publicKey = prefetched.publicKey
  } else {
    const loaded = await prefetchPushResources(vapidUrl)
    registration = loaded.registration
    publicKey = loaded.publicKey
  }

  await completePushSubscription({
    registration,
    publicKey,
    subscribeUrl,
    timeZone
  })

  return { ok: true, permission: "granted" }
}

export async function disablePushSubscription({ unsubscribeUrl }) {
  const registration = "serviceWorker" in navigator ? await navigator.serviceWorker.ready : null
  const subscription = registration ? await registration.pushManager.getSubscription() : null
  const endpoint = subscription?.endpoint

  if (subscription) await subscription.unsubscribe()

  const url = endpoint
    ? `${unsubscribeUrl}?endpoint=${encodeURIComponent(endpoint)}`
    : unsubscribeUrl

  await fetchJson(url, { method: "DELETE" })
  return { ok: true }
}

const PUSH_REPAIR_SESSION_KEY = "lp_push_repaired"

function pushRepairAlreadyRan() {
  try {
    return typeof sessionStorage !== "undefined" && sessionStorage.getItem(PUSH_REPAIR_SESSION_KEY) === "1"
  } catch (_error) {
    return false
  }
}

function markPushRepairRan() {
  try {
    if (typeof sessionStorage !== "undefined") {
      sessionStorage.setItem(PUSH_REPAIR_SESSION_KEY, "1")
    }
  } catch (_error) {
    /* private mode / blocked storage — still continue this call */
  }
}

// Quiet upsert on app open: keep the server endpoint in step with this browser.
// Never prompts. At most once per tab session. Never throws to the page.
export async function repairPushSubscriptionIfNeeded({ vapidUrl, subscribeUrl, timeZone = "" }) {
  try {
    if (!canEnablePushHere()) return { ok: false, skipped: "unsupported" }
    if (typeof Notification === "undefined" || Notification.permission !== "granted") {
      return { ok: false, skipped: "permission" }
    }
    if (pushRepairAlreadyRan()) return { ok: false, skipped: "already" }

    markPushRepairRan()

    const registration = await navigator.serviceWorker.ready
    let subscription = await registration.pushManager.getSubscription()

    if (!subscription) {
      const { publicKey } = await fetchJson(vapidUrl)
      if (!publicKey) return { ok: false, skipped: "no_vapid" }

      subscription = await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: urlBase64ToUint8Array(publicKey)
      })
    }

    await postSubscriptionToServer(subscription, subscribeUrl, timeZone)
    return { ok: true, endpoint: subscription.endpoint }
  } catch (error) {
    console.error(error)
    return { ok: false, error }
  }
}
