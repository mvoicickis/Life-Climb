import { Controller } from "@hotwired/stimulus"
import { canPrompt, ensureCapture, isStandalonePwa, promptInstall } from "pwa_install_prompt"
import { detectedBrowserTimeZone } from "browser_timezone"
import {
  canEnablePushHere,
  completePushSubscription,
  enablePushSubscription,
  getPushSubscriptionState,
  isIos,
  prefetchPushResources,
  requestNotificationPermission
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
    goalLabel: String,
    goalTitle: String,
    reminderLine: String,
    showOnConnect: Boolean,
    compact: Boolean,
    showNotNow: { type: Boolean, default: true },
    markShownOnDisplay: Boolean,
    countShowDay: { type: Boolean, default: true },
    campSheet: Boolean,
    source: { type: String, default: "today" },
    yesLabel: String,
    notNowLabel: String,
    iosHeadline: String,
    iosBody: String,
    iosSteps: String,
    iosInstallLabel: String,
    unsupportedMessage: String,
    notSavedMessage: String,
    settingsLinkLabel: String,
    mountainLabel: String,
    mountainLine: String,
    mountainYes: String,
    mountainDone: String
  }

  connect() {
    ensureCapture()
    this._enabling = false
    this._displayMarked = false
    this._prefetchRegistration = null
    this._prefetchPublicKey = null
    this._doneTimer = null
    this._celebrateHandler = (event) => this.onCelebrate(event.detail || {})
    document.addEventListener("battle-day:celebrate", this._celebrateHandler)
    this.syncPushEndpointFields()
    this.syncStandaloneSubscription()
    if (this.showOnConnectValue) {
      this.prepareOffer()
    }
  }

  disconnect() {
    document.removeEventListener("battle-day:celebrate", this._celebrateHandler)
    this.clearDoneTimer()
    this.setPushOfferOpen(false)
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
        subscribeUrl: this.offerUrl(this.subscribeUrlValue),
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

  async prefetchForOffer() {
    if (!canEnablePushHere()) return
    if (this._prefetchRegistration && this._prefetchPublicKey) return

    try {
      const { registration, publicKey } = await prefetchPushResources(this.vapidUrlValue)
      this._prefetchRegistration = registration
      this._prefetchPublicKey = publicKey
    } catch (error) {
      console.error(error)
    }
  }

  async prepareOffer() {
    const state = await getPushSubscriptionState()

    if (state.subscribed) {
      console.info("[PushOffer] skip", "subscribed")
      return
    }
    if (state.permission === "denied") {
      console.info("[PushOffer] skip", "denied")
      return
    }

    await this.prefetchForOffer()

    if (this.campSheetValue) {
      const mode = this.cardMode()
      if (mode === "ios_install") {
        console.info("[PushOffer] skip", "ios")
        return
      }
      if (mode === "unsupported") {
        console.info("[PushOffer] skip", "unsupported")
        return
      }
      if (mode === "remind" && !this._prefetchPublicKey) {
        console.info("[PushOffer] skip", "no_vapid")
        return
      }
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

  finishRoot() {
    return this.element.closest(".lp-trail-camp-finish")
  }

  setPushOfferOpen(open) {
    const root = this.finishRoot()
    if (!root) return
    root.classList.toggle("is-push-offer-open", Boolean(open))
  }

  clearDoneTimer() {
    if (this._doneTimer) {
      window.clearTimeout(this._doneTimer)
      this._doneTimer = null
    }
  }

  renderCard() {
    if (this.campSheetValue) {
      this.renderCampSheetCard()
      return
    }

    const host = this.element
    host.hidden = false
    host.innerHTML = ""

    const mode = this.cardMode()
    const quiet = this.compactValue
    const rowLayout = quiet

    const error = document.createElement("p")
    error.className = "lp-push-offer__error"
    error.hidden = true
    error.setAttribute("role", "alert")
    this.errorElement = error

    if (mode === "ios_install") {
      this.appendIosInstallCard(host, quiet, error)
      this.markShownIfNeeded()
      return
    }

    const card = document.createElement("div")
    card.className = rowLayout
      ? "lp-push-offer lp-push-offer--quiet lp-push-offer--row"
      : quiet
        ? "lp-push-offer lp-push-offer--quiet"
        : "lp-push-offer"
    card.setAttribute("role", "dialog")
    card.setAttribute("aria-live", "polite")

    if (rowLayout) {
      const row = document.createElement("div")
      row.className = "lp-push-offer__row"

      const copy = document.createElement("p")
      copy.className = "lp-push-offer__headline"
      if (mode === "unsupported") {
        copy.textContent = this.unsupportedMessageValue
      } else {
        copy.textContent = this.reminderLineValue || this.headlineValue
      }
      row.appendChild(copy)

      const actions = document.createElement("div")
      actions.className = "lp-push-offer__actions lp-push-offer__actions--row"

      if (mode !== "unsupported") {
        const yes = document.createElement("button")
        yes.type = "button"
        yes.className = "lp-push-offer__yes lp-push-offer__yes--quiet"
        yes.textContent = this.yesLabelValue
        yes.addEventListener("click", (event) => this.enable(event))
        actions.appendChild(yes)
        this.yesButton = yes
      } else if (this.settingsUrlValue) {
        const settings = document.createElement("a")
        settings.className = "lp-push-offer__yes lp-push-offer__yes--quiet"
        settings.href = this.settingsUrlValue
        settings.textContent = this.settingsLinkLabelValue || "Settings"
        actions.appendChild(settings)
      }

      row.appendChild(actions)
      card.appendChild(row)
    } else {
      if (mode === "unsupported") {
        const headline = document.createElement("p")
        headline.className = "lp-push-offer__headline"
        headline.textContent = this.unsupportedMessageValue
        card.appendChild(headline)
      } else {
        const goalTitle = (this.goalTitleValue || "").trim()
        if (goalTitle) {
          const label = document.createElement("p")
          label.className = "lp-push-offer__goal-label"
          label.textContent = this.goalLabelValue || "Your goal"
          card.appendChild(label)

          const title = document.createElement("p")
          title.className = "lp-push-offer__goal-title"
          title.textContent = goalTitle
          card.appendChild(title)

          const reminder = document.createElement("p")
          reminder.className = "lp-push-offer__headline is-subline"
          reminder.textContent = this.reminderLineValue || this.headlineValue
          card.appendChild(reminder)
        } else {
          const headline = document.createElement("p")
          headline.className = "lp-push-offer__headline"
          headline.textContent = this.headlineValue
          card.appendChild(headline)
        }
      }

      const actions = document.createElement("div")
      actions.className = "lp-push-offer__actions"

      if (mode !== "unsupported") {
        const yes = document.createElement("button")
        yes.type = "button"
        yes.className = "lp-cta lp-push-offer__yes"
        yes.textContent = this.yesLabelValue
        yes.addEventListener("click", (event) => this.enable(event))
        actions.appendChild(yes)
        this.yesButton = yes
      } else if (this.settingsUrlValue) {
        const settings = document.createElement("a")
        settings.className = "lp-cta lp-push-offer__yes"
        settings.href = this.settingsUrlValue
        settings.textContent = this.settingsLinkLabelValue || "Settings"
        actions.appendChild(settings)
      }

      if (this.showNotNowValue) {
        const notNow = document.createElement("button")
        notNow.type = "button"
        notNow.className = "lp-push-offer__not-now"
        notNow.textContent = this.notNowLabelValue
        notNow.addEventListener("click", (event) => this.dismiss(event))
        actions.appendChild(notNow)
      }

      card.appendChild(actions)
    }

    card.appendChild(error)
    host.appendChild(card)
    this.cardElement = card

    this.markShownIfNeeded()
  }

  renderCampSheetCard() {
    const host = this.element
    host.hidden = false
    host.innerHTML = ""

    const error = document.createElement("p")
    error.className = "lp-push-offer__error"
    error.hidden = true
    error.setAttribute("role", "alert")
    this.errorElement = error

    const card = document.createElement("div")
    card.className = "lp-push-offer is-mountain-reminder is-enter"
    card.setAttribute("role", "dialog")
    card.setAttribute("aria-live", "polite")

    const label = document.createElement("p")
    label.className = "lp-push-offer__goal-label"
    label.textContent = this.mountainLabelValue || "The mountain is yours to climb:"
    card.appendChild(label)

    const goalTitle = (this.goalTitleValue || "").trim()
    if (goalTitle) {
      const title = document.createElement("p")
      title.className = "lp-push-offer__goal-title is-mountain"
      title.textContent = goalTitle
      card.appendChild(title)
    }

    const ask = document.createElement("div")
    ask.className = "lp-push-offer__ask"

    const line = document.createElement("p")
    line.className = "lp-push-offer__body is-mountain-line"
    line.textContent = this.mountainLineValue || "One small step each day gets you there."
    ask.appendChild(line)

    const yes = document.createElement("button")
    yes.type = "button"
    yes.className = "lp-push-offer__yes is-mountain-yes"
    const bell = document.createElement("span")
    bell.className = "lp-push-offer__bell-inline"
    bell.setAttribute("aria-hidden", "true")
    bell.innerHTML =
      '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M6.5 10.5a5.5 5.5 0 0 1 11 0c0 4 1.5 5.5 1.5 5.5H5s1.5-1.5 1.5-5.5Z"/><path d="M10 17.5a2 2 0 0 0 4 0"/></svg>'
    yes.appendChild(bell)
    const yesText = document.createElement("span")
    yesText.textContent = this.mountainYesValue || "Remind me tomorrow"
    yes.appendChild(yesText)
    yes.addEventListener("click", (event) => this.enable(event))
    ask.appendChild(yes)
    this.yesButton = yes

    card.appendChild(ask)
    card.appendChild(error)
    host.appendChild(card)
    this.cardElement = card
    this.askElement = ask

    this.setPushOfferOpen(true)
    this.markShownIfNeeded()
  }

  showCampSheetDone() {
    if (!this.cardElement) return

    if (this.askElement) {
      this.askElement.remove()
      this.askElement = null
    }
    this.yesButton = null

    const done = document.createElement("p")
    done.className = "lp-push-offer__done is-pop"
    const raw = (this.mountainDoneValue || "Reminders on ✓").trim()
    const tickIndex = raw.lastIndexOf("✓")
    if (tickIndex >= 0) {
      done.appendChild(document.createTextNode(raw.slice(0, tickIndex)))
      const tick = document.createElement("span")
      tick.className = "lp-push-offer__done-tick"
      tick.setAttribute("aria-hidden", "true")
      tick.textContent = "✓"
      done.appendChild(tick)
      if (tickIndex + 1 < raw.length) {
        done.appendChild(document.createTextNode(raw.slice(tickIndex + 1)))
      }
    } else {
      done.textContent = raw
    }
    this.cardElement.appendChild(done)

    this.clearDoneTimer()
    this._doneTimer = window.setTimeout(() => {
      if (this.cardElement) this.cardElement.classList.add("is-fade-out")
      this._doneTimer = window.setTimeout(() => {
        this._doneTimer = null
        this.hideCard()
      }, 450)
    }, 2000)
  }

  appendIosInstallCard(host, quiet, error) {
    const card = document.createElement("div")
    card.className = quiet ? "lp-push-offer lp-push-offer--quiet" : "lp-push-offer"
    card.setAttribute("role", "dialog")
    card.setAttribute("aria-live", "polite")

    const headline = document.createElement("p")
    headline.className = "lp-push-offer__headline"
    headline.textContent = this.iosHeadlineValue
    card.appendChild(headline)

    const steps = (this.iosStepsValue || "").trim()
    if (steps) {
      const body = document.createElement("p")
      body.className = "lp-push-offer__body"
      body.textContent = steps
      card.appendChild(body)
    }

    card.appendChild(error)
    host.appendChild(card)
    this.cardElement = card
  }

  markShownIfNeeded() {
    if (this.markShownOnDisplayValue && !this._displayMarked) {
      this._displayMarked = true
      this.markShown()
    }
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

  offerSource() {
    const value = (this.sourceValue || "").trim()
    if (value === "camp_sheet" || value === "today") return value
    return this.campSheetValue ? "camp_sheet" : "today"
  }

  offerUrl(url) {
    if (!url) return url

    const params = new URLSearchParams()
    params.set("source", this.offerSource())
    if (!this.countShowDayValue) params.set("count_show_day", "false")

    const separator = url.includes("?") ? "&" : "?"
    return `${url}${separator}${params.toString()}`
  }

  async fetchPatchOk(url) {
    const response = await fetch(url, {
      method: "PATCH",
      credentials: "same-origin",
      headers: {
        Accept: "application/json",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content || ""
      }
    })
    if (!response.ok) throw new Error("Request failed")
  }

  async fetchDeleteOk(url) {
    const response = await fetch(url, {
      method: "DELETE",
      credentials: "same-origin",
      headers: {
        Accept: "application/json",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content || ""
      }
    })
    if (!response.ok) throw new Error("Request failed")
  }

  markShown() {
    if (!this.shownUrlValue) return Promise.resolve()

    return this.fetchPatchOk(this.offerUrl(this.shownUrlValue)).catch(() => {
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
      const permission = await requestNotificationPermission()

      if (permission !== "granted") {
        if (permission === "denied") {
          try {
            await this.fetchPatchOk(this.offerUrl(this.deniedUrlValue))
          } catch (error) {
            console.error(error)
          }
          this.hideCard()
        }
        return
      }

      let registration = this._prefetchRegistration
      let publicKey = this._prefetchPublicKey
      if (!registration || !publicKey) {
        const loaded = await prefetchPushResources(this.vapidUrlValue)
        registration = loaded.registration
        publicKey = loaded.publicKey
      }

      await completePushSubscription({
        registration,
        publicKey,
        subscribeUrl: this.offerUrl(this.subscribeUrlValue),
        timeZone: detectedBrowserTimeZone()
      })

      await this.syncPushEndpointFields()
      await this.markShown()

      if (this.campSheetValue) {
        this.showCampSheetDone()
      } else {
        this.hideCard()
      }
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
        await this.fetchDeleteOk(this.offerUrl(this.dismissUrlValue))
      }
    } catch (error) {
      console.error(error)
      this.showNotSavedError()
      return
    }

    this.hideCard()
  }

  async markDenied() {
    if (!this.deniedUrlValue) return

    try {
      await this.fetchPatchOk(this.offerUrl(this.deniedUrlValue))
    } catch (error) {
      console.error(error)
    }
  }

  hideCard() {
    this.clearDoneTimer()
    this.setPushOfferOpen(false)
    this.element.hidden = true
    this.element.innerHTML = ""
    this.cardElement = null
    this.askElement = null
    this.yesButton = null
    this.errorElement = null
  }
}
