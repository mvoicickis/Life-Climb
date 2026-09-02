import { Controller } from "@hotwired/stimulus"
import {
  disablePushSubscription,
  enablePushSubscription,
  getPushSubscriptionState
} from "push_subscription"

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
      const result = await enablePushSubscription({
        vapidUrl: this.vapidUrlValue,
        subscribeUrl: this.subscribeUrlValue
      })

      if (!result.ok) {
        this.showMessage(this.element.dataset.deniedMessage || "Notifications were blocked.", true)
        return
      }

      this.showMessage(this.element.dataset.enabledMessage || "Reminders enabled.", false)
      this.refreshState()
    } catch (error) {
      if (error.message === "unsupported") {
        this.showMessage(this.element.dataset.unsupportedMessage || "Push is not supported on this browser.", true)
        return
      }
      console.error(error)
      this.showMessage(this.element.dataset.errorMessage || "Could not enable reminders.", true)
    }
  }

  async disable(event) {
    event.preventDefault()
    this.clearMessage()

    try {
      await disablePushSubscription({ unsubscribeUrl: this.unsubscribeUrlValue })
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
    const { subscribed } = await getPushSubscriptionState()

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
}
