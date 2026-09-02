import { isStandalonePwa } from "pwa_install_prompt"

export function isIos() {
  if (typeof navigator === "undefined") return false
  return /iPad|iPhone|iPod/.test(navigator.userAgent) ||
    (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1)
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

export async function enablePushSubscription({ vapidUrl, subscribeUrl }) {
  if (!canEnablePushHere()) {
    throw new Error("unsupported")
  }

  const permission = await Notification.requestPermission()
  if (permission !== "granted") {
    return { ok: false, permission }
  }

  const registration = await navigator.serviceWorker.ready
  const { publicKey } = await fetchJson(vapidUrl)
  if (!publicKey) throw new Error("Missing VAPID public key")

  const subscription = await registration.pushManager.subscribe({
    userVisibleOnly: true,
    applicationServerKey: urlBase64ToUint8Array(publicKey)
  })

  const keys = subscription.toJSON().keys || {}
  await fetchJson(subscribeUrl, {
    method: "POST",
    body: JSON.stringify({
      subscription: {
        endpoint: subscription.endpoint,
        p256dh: keys.p256dh,
        auth: keys.auth
      }
    })
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
