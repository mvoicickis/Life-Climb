import { Controller } from "@hotwired/stimulus"
import { canPrompt, ensureCapture, isStandalonePwa, promptInstall } from "pwa_install_prompt"
import {
  canEnablePushHere,
  enablePushSubscription,
  getPushSubscriptionState,
  isIos
} from "push_subscription"

// Post-win push reminder offer — shown after battle celebration on wins 1–3.
export default class extends Controller {
  static values = {
    dismissUrl: String,
    deniedUrl: String,
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
    enabledMessage: String,
    settingsLinkLabel: String
  }

  connect() {
    console.log("[lp-push-offer-debug] push-offer#connect", {
      hostHidden: this.element.hidden,
      hasDismissUrl: Boolean(this.dismissUrlValue),
      hasSubscribeUrl: Boolean(this.subscribeUrlValue)
    })
    ensureCapture()
    this._celebrateHandler = (event) => this.onCelebrate(event.detail || {})
    document.addEventListener("battle-day:celebrate", this._celebrateHandler)
  }

  disconnect() {
    document.removeEventListener("battle-day:celebrate", this._celebrateHandler)
  }

  onCelebrate({ celebrate = false, apGained = 0, pushOfferEligible = false, winNumber = 0 } = {}) {
    const detail = {
      celebrate: Boolean(celebrate),
      apGained: Number(apGained) || 0,
      pushOfferEligible: Boolean(pushOfferEligible),
      winNumber: Number(winNumber) || 0
    }
    console.log("[lp-push-offer-debug] push-offer#onCelebrate", detail)

    if (!detail.pushOfferEligible) {
      console.log("[lp-push-offer-debug] push-offer#onCelebrate skip: pushOfferEligible is false")
      return
    }
    if (!detail.celebrate && !(detail.apGained > 0)) {
      console.log("[lp-push-offer-debug] push-offer#onCelebrate skip: no celebrate and no AP")
      return
    }

    console.log("[lp-push-offer-debug] push-offer#onCelebrate scheduling prepareOffer in 1400ms")
    window.setTimeout(() => this.prepareOffer(), 1400)
  }

  async prepareOffer() {
    console.log("[lp-push-offer-debug] push-offer#prepareOffer start")
    const state = await getPushSubscriptionState()
    console.log("[lp-push-offer-debug] push-offer#prepareOffer subscription state", state)

    if (state.subscribed) {
      console.log("[lp-push-offer-debug] push-offer#prepareOffer skip: already subscribed in browser")
      return
    }
    if (state.permission === "denied") {
      console.log("[lp-push-offer-debug] push-offer#prepareOffer skip: Notification.permission denied")
      return
    }

    console.log("[lp-push-offer-debug] push-offer#prepareOffer rendering card")
    this.renderCard()
  }

  renderCard() {
    const host = this.element
    host.hidden = false
    host.innerHTML = ""

    const card = document.createElement("div")
    card.className = "lp-push-offer"
    card.setAttribute("role", "dialog")
    card.setAttribute("aria-live", "polite")

    const iosInstallNeeded = isIos() && !isStandalonePwa() && !canEnablePushHere()
    const unsupported = !canEnablePushHere() && !iosInstallNeeded

    const headline = document.createElement("p")
    headline.className = "lp-push-offer__headline"
    headline.textContent = iosInstallNeeded
      ? this.iosHeadlineValue
      : (unsupported ? this.unsupportedMessageValue : this.headlineValue)
    card.appendChild(headline)

    if (iosInstallNeeded && this.iosBodyValue) {
      const body = document.createElement("p")
      body.className = "lp-push-offer__body"
      body.textContent = this.iosBodyValue
      card.appendChild(body)
    }

    const actions = document.createElement("div")
    actions.className = "lp-push-offer__actions"

    if (!unsupported) {
      const yes = document.createElement("button")
      yes.type = "button"
      yes.className = "lp-cta lp-push-offer__yes"
      yes.textContent = iosInstallNeeded ? this.iosInstallLabelValue : this.yesLabelValue
      yes.addEventListener("click", (event) => {
        if (iosInstallNeeded) this.install(event)
        else this.enable(event)
      })
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

      this.hideCard()
    } catch (error) {
      console.error(error)
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
      this.hideCard()
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
