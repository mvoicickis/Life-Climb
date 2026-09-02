import { Controller } from "@hotwired/stimulus"

// Subtle juice for Complete Battle — confetti, ring close, AP float, camp nudge.
export default class extends Controller {
  static targets = ["completeBtn", "reward", "goalPct", "goalBar", "item", "lpTotal", "momentum", "ring", "campArt"]
  static values = {
    closer: Number,
    celebrate: Boolean,
    apGained: Number,
    boss: Boolean,
    winNumber: Number,
    pushOfferEligible: Boolean
  }

  connect() {
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
      console.log("[lp-push-offer-debug] battle-day#connect page-load celebrate", {
        celebrate: this.celebrateValue,
        apGained: this.apGainedValue,
        boss: this.bossValue,
        winNumber: this.winNumberValue,
        pushOfferEligible: this.pushOfferEligibleValue,
        suppress
      })
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
    console.log("[lp-push-offer-debug] battle-day#triggerWin entry", detail)

    if (!detail.celebrate && !(detail.apGained > 0)) {
      console.log("[lp-push-offer-debug] battle-day#triggerWin early return (no celebrate and no AP)")
      return
    }

    this.celebrateValue = detail.celebrate
    this.apGainedValue = detail.apGained
    this.bossValue = detail.boss
    this.winNumberValue = detail.winNumber
    this.pushOfferEligibleValue = detail.pushOfferEligible

    if (dispatch) {
      const eventDetail = {
        source: this,
        celebrate: this.celebrateValue,
        apGained: this.apGainedValue,
        boss: this.bossValue,
        winNumber: this.winNumberValue,
        pushOfferEligible: this.pushOfferEligibleValue
      }
      console.log("[lp-push-offer-debug] battle-day#triggerWin dispatch battle-day:celebrate", eventDetail)
      document.dispatchEvent(
        new CustomEvent("battle-day:celebrate", {
          detail: eventDetail
        })
      )
    } else {
      console.log("[lp-push-offer-debug] battle-day#triggerWin skip dispatch (stream replay)")
    }

    window.requestAnimationFrame(() => this.celebrate())
  }

  celebrate() {
    this.element.classList.add("is-celebrating")
    if (this.bossValue) this.element.classList.add("is-boss")
    this.burst()
    this.nudgeReward()
    this.nudgeGoal()
    this.closeRing()
    this.nudgeCamp()
    this.floatAp()
    this.chime()
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
    chip.textContent = `+${this.apGainedValue} AP`
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

  burst() {
    const root = document.createElement("div")
    root.className = this.bossValue ? "lp-dash-confetti is-boss" : "lp-dash-confetti"
    root.setAttribute("aria-hidden", "true")
    const count = this.bossValue ? 28 : 18
    for (let i = 0; i < count; i += 1) {
      const bit = document.createElement("span")
      bit.style.setProperty("--x", `${(Math.random() * 180) - 90}px`)
      bit.style.setProperty("--d", `${420 + Math.random() * 780}ms`)
      bit.style.setProperty("--h", `${85 + Math.random() * 45}`)
      root.appendChild(bit)
    }
    this.element.appendChild(root)
    window.setTimeout(() => root.remove(), 1300)
  }

  chime() {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return
    try {
      const Ctx = window.AudioContext || window.webkitAudioContext
      if (!Ctx) return
      const ctx = new Ctx()
      const osc = ctx.createOscillator()
      const gain = ctx.createGain()
      osc.type = "triangle"
      osc.frequency.value = this.bossValue ? 587.33 : 440
      gain.gain.value = 0.0001
      osc.connect(gain)
      gain.connect(ctx.destination)
      const now = ctx.currentTime
      gain.gain.exponentialRampToValueAtTime(0.04, now + 0.02)
      gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.25)
      osc.start(now)
      osc.stop(now + 0.28)
      window.setTimeout(() => ctx.close(), 400)
    } catch (_err) {
      // optional
    }
  }
}
