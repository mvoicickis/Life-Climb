import { Controller } from "@hotwired/stimulus"
import { canPrompt, ensureCapture, isStandalonePwa, promptInstall } from "pwa_install_prompt"
import {
  canEnablePushHere,
  enablePushSubscription,
  getPushSubscriptionState,
  isAndroid,
  isIos
} from "push_subscription"

// Post-win push reminder offer — after celebration when eligible (no subscription, under ask cap).
export default class extends Controller {
  static values = {
    dismissUrl: String,
    deniedUrl: String,
    shownUrl: String,
    installedUrl: String,
    vapidUrl: String,
    subscribeUrl: String,
    settingsUrl: String,
    headline: String,
    yesLabel: String,
    notNowLabel: String,
    iosHeadline: String,
    iosBody: String,
    iosInstallLabel: String,
    androidHeadline: String,
    androidBody: String,
    androidInstallLabel: String,
    unsupportedMessage: String,
    enabledMessage: String,
    settingsLinkLabel: String
  }

  connect() {
    ensureCapture()
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
      await enablePushSubscription({
        vapidUrl: this.vapidUrlValue,
        subscribeUrl: this.subscribeUrlValue
      })
      await this.syncPushEndpointFields()
    } catch (error) {
      console.error(error)
    }
  }

  async prepareOffer() {
    const state = await getPushSubscriptionState()

    if (state.subscribed) return
    if (state.permission === "denied") return

    this.renderCard()
  }

  cardMode() {
    const iosInstallNeeded = isIos() && !isStandalonePwa() && !canEnablePushHere()
    const androidInstallNeeded =
      isAndroid() && !isStandalonePwa() && canPrompt() && canEnablePushHere()
    const unsupported = !canEnablePushHere() && !iosInstallNeeded

    if (iosInstallNeeded) return "ios_install"
    if (androidInstallNeeded) return "android_install"
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
    } else if (mode === "android_install") {
      headline.textContent = this.androidHeadlineValue
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
    } else if (mode === "android_install" && this.androidBodyValue) {
      const body = document.createElement("p")
      body.className = "lp-push-offer__body"
      body.textContent = this.androidBodyValue
      card.appendChild(body)
    }

    const actions = document.createElement("div")
    actions.className = "lp-push-offer__actions"

    if (mode !== "unsupported") {
      const yes = document.createElement("button")
      yes.type = "button"
      yes.className = "lp-cta lp-push-offer__yes"
      if (mode === "ios_install") {
        yes.textContent = this.iosInstallLabelValue
        yes.addEventListener("click", (event) => this.install(event))
      } else if (mode === "android_install") {
        yes.textContent = this.androidInstallLabelValue
        yes.addEventListener("click", (event) => this.installThenEnable(event))
      } else {
        yes.textContent = this.yesLabelValue
        yes.addEventListener("click", (event) => this.enable(event))
      }
      actions.appendChild(yes)
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
    this.markShown()
  }

  markShown() {
    if (!this.shownUrlValue) return

    fetch(this.shownUrlValue, {
      method: "PATCH",
      credentials: "same-origin",
      headers: {
        Accept: "application/json",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content || ""
      }
    }).catch(() => {
      /* Network failure — leave card up. */
    })
  }

  async enable(event) {
    event.preventDefault()

    try {
      const result = await enablePushSubscription({
        vapidUrl: this.vapidUrlValue,
        subscribeUrl: this.subscribeUrlValue
      })

      if (!result.ok) {
        if (result.permission === "denied") {
          await this.markDenied()
        }
        this.hideCard()
        return
      }

      await this.syncPushEndpointFields()
      this.hideCard()
    } catch (error) {
      console.error(error)
      this.hideCard()
    }
  }

  async installThenEnable(event) {
    event.preventDefault()

    if (isStandalonePwa()) {
      await this.enable(event)
      return
    }

    if (!canPrompt()) {
      await this.enable(event)
      return
    }

    const result = await promptInstall()
    if (result.outcome !== "accepted") return

    await this.markInstalled()

    try {
      const enableResult = await enablePushSubscription({
        vapidUrl: this.vapidUrlValue,
        subscribeUrl: this.subscribeUrlValue
      })

      if (!enableResult.ok) {
        this.markShown()
        this.hideCard()
        return
      }

      await this.syncPushEndpointFields()
      this.hideCard()
    } catch (error) {
      console.error(error)
      this.markShown()
      this.hideCard()
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
      await this.markInstalled()
      this.hideCard()
    }
  }

  async markInstalled() {
    if (!this.installedUrlValue) return

    try {
      const response = await fetch(this.installedUrlValue, {
        method: "PATCH",
        credentials: "same-origin",
        headers: {
          Accept: "application/json",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content || ""
        }
      })
      if (!response.ok) throw new Error("request failed")
    } catch (_error) {
      /* still hide card locally */
    }
  }

  async dismiss(event) {
    event.preventDefault()

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
  }
}
