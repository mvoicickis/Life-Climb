import { Controller } from "@hotwired/stimulus"
import { syncAppBadge } from "app_badge"
import { burst, consumeTapBurst, sound } from "lib/lp_feedback"

// Subtle juice for Complete Battle — confetti, ring close, AP float, camp nudge.
export default class extends Controller {
  static targets = ["completeBtn", "reward", "goalPct", "goalBar", "item", "lpTotal", "momentum", "ring", "campArt"]
  static values = {
    closer: Number,
    celebrate: Boolean,
    apGained: Number,
    boss: Boolean,
    winNumber: Number,
    pushOfferEligible: Boolean,
    openCount: Number
  }

  connect() {
    syncAppBadge(this.openCountValue)
    this._streamCelebrateHandler = (event) => {
      if (event.detail?.source === this) return
      this.triggerWin(event.detail || {}, { dispatch: false })
    }
    document.addEventListener("battle-day:celebrate", this._streamCelebrateHandler)

    // Click-time juicy_feedback already celebrated battle Win — skip reload juice.
    let suppress = false
    try {
      suppress = window.sessionStorage.getItem("lpJuicySuppressCelebrate") === "1"
      if (suppress) window.sessionStorage.removeItem("lpJuicySuppressCelebrate")
    } catch (_err) {
      suppress = false
    }

    if (!suppress && (this.celebrateValue || this.apGainedValue > 0)) {
      this.triggerWin({
        celebrate: this.celebrateValue,
        apGained: this.apGainedValue,
        boss: this.bossValue,
        winNumber: this.winNumberValue,
        pushOfferEligible: this.pushOfferEligibleValue
      })
    }
  }

  disconnect() {
    document.removeEventListener("battle-day:celebrate", this._streamCelebrateHandler)
  }

  triggerWin(
    {
      celebrate = false,
      apGained = 0,
      boss = false,
      winNumber = 0,
      pushOfferEligible = false
    } = {},
    { dispatch = true } = {}
  ) {
    const detail = {
      celebrate: Boolean(celebrate),
      apGained: Number(apGained) || 0,
      boss: Boolean(boss),
      winNumber: Number(winNumber) || 0,
      pushOfferEligible: Boolean(pushOfferEligible),
      dispatch
    }

    if (!detail.celebrate && !(detail.apGained > 0)) return

    this.celebrateValue = detail.celebrate
    this.apGainedValue = detail.apGained
    this.bossValue = detail.boss
    this.winNumberValue = detail.winNumber
    this.pushOfferEligibleValue = detail.pushOfferEligible

    if (dispatch) {
      document.dispatchEvent(
        new CustomEvent("battle-day:celebrate", {
          detail: {
            source: this,
            celebrate: this.celebrateValue,
            apGained: this.apGainedValue,
            boss: this.bossValue,
            winNumber: this.winNumberValue,
            pushOfferEligible: this.pushOfferEligibleValue
          }
        })
      )
    }

    window.requestAnimationFrame(() => this.celebrate())
  }

  celebrate() {
    this.element.classList.add("is-celebrating")
    if (this.bossValue) this.element.classList.add("is-boss")
    const tapBurst = consumeTapBurst()
    if (!tapBurst) burst(this.element, { density: "dash", boss: this.bossValue })
    this.nudgeReward()
    this.nudgeGoal()
    this.closeRing()
    this.nudgeCamp()
    this.floatAp()
    sound(this.bossValue ? "win_boss" : "win", { boss: this.bossValue })
    window.setTimeout(() => {
      this.element.classList.remove("is-celebrating", "is-boss")
    }, this.bossValue ? 1800 : 1400)
  }

  closeRing() {
    if (!this.hasRingTarget) return
    this.ringTarget.classList.add("is-closing")
    window.setTimeout(() => this.ringTarget.classList.remove("is-closing"), 900)
  }

  nudgeCamp() {
    if (!this.hasCampArtTarget) return
    this.campArtTarget.classList.add("is-nudge")
    window.setTimeout(() => this.campArtTarget.classList.remove("is-nudge"), 800)
  }

  floatAp() {
    if (this.apGainedValue <= 0) return
    const host = this.hasLpTotalTarget ? this.lpTotalTarget.parentElement : this.element
    const chip = document.createElement("span")
    chip.className = "lp-dash__ap-float"
    chip.textContent = `+${this.apGainedValue} Battle strength`
    host.appendChild(chip)
    window.setTimeout(() => chip.remove(), 1200)
  }

  nudgeReward() {
    if (!this.hasRewardTarget) return
    this.rewardTarget.classList.add("is-pulse")
    window.setTimeout(() => this.rewardTarget.classList.remove("is-pulse"), 900)
  }

  nudgeGoal() {
    if (!this.hasGoalBarTarget) return
    this.goalBarTarget.classList.add("is-glow", "is-bounce")
    if (this.hasGoalPctTarget) this.goalPctTarget.classList.add("is-glow")
    if (this.hasMomentumTarget) this.momentumTarget.classList.add("is-glow")
    window.setTimeout(() => {
      this.goalBarTarget.classList.remove("is-glow", "is-bounce")
      this.goalPctTarget?.classList.remove("is-glow")
      this.momentumTarget?.classList.remove("is-glow")
    }, 900)
  }
}
