import { Controller } from "@hotwired/stimulus"
import {
  bump,
  retry,
  subscribe,
  formatAmount,
  habitProgressSegments,
  habitTodayRowState,
  ROW_STATE_CLASSES
} from "lib/basic_today_save_queue"

export default class extends Controller {
  static targets = [
    "amountSpan",
    "metaPrimary",
    "metaOver",
    "pct",
    "segs",
    "saveNotice"
  ]

  static values = {
    habitId: Number,
    amount: Number,
    quick: Number,
    goal: Number,
    stretchGoal: Boolean,
    setUrl: String,
    unit: String,
    target: Number,
    amountOfTargetFormat: String,
    overByFormat: String,
    winNotSaved: String,
    metaId: String,
    todayId: String,
    showPct: Boolean
  }

  connect() {
    this.unsubscribe = subscribe(this.habitIdValue, (state) => this.onQueue(state), {
      amount: this.amountValue,
      setUrl: this.setUrlValue
    })
    this.prefersReducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches
  }

  disconnect() {
    this.unsubscribe?.()
  }

  addQuick(event) {
    event.preventDefault()
    bump(this.habitIdValue, this.quickValue, { debounceMs: 400, setUrl: this.setUrlValue })
    const popEl = this.popTarget()
    if (!this.prefersReducedMotion && popEl) {
      popEl.classList.remove("is-total-pop")
      void popEl.offsetWidth
      popEl.classList.add("is-total-pop")
    }
    navigator.vibrate?.(10)
  }

  retrySave(event) {
    event.preventDefault()
    retry(this.habitIdValue)
  }

  onQueue(state) {
    this.paintRow(state.localTotal)
    if (state.failed) this.showNotice()
    else this.hideNotice()
    if (!state.inFlight && state.localTotal === state.confirmedTotal && !state.failed) {
      this.syncRowStateFromMeta()
    }
  }

  paintRow(amount) {
    this.updateMeta(amount)
    this.updateSegs(amount)
    this.updateRowClasses(amount)
  }

  updateMeta(amount) {
    const num = Number(amount)
    const zero = !Number.isFinite(num) || num <= 0

    if (this.stretchGoalValue && this.targetValue > 0 && !zero) {
      if (this.hasMetaPrimaryTarget) {
        this.metaPrimaryTarget.hidden = false
        this.metaPrimaryTarget.textContent = this.interpolate(this.amountOfTargetFormatValue, {
          amount: formatAmount(num),
          target: formatAmount(this.targetValue),
          unit: this.unitValue
        })
      }
      if (this.hasMetaOverTarget) {
        const over = num > this.targetValue
        this.metaOverTarget.hidden = !over
        if (over) {
          this.metaOverTarget.textContent = ` · ${this.interpolate(this.overByFormatValue, {
            amount: formatAmount(num - this.targetValue)
          })}`
        }
      }
      if (this.hasAmountSpanTarget) this.amountSpanTarget.textContent = formatAmount(num)
    } else if (!this.stretchGoalValue && !zero) {
      if (this.hasMetaPrimaryTarget) this.metaPrimaryTarget.hidden = true
      if (this.hasMetaOverTarget) this.metaOverTarget.hidden = true
      if (this.hasAmountSpanTarget) this.amountSpanTarget.textContent = formatAmount(num)
    } else {
      if (this.hasMetaPrimaryTarget) this.metaPrimaryTarget.hidden = true
      if (this.hasMetaOverTarget) this.metaOverTarget.hidden = true
      if (this.hasAmountSpanTarget && zero) this.amountSpanTarget.textContent = formatAmount(0)
    }

    if (this.showPctValue && this.hasPctTarget && this.stretchGoalValue && this.goalValue > 0) {
      const progress = Math.round((num / this.goalValue) * 100)
      this.pctTarget.textContent = `${progress}%`
      this.pctTarget.classList.toggle("is-zero", num <= 0)
    }
  }

  updateSegs(amount) {
    if (!this.hasSegsTarget) return
    const goal = this.goalValue
    if (!this.stretchGoalValue || goal <= 0) return
    const progress = Math.round((Number(amount) / goal) * 100)
    const classes = habitProgressSegments(progress, 16)
    this.segsTarget.innerHTML = classes.map((klass) => `<i class="${klass}"></i>`).join("")
  }

  updateRowClasses(amount) {
    const row = this.element
    const metGoal = this.stretchGoalValue && this.goalValue > 0 && Number(amount) >= this.goalValue
    const state = habitTodayRowState({
      amount: Number(amount),
      goal: this.goalValue,
      stretchGoal: this.stretchGoalValue,
      metGoal
    })
    ROW_STATE_CLASSES.forEach((klass) => row.classList.remove(klass))
    state.split(/\s+/).filter(Boolean).forEach((klass) => row.classList.add(klass))
  }

  syncRowStateFromMeta() {
    const meta = document.getElementById(this.metaIdValue)
    const row = document.getElementById(this.todayIdValue)
    if (!meta || !row) return
    const state = meta.dataset.basicRowState || ""
    ROW_STATE_CLASSES.forEach((klass) => row.classList.remove(klass))
    state.split(/\s+/).filter(Boolean).forEach((klass) => row.classList.add(klass))
  }

  showNotice() {
    if (!this.hasSaveNoticeTarget) return
    this.saveNoticeTarget.hidden = false
    this.element.classList.add("has-win-save-notice")
  }

  hideNotice() {
    if (!this.hasSaveNoticeTarget) return
    this.saveNoticeTarget.hidden = true
    this.element.classList.remove("has-win-save-notice")
  }

  popTarget() {
    if (this.hasAmountSpanTarget && !this.amountSpanTarget.hidden) return this.amountSpanTarget
    if (this.hasMetaPrimaryTarget && !this.metaPrimaryTarget.hidden) return this.metaPrimaryTarget
    return null
  }

  interpolate(template, vars) {
    let out = String(template ?? "")
    Object.entries(vars).forEach(([key, value]) => {
      out = out.replaceAll(`%{${key}}`, value)
    })
    return out
  }
}
