import { Controller } from "@hotwired/stimulus"
import { attachTitleLimit } from "lib/title_limit"

// Mountain terraced trail: FAB opens composer, camps land on stage ledges.
export default class extends Controller {
  static targets = [
    "surface",
    "mountain",
    "scroll",
    "camps",
    "plantForm",
    "plantTitle",
    "plantDescription",
    "plantSubmit",
    "newTerraceStage",
    "plantError",
    "peakMenu",
    "advanced",
    "metricFields",
    "metricFollow",
    "trackQuantity",
    "wantTargetBtn",
    "skipTargetBtn",
    "logSheet",
    "logProjectId",
    "logBattleId",
    "logTitle",
    "logPrompt",
    "logAmount",
    "logQuick",
    "logVerdict",
    "accentHex",
    "campMode",
    "peakTitle",
    "peakTitleInput",
    "peakPlaque",
    "clouds"
  ]

  static values = {
    createUrl: String,
    journeyId: Number,
    planId: Number,
    lifeAreaId: Number,
    goalId: Number,
    goalUpdateUrl: String,
    csrf: String,
    curve: { type: Array, default: [] },
    quantityLogUrl: String,
    atMaxTemplate: { type: String, default: "%{count} of %{max} letters used" },
    plantFailed: String
  }

  connect() {
    this._logContext = null
    this._editingTitle = false
    this._goalTitlePrevious = ""
    this._peakMenuDismissBound = false
    this._plantFromArrange = false
    this.bindFab()
    this.bindScrollParallax()
    this.syncAccentFromSwatch()
    this.bindGoalTitleInput()
    this.bindPlantEscape()
  }

  disconnect() {
    this.unbindFab()
    this.unbindScrollParallax()
    this.unbindPeakMenuDismiss()
    this.teardownGoalTitleEdit()
    this.unbindPlantEscape()
  }

  bindFab() {
    this._fabHandler = (event) => {
      const fab = event.target.closest(".lp-dash-nav__fab")
      if (!fab) return
      event.preventDefault()
      this.openComposerFromFab(event)
    }
    document.addEventListener("click", this._fabHandler)
  }

  unbindFab() {
    if (this._fabHandler) document.removeEventListener("click", this._fabHandler)
  }

  openComposerFromFab(event) {
    event?.preventDefault()
    event?.stopPropagation()
    this.openPlant()
  }

  openPlantFromArrange() {
    this._plantFromArrange = true
    if (this.hasNewTerraceStageTarget) this.newTerraceStageTarget.value = "1"
    this.openPlant({ syncFocus: true })
  }

  isPlantOpen() {
    return this.hasPlantFormTarget && this.plantFormTarget.classList.contains("is-open")
  }

  bindPlantEscape() {
    this._plantEscapeHandler = (event) => {
      if (event.key !== "Escape") return
      if (!this.isPlantOpen()) return
      event.preventDefault()
      event.stopPropagation()
      this.closePlant(event)
    }
    window.addEventListener("keydown", this._plantEscapeHandler, true)
  }

  unbindPlantEscape() {
    if (this._plantEscapeHandler) {
      window.removeEventListener("keydown", this._plantEscapeHandler, true)
    }
  }

  campClick(_event) {
    // Camp sheet opens via trail-camp-sheet controller.
  }

  closePlant(event) {
    event?.preventDefault()
    event?.stopPropagation()
    this.hidePlant()
  }

  stop(event) {
    event.stopPropagation()
  }

  toggleGoalMenu(event) {
    if (this._editingTitle) return
    this.togglePeakMenu(event)
  }

  togglePeakMenu(event) {
    event?.preventDefault()
    event?.stopPropagation()
    if (!this.hasPeakMenuTarget || this._editingTitle) return
    const open = this.peakMenuTarget.hasAttribute("hidden")
    if (open) {
      this.openPeakMenu(event?.currentTarget)
    } else {
      this.closePeakMenu(event?.currentTarget)
    }
  }

  openPeakMenu(plaqueButton = null) {
    if (!this.hasPeakMenuTarget) return
    this.peakMenuTarget.hidden = false
    this.peakMenuTarget.removeAttribute("hidden")
    const plaque = plaqueButton || (this.hasPeakPlaqueTarget ? this.peakPlaqueTarget : null)
    plaque?.setAttribute("aria-expanded", "true")
    this.bindPeakMenuDismiss()
  }

  closePeakMenu(plaqueButton = null) {
    if (!this.hasPeakMenuTarget) return
    this.peakMenuTarget.hidden = true
    this.peakMenuTarget.setAttribute("hidden", "")
    const plaque = plaqueButton || (this.hasPeakPlaqueTarget ? this.peakPlaqueTarget : null)
    plaque?.setAttribute("aria-expanded", "false")
    this.unbindPeakMenuDismiss()
  }

  bindPeakMenuDismiss() {
    if (this._peakMenuDismissBound) return
    this._onPeakMenuPointer = (event) => this.onPeakMenuPointerDown(event)
    this._onPeakMenuKey = (event) => this.onPeakMenuKeydown(event)
    document.addEventListener("pointerdown", this._onPeakMenuPointer)
    document.addEventListener("mousedown", this._onPeakMenuPointer)
    document.addEventListener("keydown", this._onPeakMenuKey)
    this._peakMenuDismissBound = true
  }

  unbindPeakMenuDismiss() {
    if (!this._peakMenuDismissBound) return
    document.removeEventListener("pointerdown", this._onPeakMenuPointer)
    document.removeEventListener("mousedown", this._onPeakMenuPointer)
    document.removeEventListener("keydown", this._onPeakMenuKey)
    this._peakMenuDismissBound = false
  }

  peakMenuHitTarget(event) {
    const target = event.target
    if (!target?.closest) return false
    if (target.closest(".lp-trail__goal-menu")) return true
    if (target.closest(".lp-trail__goal-plaque")) return true
    if (this._editingTitle && this.hasPeakTitleInputTarget && target.closest(".lp-trail__goal-title-input")) {
      return true
    }
    return false
  }

  onPeakMenuPointerDown(event) {
    if (this.peakMenuHitTarget(event)) return
    if (this.hasPeakMenuTarget && !this.peakMenuTarget.hasAttribute("hidden") && !this.peakMenuTarget.hidden) {
      this.closePeakMenu()
    }
  }

  onPeakMenuKeydown(event) {
    if (event.key !== "Escape") return
    if (this._editingTitle) {
      event.preventDefault()
      this.cancelGoalTitleEdit()
      return
    }
    if (this.hasPeakMenuTarget && !this.peakMenuTarget.hasAttribute("hidden") && !this.peakMenuTarget.hidden) {
      event.preventDefault()
      this.closePeakMenu()
    }
  }

  editGoalNameFromMenu(event) {
    event.preventDefault()
    event.stopPropagation()
    this.closePeakMenu()
    if (!this.hasPeakTitleTarget || !this.hasPeakTitleInputTarget || !this.hasPeakPlaqueTarget) return

    this._goalTitlePrevious = (this.peakTitleTarget.textContent || "").trim()
    this.peakTitleInputTarget.value = this._goalTitlePrevious
    this._editingTitle = true
    this.peakPlaqueTarget.hidden = true
    this.peakTitleInputTarget.hidden = false
    this._titleLimit?.detach()
    this._titleLimit = attachTitleLimit(this.peakTitleInputTarget, { template: this.atMaxTemplateValue })
    this.peakTitleInputTarget.focus()
    this.peakTitleInputTarget.select()
  }

  bindGoalTitleInput() {
    if (!this.hasPeakTitleInputTarget) return
    const input = this.peakTitleInputTarget
    this._onGoalTitleBlur = () => this.onGoalTitleBlur()
    this._onGoalTitleKeydown = (event) => this.onGoalTitleKeydown(event)
    input.addEventListener("blur", this._onGoalTitleBlur)
    input.addEventListener("keydown", this._onGoalTitleKeydown)
  }

  onGoalTitleBlur() {
    if (!this._editingTitle) return
    void this.commitGoalTitleEdit()
  }

  onGoalTitleKeydown(event) {
    if (!this._editingTitle) return
    if (event.key === "Enter") {
      event.preventDefault()
      void this.commitGoalTitleEdit()
    }
    if (event.key === "Escape") {
      event.preventDefault()
      this.cancelGoalTitleEdit()
    }
  }

  async commitGoalTitleEdit() {
    if (!this._editingTitle || !this.hasPeakTitleInputTarget || !this.hasPeakTitleTarget) return

    const title = this.peakTitleInputTarget.value.trim()
    const previous = this._goalTitlePrevious

    if (!title || title === previous) {
      this.cancelGoalTitleEdit()
      return
    }

    const saved = await this.patchGoal({ title })
    if (saved) {
      this.peakTitleTarget.textContent = title
    } else {
      this.peakTitleTarget.textContent = previous
      this.peakTitleInputTarget.value = previous
    }
    this.finishGoalTitleEdit()
  }

  cancelGoalTitleEdit() {
    if (!this._editingTitle) return
    if (this.hasPeakTitleTarget) {
      this.peakTitleTarget.textContent = this._goalTitlePrevious
    }
    if (this.hasPeakTitleInputTarget) {
      this.peakTitleInputTarget.value = this._goalTitlePrevious
    }
    this.finishGoalTitleEdit()
  }

  finishGoalTitleEdit() {
    this._editingTitle = false
    this._titleLimit?.detach()
    this._titleLimit = null

    if (this.hasPeakTitleInputTarget) {
      this.peakTitleInputTarget.hidden = true
    }
    if (this.hasPeakPlaqueTarget) {
      this.peakPlaqueTarget.hidden = false
      this.peakPlaqueTarget.focus({ preventScroll: true })
    }
  }

  teardownGoalTitleEdit() {
    if (!this._editingTitle) return
    this._editingTitle = false
    this._titleLimit?.detach()
    this._titleLimit = null
    if (this.hasPeakTitleInputTarget) this.peakTitleInputTarget.hidden = true
    if (this.hasPeakPlaqueTarget) this.peakPlaqueTarget.hidden = false
  }

  async submitPlant(event) {
    event.preventDefault()
    event.stopPropagation()

    if (!this.hasPlantFormTarget) return

    const form = this.plantFormTarget
    const title = this.hasPlantTitleTarget ? this.plantTitleTarget.value.trim() : ""
    if (!title) {
      this.plantTitleTarget?.focus()
      return
    }

    const description = this.hasPlantDescriptionTarget ? this.plantDescriptionTarget.value.trim() : ""

    const color =
      form.querySelector("input[name='color_key']:checked")?.value ||
      form.querySelector("input[name='color_key']")?.value ||
      "teal"

    const quantity = this.readQuantityFields(form)

    await this.postPlant({ title, description, color, quantity })
  }

  pickStarter(event) {
    event.preventDefault()
    event.stopPropagation()
    const starter = event.currentTarget?.dataset?.starter
    if (!starter || !this.hasPlantTitleTarget) return
    this.plantTitleTarget.value = starter
    this.plantTitleTarget.focus()
  }

  toggleAdvanced(event) {
    event.preventDefault()
    event.stopPropagation()
    if (!this.hasAdvancedTarget) return
    const open = this.advancedTarget.hasAttribute("hidden")
    this.advancedTarget.toggleAttribute("hidden", !open)
    event.currentTarget?.setAttribute("aria-expanded", open ? "true" : "false")
    if (!open) this.resetMetricFlow()
  }

  pickMetricCard(event) {
    event.preventDefault()
    event.stopPropagation()
    const kind = event.currentTarget?.dataset?.metric
    const form = this.plantFormTarget
    if (!kind || !form) return

    form.querySelectorAll(".lp-trail-plant__metric-card").forEach((el) => {
      const selected = el.dataset.metric === kind
      el.classList.toggle("is-selected", selected)
      el.setAttribute("aria-pressed", selected ? "true" : "false")
    })

    const radio = form.querySelector(`input[name='quantity_kind'][value='${kind}']`)
    if (radio) {
      radio.checked = true
      this.metricKindChanged({ currentTarget: radio })
    }

    this.setMetricTracking(true)
    if (this.hasMetricFollowTarget) this.metricFollowTarget.hidden = false
    this.setTargetChoice(null)
  }

  wantTarget(event) {
    event.preventDefault()
    this.setTargetChoice(true)
  }

  skipTarget(event) {
    event.preventDefault()
    this.setTargetChoice(false)
    this.clearTargetInputs()
  }

  setTargetChoice(want) {
    this._wantTarget = want
    if (this.hasWantTargetBtnTarget) {
      this.wantTargetBtnTarget.classList.toggle("is-selected", want === true)
    }
    if (this.hasSkipTargetBtnTarget) {
      this.skipTargetBtnTarget.classList.toggle("is-selected", want === false)
    }
    if (this.hasMetricFieldsTarget) this.metricFieldsTarget.hidden = want !== true
    if (want === true) {
      const radio = this.plantFormTarget?.querySelector("input[name='quantity_kind']:checked")
      if (radio) this.metricKindChanged({ currentTarget: radio })
    }
  }

  resetMetricFlow() {
    this.setMetricTracking(false)
    this._wantTarget = null
    const form = this.plantFormTarget
    form?.querySelectorAll(".lp-trail-plant__metric-card").forEach((el) => {
      el.classList.remove("is-selected")
      el.setAttribute("aria-pressed", "false")
    })
    form?.querySelectorAll("input[name='quantity_kind']").forEach((el) => { el.checked = false })
    if (this.hasMetricFollowTarget) this.metricFollowTarget.hidden = true
    if (this.hasMetricFieldsTarget) this.metricFieldsTarget.hidden = true
    this.clearTargetInputs()
    if (this.hasWantTargetBtnTarget) this.wantTargetBtnTarget.classList.remove("is-selected")
    if (this.hasSkipTargetBtnTarget) this.skipTargetBtnTarget.classList.remove("is-selected")
  }

  clearTargetInputs() {
    const form = this.plantFormTarget
    if (!form) return
    ;["target_amount", "range_min", "range_max"].forEach((name) => {
      const input = form.querySelector(`input[name='${name}']`)
      if (input) input.value = ""
    })
  }

  setMetricTracking(on) {
    const track = this.hasTrackQuantityTarget
      ? this.trackQuantityTarget
      : this.plantFormTarget?.querySelector("input[name='track_quantity']")
    if (track) track.value = on ? "1" : "0"
  }

  colorPicked(event) {
    const hex = event.currentTarget?.dataset?.hex
    if (hex && this.hasAccentHexTarget) this.accentHexTarget.value = hex
  }

  syncAccentFromSwatch() {
    const checked = this.plantFormTarget?.querySelector("input[name='color_key']:checked")
    const hex = checked?.dataset?.hex
    if (hex && this.hasAccentHexTarget) this.accentHexTarget.value = hex
  }

  readQuantityFields(form) {
    const track = form.querySelector("input[name='track_quantity']")
    const tracked = track?.type === "checkbox" ? track.checked : track?.value === "1"
    if (!tracked) return null
    const kind = form.querySelector("input[name='quantity_kind']:checked")?.value || "up"
    const target = form.querySelector("input[name='target_amount']")?.value
    const unit = form.querySelector("input[name='unit']")?.value
    const rangeMin = form.querySelector("input[name='range_min']")?.value
    const rangeMax = form.querySelector("input[name='range_max']")?.value
    return { track: true, kind, target, unit, rangeMin, rangeMax }
  }

  metricKindChanged(event) {
    const form = event.currentTarget?.closest("form") || this.plantFormTarget
    if (!form) return
    const kind = form.querySelector("input[name='quantity_kind']:checked")?.value || "up"
    form.querySelectorAll("[data-quantity-panel]").forEach((panel) => {
      const show = kind === "range" ? panel.dataset.quantityPanel === "range" : panel.dataset.quantityPanel === "updown"
      panel.hidden = !show
    })
  }

  pickCampMode(event) {
    if (!this.hasCampModeTarget) return
    this.campModeTarget.value = event.currentTarget?.value || "battles"
    const track = this.plantFormTarget?.querySelector("input[name='track_quantity'][type='checkbox']")
    if (this.campModeTarget.value === "pages" && track) {
      track.checked = true
      track.dispatchEvent(new Event("change", { bubbles: true }))
    }
  }

  async postPlant({ title, description = "", color, quantity = null }) {
    const url = this.createUrlValue
    if (!url) return

    const body = new FormData()
    body.set("title", title)
    if (description) body.set("description", description)
    body.set("horizon", "project")
    body.set("color_key", color)
    if (this.hasAccentHexTarget && this.accentHexTarget.value) {
      body.set("accent_hex", this.accentHexTarget.value)
    }
    if (this.hasCampModeTarget) {
      body.set("camp_mode", this.campModeTarget.value || "battles")
      if (this.campModeTarget.value === "pages") {
        body.set("track_quantity", "1")
        body.set("quantity_kind", quantity?.kind || "up")
        if (quantity?.target) body.set("target_amount", String(quantity.target))
        if (quantity?.unit) body.set("unit", String(quantity.unit || "pages"))
      }
    }
    if (quantity?.track && this.campModeTarget?.value !== "pages") {
      body.set("track_quantity", "1")
      body.set("quantity_kind", quantity.kind || "up")
      if (quantity.target) body.set("target_amount", String(quantity.target))
      if (quantity.unit) body.set("unit", String(quantity.unit))
      if (quantity.rangeMin) body.set("range_min", String(quantity.rangeMin))
      if (quantity.rangeMax) body.set("range_max", String(quantity.rangeMax))
    }
    if (this._plantFromArrange) {
      body.set("new_terrace_stage", "1")
    }
    this.appendContext(body)
    const token = this.csrfToken()
    if (token) body.set("authenticity_token", token)

    const fromArrange = this._plantFromArrange

    try {
      const response = await fetch(url, {
        method: "POST",
        headers: {
          Accept: "text/vnd.turbo-stream.html, text/html, application/xhtml+xml",
          "X-CSRF-Token": token,
          "X-Requested-With": "XMLHttpRequest"
        },
        body,
        credentials: "same-origin"
      })

      const contentType = response.headers.get("content-type") || ""
      if (contentType.includes("turbo-stream") && window.Turbo?.renderStreamMessage) {
        if (!response.ok) {
          this.showPlantError(this.plantFailedValue || "Could not add camp. Try again.")
          return
        }
        window.Turbo.renderStreamMessage(await response.text())
        this.hidePlant()
        if (fromArrange) this.closeArrangeCamps()
        return
      }
      if (!response.ok) {
        this.showPlantError(this.plantFailedValue || "Could not add camp. Try again.")
        return
      }
      if (response.redirected) {
        window.location.href = response.url
        return
      }
      window.location.reload()
    } catch (_error) {
      if (fromArrange) {
        this.showPlantError(this.plantFailedValue || "Could not add camp. Try again.")
        return
      }
      window.location.reload()
    }
  }

  openLog(event) {
    event.preventDefault()
    event.stopPropagation()
    const btn = event.currentTarget
    if (!this.hasLogSheetTarget) return
    if (this.hasLogProjectIdTarget) this.logProjectIdTarget.value = btn.dataset.projectId || ""
    if (this.hasLogBattleIdTarget) this.logBattleIdTarget.value = btn.dataset.battleId || ""
    if (this.hasLogTitleTarget) {
      this.logTitleTarget.textContent =
        btn.dataset.projectTitle || this.logSheetTarget.dataset.logTitleFallback || ""
    }
    if (this.hasLogPromptTarget) {
      const unit = btn.dataset.unit || ""
      const kind = btn.dataset.quantityKind || "up"
      const min = Number.parseFloat(btn.dataset.rangeMin)
      const max = Number.parseFloat(btn.dataset.rangeMax)
      let prompt
      if (kind === "range" && Number.isFinite(min) && Number.isFinite(max)) {
        const template = unit
          ? this.logSheetTarget.dataset.logPromptHealthyRangeWithUnit
          : this.logSheetTarget.dataset.logPromptHealthyRange
        prompt = this.interpolateLogCopy(template, { min, max, unit })
      } else if (kind === "down") {
        const template = unit
          ? this.logSheetTarget.dataset.logPromptDown
          : this.logSheetTarget.dataset.logPromptDownBare
        prompt = this.interpolateLogCopy(template, { unit })
      } else {
        const template = unit
          ? this.logSheetTarget.dataset.logPromptUp
          : this.logSheetTarget.dataset.logPromptGeneric
        prompt = this.interpolateLogCopy(template, { unit })
      }
      this.logPromptTarget.textContent = prompt
      this.logPromptTarget.dataset.kind = kind
      this.logPromptTarget.dataset.rangeMin = btn.dataset.rangeMin || ""
      this.logPromptTarget.dataset.rangeMax = btn.dataset.rangeMax || ""
    }
    if (this.hasLogAmountTarget) {
      this.logAmountTarget.value = "1"
      this.logAmountTarget.readOnly = true
    }
    this._logContext = {
      kind: btn.dataset.quantityKind || "up",
      rangeMin: Number.parseFloat(btn.dataset.rangeMin),
      rangeMax: Number.parseFloat(btn.dataset.rangeMax),
      lastLog: Number.parseFloat(btn.dataset.lastLog)
    }
    this.updateLogVerdict()
    this.logSheetTarget.hidden = false
    this.logSheetTarget.setAttribute("aria-hidden", "false")
    this.logSheetTarget.classList.add("is-open")
  }

  armLogAmount(event) {
    const field = event.currentTarget
    if (!field || !field.readOnly) return
    field.readOnly = false
    field.focus()
    field.select?.()
  }

  closeLog(event) {
    event?.preventDefault()
    event?.stopPropagation()
    if (!this.hasLogSheetTarget) return
    this.logSheetTarget.hidden = true
    this.logSheetTarget.setAttribute("aria-hidden", "true")
    this.logSheetTarget.classList.remove("is-open")
    if (this.hasLogAmountTarget) this.logAmountTarget.readOnly = true
  }

  logMinus(event) {
    event.preventDefault()
    if (!this.hasLogAmountTarget) return
    const n = Number.parseFloat(this.logAmountTarget.value) || 0
    this.logAmountTarget.value = String(Math.max(0.01, Math.round((n - 1) * 100) / 100))
    this.updateLogVerdict()
  }

  logPlus(event) {
    event.preventDefault()
    if (!this.hasLogAmountTarget) return
    const n = Number.parseFloat(this.logAmountTarget.value) || 0
    this.logAmountTarget.value = String(Math.round((n + 1) * 100) / 100)
    this.updateLogVerdict()
  }

  logQuick(event) {
    event.preventDefault()
    if (!this.hasLogAmountTarget) return
    const amount = event.currentTarget?.dataset?.amount
    if (amount) this.logAmountTarget.value = amount
    this.updateLogVerdict()
  }

  logAmountInput() {
    this.updateLogVerdict()
  }

  updateLogVerdict() {
    if (!this.hasLogVerdictTarget || !this.hasLogAmountTarget || !this._logContext) return

    const val = Number.parseFloat(this.logAmountTarget.value)
    if (!Number.isFinite(val)) {
      this.logVerdictTarget.hidden = true
      return
    }

    const { kind, rangeMin, rangeMax, lastLog } = this._logContext
    let text
    let tone = "neutral"

    if (kind === "range" && Number.isFinite(rangeMin) && Number.isFinite(rangeMax)) {
      if (val < rangeMin) {
        text = this.verdictTemplate("below")
        tone = "bad"
      } else if (val > rangeMax) {
        text = this.verdictTemplate("above")
        tone = "bad"
      } else {
        text = this.verdictTemplate("in_range")
        tone = "good"
      }
    } else if (!Number.isFinite(lastLog)) {
      text = this.verdictTemplate("first")
      tone = "neutral"
    } else if (val === lastLog) {
      text = this.verdictTemplate("same", { prev: lastLog })
      tone = "warn"
    } else {
      const better = kind === "down" ? val < lastLog : val > lastLog
      text = this.verdictTemplate(better ? (kind === "down" ? "down_from" : "up_from") : (kind === "down" ? "up_from" : "down_from"), { prev: lastLog })
      tone = better ? "good" : "bad"
    }

    this.logVerdictTarget.textContent = text
    this.logVerdictTarget.dataset.tone = tone
    this.logVerdictTarget.hidden = false
  }

  verdictTemplate(key, vars = {}) {
    if (!this.hasLogSheetTarget) return ""
    const map = {
      first: "logVerdictFirst",
      in_range: "logVerdictInRange",
      below: "logVerdictBelow",
      above: "logVerdictAbove",
      same: "logVerdictSame",
      up_from: "logVerdictUpFrom",
      down_from: "logVerdictDownFrom"
    }
    const raw = this.logSheetTarget.dataset[map[key]] || ""
    return this.interpolateLogCopy(raw, vars)
  }

  interpolateLogCopy(template, vars = {}) {
    if (!template) return ""
    return template.replace(/%\{(\w+)\}/g, (_, key) => String(vars[key] ?? ""))
  }

  async submitLog(event) {
    event.preventDefault()
    event.stopPropagation()
    const form = event.currentTarget
    const url = this.quantityLogUrlValue || form.action
    if (!url) return
    const body = new FormData(form)
    const token = this.csrfToken()
    if (token) body.set("authenticity_token", token)

    try {
      const response = await fetch(url, {
        method: "POST",
        headers: {
          Accept: "text/vnd.turbo-stream.html, text/html",
          "X-CSRF-Token": token,
          "X-Requested-With": "XMLHttpRequest"
        },
        body,
        credentials: "same-origin"
      })
      const kind = response.headers.get("content-type") || ""
      if (kind.includes("turbo-stream")) {
        const html = await response.text()
        this.closeLog()
        window.Turbo.renderStreamMessage(html)
        return
      }
      if (response.redirected) {
        window.location.href = response.url
        return
      }
      window.location.reload()
    } catch (_error) {
      window.location.reload()
    }
  }

  async patchGoal(fields) {
    if (!this.goalUpdateUrlValue) return false
    const token = this.csrfToken()
    const body = new FormData()
    Object.entries(fields).forEach(([k, v]) => body.set(k, v))
    body.set("_method", "patch")
    if (token) body.set("authenticity_token", token)
    try {
      const response = await fetch(this.goalUpdateUrlValue, {
        method: "POST",
        headers: {
          Accept: "text/vnd.turbo-stream.html, text/html",
          "X-CSRF-Token": token,
          "X-Requested-With": "XMLHttpRequest"
        },
        body,
        credentials: "same-origin"
      })
      return response.ok
    } catch (_e) {
      return false
    }
  }

  bindScrollParallax() {
    if (!this.hasScrollTarget) return
    this._onScrollParallax = () => {
      if (this._parallaxRaf) return
      this._parallaxRaf = requestAnimationFrame(() => {
        this._parallaxRaf = null
        const y = this.scrollTarget.scrollTop || 0
        if (this.hasCloudsTarget) {
          this.cloudsTarget.style.transform = `translate3d(0, ${-(y * 0.32)}px, 0)`
        }
      })
    }
    this.scrollTarget.addEventListener("scroll", this._onScrollParallax, { passive: true })
  }

  unbindScrollParallax() {
    if (this.hasScrollTarget && this._onScrollParallax) {
      this.scrollTarget.removeEventListener("scroll", this._onScrollParallax)
    }
    if (this._parallaxRaf) cancelAnimationFrame(this._parallaxRaf)
  }

  openPlant({ syncFocus = false } = {}) {
    if (!this.hasPlantFormTarget) return
    this.clearPlantError()
    document.body.classList.add("is-trail-plant-open")
    this.plantFormTarget.classList.add("is-open")
    this.plantFormTarget.hidden = false
    this.plantFormTarget.setAttribute("aria-hidden", "false")

    if (syncFocus) {
      this.plantTitleTarget?.focus({ preventScroll: true })
    } else {
      requestAnimationFrame(() => {
        this.plantTitleTarget?.focus({ preventScroll: true })
      })
    }
  }

  hidePlant() {
    if (!this.hasPlantFormTarget) return
    this._plantFromArrange = false
    if (this.hasNewTerraceStageTarget) this.newTerraceStageTarget.value = ""
    this.clearPlantError()
    this.plantFormTarget.classList.remove("is-open")
    this.plantFormTarget.hidden = true
    this.plantFormTarget.setAttribute("aria-hidden", "true")
    document.body.classList.remove("is-trail-plant-open")
    if (this.hasPlantTitleTarget) this.plantTitleTarget.value = ""
    if (this.hasPlantDescriptionTarget) this.plantDescriptionTarget.value = ""
    this.resetMetricFlow()
    if (this.hasAdvancedTarget) this.advancedTarget.hidden = true
    this.plantFormTarget.querySelector(".lp-trail-plant__advanced-toggle")?.setAttribute("aria-expanded", "false")
  }

  showPlantError(message) {
    if (!this.hasPlantErrorTarget) return
    this.plantErrorTarget.textContent = message
    this.plantErrorTarget.hidden = false
  }

  clearPlantError() {
    if (!this.hasPlantErrorTarget) return
    this.plantErrorTarget.textContent = ""
    this.plantErrorTarget.hidden = true
  }

  appendContext(body) {
    if (this.hasJourneyIdValue && this.journeyIdValue) {
      body.set("life_journey_id", String(this.journeyIdValue))
    }
    if (this.hasPlanIdValue && this.planIdValue) {
      body.set("plan_id", String(this.planIdValue))
      body.set("parent_id", String(this.planIdValue))
    }
    if (this.hasLifeAreaIdValue && this.lifeAreaIdValue) {
      body.set("life_area_id", String(this.lifeAreaIdValue))
    }
  }

  shouldIgnoreClick(target) {
    if (!target || !target.closest) return true
    return Boolean(
      target.closest(".lp-trail-camp") ||
      target.closest(".lp-trail-sheet") ||
      target.closest(".lp-trail-plant") ||
      target.closest(".lp-trail-hud") ||
      target.closest(".lp-trail-today") ||
      target.closest(".lp-trail__peak") ||
      target.closest(".lp-trail-placing") ||
      target.closest(".lp-trail-log") ||
      target.closest("[data-trail-ignore]")
    )
  }

  coordsFromEvent(event) {
    return this.coordsFromClient(event.clientX, event.clientY)
  }

  coordsFromClient(clientX, clientY) {
    const mountain = this.hasMountainTarget
      ? this.mountainTarget
      : this.surfaceTarget?.querySelector(".lp-trail__map")
    const surface = mountain || (this.hasSurfaceTarget ? this.surfaceTarget : this.element)
    const rect = surface.getBoundingClientRect()
    if (!rect.width || !rect.height) return null
    return {
      x: this.clamp((clientX - rect.left) / rect.width, 0.03, 0.97),
      y: this.clamp((clientY - rect.top) / rect.height, 0.03, 0.985)
    }
  }

  readCoord(value, fallback) {
    const n = Number.parseFloat(value)
    return Number.isFinite(n) ? n : fallback
  }

  clamp(n, min, max) {
    return Math.min(max, Math.max(min, n))
  }

  csrfToken() {
    return this.csrfValue ||
      document.querySelector("meta[name='csrf-token']")?.content ||
      ""
  }

  openArrangeCamps(event) {
    event?.preventDefault()
    event?.stopPropagation()
    if (this.element.classList.contains("is-first-camp-reveal")) return
    this.closePeakMenu()

    const overlay = document.getElementById("trail-arrange-camps")
    if (!overlay) return

    this.setArrangeOpen(true)
    overlay.hidden = false
    overlay.setAttribute("aria-hidden", "false")
    overlay.querySelector(".lp-trail-arrange__back")?.focus()
  }

  closeArrangeCamps(event) {
    event?.preventDefault()
    this.setArrangeOpen(false)

    const overlay = document.getElementById("trail-arrange-camps")
    if (!overlay) return

    overlay.hidden = true
    overlay.setAttribute("aria-hidden", "true")
    this.element.querySelector(".lp-trail__goal-plaque")?.focus()
  }

  setArrangeOpen(open) {
    this.element.classList.toggle("is-arrange-open", open)
    document.body.classList.toggle("is-arrange-open", open)
  }
}
