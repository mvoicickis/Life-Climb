import { Controller } from "@hotwired/stimulus"
import { detectedBrowserTimeZone } from "browser_timezone"
import {
  canEnablePushHere,
  detectPushBrowserName,
  disablePushSubscription,
  enablePushSubscription,
  getPushSubscriptionState,
  isAndroid,
  repairPushSubscriptionIfNeeded
} from "push_subscription"

// Settings/You — enable Web Push reminders and send a manual test notification.
export default class extends Controller {
  static targets = [
    "status",
    "enable",
    "disable",
    "test",
    "message",
    "switch",
    "hint",
    "hintText",
    "turnOn",
    "howToFix",
    "deniedSteps",
    "fixStepApps",
    "fixStepBattery",
    "openChrome"
  ]
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
        subscribeUrl: this.subscribeUrlValue,
        timeZone: detectedBrowserTimeZone()
      })

      if (!result.ok) {
        this.showMessage(this.element.dataset.deniedMessage || "Notifications were blocked.", true)
        await this.refreshState()
        return
      }

      this.showMessage(this.element.dataset.enabledMessage || "Reminders enabled.", false)
      await this.refreshState()
    } catch (error) {
      if (error.message === "unsupported") {
        this.showMessage(this.element.dataset.unsupportedMessage || "Push is not supported in this browser.", true)
        await this.refreshState()
        return
      }
      console.error(error)
      this.showMessage(this.element.dataset.errorMessage || "Could not enable reminders.", true)
    }
  }

  async turnOn(event) {
    await this.enable(event)
  }

  async disable(event) {
    event.preventDefault()
    this.clearMessage()

    try {
      await disablePushSubscription({ unsubscribeUrl: this.unsubscribeUrlValue })
      this.showMessage(this.element.dataset.disabledMessage || "Reminders turned off.", false)
      await this.refreshState()
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
    const state = await getPushSubscriptionState()
    this.applyToggle(state.subscribed)

    if (!canEnablePushHere()) {
      this.showUnsupportedHint()
      return
    }

    if (state.permission === "granted" && state.subscribed) {
      this.hideHint()
      return
    }

    if (state.permission === "granted" && !state.subscribed) {
      this.showSettingUpHint()
      await repairPushSubscriptionIfNeeded({
        vapidUrl: this.vapidUrlValue,
        subscribeUrl: this.subscribeUrlValue,
        timeZone: detectedBrowserTimeZone()
      })
      const next = await getPushSubscriptionState()
      this.applyToggle(next.subscribed)
      this.hideHint()
      return
    }

    if (state.permission === "denied") {
      this.showDeniedHint()
      return
    }

    // default / never asked
    this.showDefaultHint()
  }

  toggleSwitch(event) {
    event.preventDefault()
    const subscribed = this.hasSwitchTarget && this.switchTarget.classList.contains("is-on")
    if (subscribed) this.disable(event)
    else this.enable(event)
  }

  toggleDeniedHelp(event) {
    event.preventDefault()
    if (!this.hasDeniedStepsTarget) return
    this.deniedStepsTarget.hidden = !this.deniedStepsTarget.hidden
  }

  applyToggle(subscribed) {
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

  hideHint() {
    if (this.hasHintTarget) this.hintTarget.hidden = true
    this.hideHintActions()
    if (this.hasDeniedStepsTarget) this.deniedStepsTarget.hidden = true
  }

  hideHintActions() {
    if (this.hasTurnOnTarget) this.turnOnTarget.hidden = true
    if (this.hasHowToFixTarget) this.howToFixTarget.hidden = true
    if (this.hasOpenChromeTarget) this.openChromeTarget.hidden = true
  }

  showHintLine(text) {
    if (!this.hasHintTarget || !this.hasHintTextTarget) return
    this.hintTarget.hidden = false
    this.hintTextTarget.textContent = text
    this.hideHintActions()
    if (this.hasDeniedStepsTarget) this.deniedStepsTarget.hidden = true
  }

  showSettingUpHint() {
    this.showHintLine(this.element.dataset.settingUpMessage || "Setting up reminders…")
  }

  showDefaultHint() {
    this.showHintLine(this.element.dataset.offPhoneMessage || "Notifications are off on this phone")
    if (this.hasTurnOnTarget) this.turnOnTarget.hidden = false
  }

  showDeniedHint() {
    this.showHintLine(this.element.dataset.blockedPhoneMessage || "Notifications are blocked on this phone")
    if (this.hasHowToFixTarget) this.howToFixTarget.hidden = false
    this.fillDeniedSteps()
  }

  showUnsupportedHint() {
    this.showHintLine(
      this.element.dataset.unsupportedChromeMessage ||
        "This browser can't send reminders. Open Life Climb in Chrome for reminders."
    )
    if (this.hasOpenChromeTarget && isAndroid()) {
      this.openChromeTarget.hidden = false
      this.openChromeTarget.href = this.chromeIntentHref()
    }
  }

  fillDeniedSteps() {
    const browser =
      detectPushBrowserName() ||
      this.element.dataset.browserFallback ||
      "your browser"
    const appsTemplate =
      this.element.dataset.fixStepApps ||
      "Phone Settings → Apps → %{browser} → Notifications → On"
    if (this.hasFixStepAppsTarget) {
      this.fixStepAppsTarget.textContent = appsTemplate.replace("%{browser}", browser)
    }
    if (this.hasFixStepBatteryTarget) {
      this.fixStepBatteryTarget.textContent =
        this.element.dataset.fixStepBattery || "Battery → Unrestricted"
    }
  }

  chromeIntentHref() {
    const host = window.location.host
    const path = `${window.location.pathname}${window.location.search}`
    return `intent://${host}${path}#Intent;scheme=https;package=com.android.chrome;end`
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
