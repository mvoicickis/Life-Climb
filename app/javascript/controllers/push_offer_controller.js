import { Controller } from "@hotwired/stimulus"
import { canPrompt, ensureCapture, isStandalonePwa, promptInstall } from "pwa_install_prompt"
import { detectedBrowserTimeZone } from "browser_timezone"
import {
  canEnablePushHere,
  enablePushSubscription,
  getPushSubscriptionState,
  isIos
} from "push_subscription"

// Post-win push reminder offer — after celebration when eligible (no subscription, under ask cap).
export default class extends Controller {
  static values = {
    dismissUrl: String,
    deniedUrl: String,
    shownUrl: String,
    vapidUrl: String,
    subscribeUrl: String,
    settingsUrl: String,
    headline: String,
    yesLabel: String,
    notNowLabel: String,
    iosHeadline: String,
    iosBody: String,
    iosInstallLabel: String,
    unsupportedMessage: String,
    notSavedMessage: String,
    settingsLinkLabel: String
  }

  connect() {
    ensureCapture()
    this._enabling = false
    this._celebrateHandler = (event) => this.onCelebrate(event.detail || {})
    document.addEventListener("battle-day:celebrate", this._celebrateHandler)
    this.syncPushEndpointFields()
    this.syncStandaloneSubscription()
  }

  disconnect() {
    document.removeEventListener("battle-day:celebrate", this._celebrateHandler)
  }

  onCelebrate({ celebrate = false, apGained = 0, pushOfferEligible = false } = {}) {
    if (!pushOfferEligible) return
    if (!celebrate && !(Number(apGained) > 0)) return

    window.setTimeout(() => this.prepareOffer(), 1400)
  }

  async syncPushEndpointFields() {
    const state = await getPushSubscriptionState()
    const endpoint = state.endpoint || ""
    document.querySelectorAll(".js-push-endpoint-field").forEach((input) => {
      input.value = endpoint
    })
  }

  async syncStandaloneSubscription() {
    if (!isStandalonePwa()) return

    const state = await getPushSubscriptionState()
    if (state.subscribed) return
    if (state.permission === "denied") return
    if (state.permission !== "granted") return

    try {
      const result = await enablePushSubscription({
        vapidUrl: this.vapidUrlValue,
        subscribeUrl: this.subscribeUrlValue,
        timeZone: detectedBrowserTimeZone()
      })
      if (result.ok) {
        await this.syncPushEndpointFields()
        await this.markShown()
      }
    } catch (error) {
      console.error(error)
    }
  }

  async prepareOffer() {
    const state = await getPushSubscriptionState()

    if (state.subscribed) return
    if (state.permission === "denied") {
      await this.markDenied()
      return
    }

    this.renderCard()
  }

  cardMode() {
    const iosInstallNeeded = isIos() && !isStandalonePwa() && !canEnablePushHere()
    const unsupported = !canEnablePushHere() && !iosInstallNeeded

    if (iosInstallNeeded) return "ios_install"
    if (unsupported) return "unsupported"
    return "remind"
  }

  renderCard() {
    const host = this.element
    host.hidden = false
    host.innerHTML = ""

    const mode = this.cardMode()

    const card = document.createElement("div")
    card.className = "lp-push-offer"
    card.setAttribute("role", "dialog")
    card.setAttribute("aria-live", "polite")

    const headline = document.createElement("p")
    headline.className = "lp-push-offer__headline"
    if (mode === "ios_install") {
      headline.textContent = this.iosHeadlineValue
    } else if (mode === "unsupported") {
      headline.textContent = this.unsupportedMessageValue
    } else {
      headline.textContent = this.headlineValue
    }
    card.appendChild(headline)

    if (mode === "ios_install" && this.iosBodyValue) {
      const body = document.createElement("p")
      body.className = "lp-push-offer__body"
      body.textContent = this.iosBodyValue
      card.appendChild(body)
    }

    const error = document.createElement("p")
    error.className = "lp-push-offer__error"
    error.hidden = true
    error.setAttribute("role", "alert")
    card.appendChild(error)
    this.errorElement = error

    const actions = document.createElement("div")
    actions.className = "lp-push-offer__actions"

    if (mode !== "unsupported") {
      const yes = document.createElement("button")
      yes.type = "button"
      yes.className = "lp-cta lp-push-offer__yes"
      if (mode === "ios_install") {
        yes.textContent = this.iosInstallLabelValue
        yes.addEventListener("click", (event) => this.install(event))
      } else {
        yes.textContent = this.yesLabelValue
        yes.addEventListener("click", (event) => this.enable(event))
      }
      actions.appendChild(yes)
      this.yesButton = yes
    } else if (this.settingsUrlValue) {
      const settings = document.createElement("a")
      settings.className = "lp-cta lp-push-offer__yes"
      settings.href = this.settingsUrlValue
      settings.textContent = this.settingsLinkLabelValue || "Settings"
      actions.appendChild(settings)
    }

    const notNow = document.createElement("button")
    notNow.type = "button"
    notNow.className = "lp-push-offer__not-now"
    notNow.textContent = this.notNowLabelValue
    notNow.addEventListener("click", (event) => this.dismiss(event))
    actions.appendChild(notNow)

    card.appendChild(actions)
    host.appendChild(card)
    this.cardElement = card
  }

  showNotSavedError() {
    if (!this.errorElement) return
    this.errorElement.textContent =
      this.notSavedMessageValue || "Not saved. Tap to try again."
    this.errorElement.hidden = false
  }

  clearNotSavedError() {
    if (!this.errorElement) return
    this.errorElement.hidden = true
    this.errorElement.textContent = ""
  }

  setYesBusy(busy) {
    if (!this.yesButton) return
    this.yesButton.disabled = busy
    this.yesButton.setAttribute("aria-busy", busy ? "true" : "false")
  }

  markShown() {
    if (!this.shownUrlValue) return Promise.resolve()

    return fetch(this.shownUrlValue, {
      method: "PATCH",
      credentials: "same-origin",
      headers: {
        Accept: "application/json",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content || ""
      }
    }).catch(() => {
      /* Network failure — offer may reappear. */
    })
  }

  async enable(event) {
    event.preventDefault()
    if (this._enabling) return

    this._enabling = true
    this.setYesBusy(true)
    this.clearNotSavedError()

    try {
      const result = await enablePushSubscription({
        vapidUrl: this.vapidUrlValue,
        subscribeUrl: this.subscribeUrlValue,
        timeZone: detectedBrowserTimeZone()
      })

      if (!result.ok) {
        if (result.permission === "denied") {
          await this.markDenied()
          this.hideCard()
          return
        }
        this.showNotSavedError()
        return
      }

      await this.syncPushEndpointFields()
      await this.markShown()
      this.hideCard()
    } catch (error) {
      console.error(error)
      this.showNotSavedError()
    } finally {
      this._enabling = false
      this.setYesBusy(false)
    }
  }

  async install(event) {
    event.preventDefault()

    if (isStandalonePwa()) {
      await this.enable(event)
      return
    }

    if (!canPrompt()) {
      return
    }

    const result = await promptInstall()
    if (result.outcome === "accepted") {
      this.hideCard()
    }
  }

  async dismiss(event) {
    event.preventDefault()
    if (this._enabling) return

    try {
      if (this.dismissUrlValue) {
        await fetch(this.dismissUrlValue, {
          method: "DELETE",
          credentials: "same-origin",
          headers: {
            Accept: "application/json",
            "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content || ""
          }
        })
      }
    } catch (error) {
      console.error(error)
    }

    this.hideCard()
  }

  async markDenied() {
    if (!this.deniedUrlValue) return

    try {
      await fetch(this.deniedUrlValue, {
        method: "PATCH",
        credentials: "same-origin",
        headers: {
          Accept: "application/json",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content || ""
        }
      })
    } catch (error) {
      console.error(error)
    }
  }

  hideCard() {
    this.element.hidden = true
    this.element.innerHTML = ""
    this.cardElement = null
    this.yesButton = null
    this.errorElement = null
  }
}
