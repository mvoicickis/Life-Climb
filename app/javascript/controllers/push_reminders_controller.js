import { Controller } from "@hotwired/stimulus"

// Settings/You — enable Web Push reminders and send a manual test notification.
export default class extends Controller {
  static targets = ["status", "enable", "disable", "test", "message", "switch"]
  static values = {
    vapidUrl: String,
    subscribeUrl: String,
    unsubscribeUrl: String,
    testUrl: String
  }

  connect() {
    this.refreshState()
  }

  async enable(event) {
    event.preventDefault()
    this.clearMessage()

    try {
      if (!("serviceWorker" in navigator) || !("PushManager" in window)) {
        this.showMessage(this.element.dataset.unsupportedMessage || "Push is not supported on this browser.", true)
        return
      }

      const permission = await Notification.requestPermission()
      if (permission !== "granted") {
        this.showMessage(this.element.dataset.deniedMessage || "Notifications were blocked.", true)
        return
      }

      const registration = await navigator.serviceWorker.ready
      const { publicKey } = await this.fetchJson(this.vapidUrlValue)
      if (!publicKey) throw new Error("Missing VAPID public key")

      const subscription = await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: this.urlBase64ToUint8Array(publicKey)
      })

      const keys = subscription.toJSON().keys || {}
      await this.fetchJson(this.subscribeUrlValue, {
        method: "POST",
        body: JSON.stringify({
          subscription: {
            endpoint: subscription.endpoint,
            p256dh: keys.p256dh,
            auth: keys.auth
          }
        })
      })

      this.showMessage(this.element.dataset.enabledMessage || "Reminders enabled.", false)
      this.refreshState()
    } catch (error) {
      console.error(error)
      this.showMessage(this.element.dataset.errorMessage || "Could not enable reminders.", true)
    }
  }

  async disable(event) {
    event.preventDefault()
    this.clearMessage()

    try {
      const registration = "serviceWorker" in navigator ? await navigator.serviceWorker.ready : null
      const subscription = registration ? await registration.pushManager.getSubscription() : null
      const endpoint = subscription?.endpoint

      if (subscription) await subscription.unsubscribe()

      const url = endpoint
        ? `${this.unsubscribeUrlValue}?endpoint=${encodeURIComponent(endpoint)}`
        : this.unsubscribeUrlValue

      await this.fetchJson(url, { method: "DELETE" })
      this.showMessage(this.element.dataset.disabledMessage || "Reminders turned off.", false)
      this.refreshState()
    } catch (error) {
      console.error(error)
      this.showMessage(this.element.dataset.errorMessage || "Could not disable reminders.", true)
    }
  }

  async sendTest(event) {
    event.preventDefault()
    this.clearMessage()

    try {
      await this.fetchJson(this.testUrlValue, { method: "POST", body: "{}" })
      this.showMessage(this.element.dataset.testSentMessage || "Test notification sent.", false)
    } catch (error) {
      console.error(error)
      const msg = error?.payload?.error || this.element.dataset.errorMessage || "Could not send test."
      this.showMessage(msg, true)
    }
  }

  async refreshState() {
    let subscribed = false
    try {
      if ("serviceWorker" in navigator && "PushManager" in window) {
        const registration = await navigator.serviceWorker.ready
        const subscription = await registration.pushManager.getSubscription()
        subscribed = !!subscription && Notification.permission === "granted"
      }
    } catch (_) {
      subscribed = false
    }

    if (this.hasStatusTarget) {
      this.statusTarget.textContent = subscribed
        ? (this.element.dataset.statusOn || "On")
        : (this.element.dataset.statusOff || "Off")
    }
    if (this.hasEnableTarget) this.enableTarget.hidden = subscribed
    if (this.hasDisableTarget) this.disableTarget.hidden = !subscribed
    if (this.hasTestTarget) this.testTarget.disabled = !subscribed
    if (this.hasSwitchTarget) {
      this.switchTarget.classList.toggle("is-on", subscribed)
      this.switchTarget.setAttribute("aria-checked", subscribed ? "true" : "false")
    }
  }

  toggleSwitch(event) {
    event.preventDefault()
    const subscribed = this.hasSwitchTarget && this.switchTarget.classList.contains("is-on")
    if (subscribed) this.disable(event)
    else this.enable(event)
  }

  async fetchJson(url, options = {}) {
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

  showMessage(text, isError) {
    if (!this.hasMessageTarget) return
    this.messageTarget.textContent = text
    this.messageTarget.hidden = false
    this.messageTarget.classList.toggle("is-error", !!isError)
  }

  clearMessage() {
    if (!this.hasMessageTarget) return
    this.messageTarget.hidden = true
    this.messageTarget.textContent = ""
  }

  urlBase64ToUint8Array(base64String) {
    const padding = "=".repeat((4 - (base64String.length % 4)) % 4)
    const base64 = (base64String + padding).replace(/-/g, "+").replace(/_/g, "/")
    const raw = atob(base64)
    const output = new Uint8Array(raw.length)
    for (let i = 0; i < raw.length; i++) output[i] = raw.charCodeAt(i)
    return output
  }
}
