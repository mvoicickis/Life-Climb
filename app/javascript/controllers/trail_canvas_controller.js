import { Controller } from "@hotwired/stimulus"

const CAMP_HOLD_MS = 450
const CAMP_HOLD_CANCEL_PX = 10

// Mountain V4 photo trail: composer → place mode, ghosts.
// Blank taps scroll only. Long-press (~450ms) then drag to PATCH camp coords.
export default class extends Controller {
  static targets = [
    "surface",
    "mountain",
    "scroll",
    "camps",
    "plantForm",
    "plantX",
    "plantY",
    "plantTitle",
    "plantSubmit",
    "ghosts",
    "glowDots",
    "placingBanner",
    "placingText",
    "peakMenu",
    "editDialog",
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
    "peakTagline",
    "photoWrap",
    "photo",
    "clouds"
  ]

  static values = {
    createUrl: String,
    journeyId: Number,
    planId: Number,
    lifeAreaId: Number,
    goalId: Number,
    goalUpdateUrl: String,
    journeyUpdateUrl: String,
    csrf: String,
    curve: { type: Array, default: [] },
    quantityLogUrl: String
  }

  connect() {
    this._plantX = null
    this._plantY = null
    this._presetSpot = null
    this._placing = false
    this._pendingPlant = null
    this._logContext = null
    this.bindFab()
    this.bindScrollParallax()
    this.bindPeakPin()
    this.syncAccentFromSwatch()
  }

  disconnect() {
    this.clearCampHold()
    this.unbindFab()
    this.unbindScrollParallax()
    this.unbindPeakPin()
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
    this._presetSpot = null
    this._plantX = null
    this._plantY = null
    this.openPlant(null, null, { chooseSpot: true })
  }

  // Empty trail tap: plant only while choosing a spot. Otherwise scroll/pan.
  surfaceClick(event) {
    if (this.element.classList.contains("is-dragging")) return
    if (this.shouldIgnoreClick(event.target)) return

    const coords = this.coordsFromEvent(event)
    if (!coords) return

    if (this._placing && this._pendingPlant) {
      this.finishPlacing(coords.x, coords.y)
      return
    }

    if (!this.element.classList.contains("is-placing")) return

    this._presetSpot = { x: coords.x, y: coords.y }
    this.openPlant(coords.x, coords.y, { chooseSpot: false })
  }

  campClick(event) {
    if (this.element.dataset.trailSuppressOpen === "1") {
      event.preventDefault()
      event.stopPropagation()
    }
  }

  // Hold ~450ms, then drag. A normal tap still opens the camp sheet.
  campPointerDown(event) {
    if (event.pointerType === "mouse" && event.button !== 0) return
    if (this.element.classList.contains("is-placing")) return

    const camp = event.currentTarget
    this.clearCampHold()
    this._campPointer = {
      camp,
      pointerId: event.pointerId,
      startClientX: event.clientX,
      startClientY: event.clientY,
      origX: this.readCoord(camp.dataset.trailX, 0.5),
      origY: this.readCoord(camp.dataset.trailY, 0.55),
      dragging: false
    }
    this._campHoldTimer = window.setTimeout(() => this.beginCampDrag(), CAMP_HOLD_MS)
  }

  campPointerMove(event) {
    const state = this._campPointer
    if (!state || state.pointerId !== event.pointerId) return

    const dist = Math.hypot(
      event.clientX - state.startClientX,
      event.clientY - state.startClientY
    )

    if (!state.dragging) {
      if (dist > CAMP_HOLD_CANCEL_PX) this.clearCampHold()
      return
    }

    event.preventDefault()
    const coords = this.coordsFromClient(event.clientX, event.clientY)
    if (!coords) return
    this.applyCampCoords(state.camp, coords.x, coords.y)
  }

  campPointerUp(event) {
    const state = this._campPointer
    if (!state || state.pointerId !== event.pointerId) return

    const wasDragging = state.dragging
    const cancelled = event.type === "pointercancel"
    if (wasDragging) {
      event.preventDefault()
      if (cancelled) this.applyCampCoords(state.camp, state.origX, state.origY)
      else this.finishCampDrag()
    }
    this.clearCampHold()
    if (wasDragging) {
      this.element.dataset.trailSuppressOpen = "1"
      window.setTimeout(() => {
        delete this.element.dataset.trailSuppressOpen
      }, 80)
    }
  }

  beginCampDrag() {
    const state = this._campPointer
    if (!state) return

    state.dragging = true
    try {
      state.camp.setPointerCapture(state.pointerId)
    } catch (_error) { /* capture is best-effort */ }
    state.camp.classList.add("is-dragging")
    this.element.classList.add("is-dragging")
    this.element.dataset.trailSuppressOpen = "1"
  }

  applyCampCoords(camp, x, y) {
    camp.style.setProperty("--lp-trail-x", x)
    camp.style.setProperty("--lp-trail-y", y)
    camp.dataset.trailX = String(x)
    camp.dataset.trailY = String(y)
  }

  async finishCampDrag() {
    const state = this._campPointer
    if (!state) return

    const camp = state.camp
    const x = this.readCoord(camp.dataset.trailX, state.origX)
    const y = this.readCoord(camp.dataset.trailY, state.origY)
    const moved = Math.hypot(x - state.origX, y - state.origY) > 0.004
    if (!moved) {
      this.applyCampCoords(camp, state.origX, state.origY)
      return
    }

    const url = camp.dataset.updateUrl
    if (!url) return

    const token = this.csrfToken()
    const body = new FormData()
    body.set("trail_x", String(x))
    body.set("trail_y", String(y))
    body.set("_method", "patch")
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
      if (!response.ok) this.applyCampCoords(camp, state.origX, state.origY)
    } catch (_error) {
      this.applyCampCoords(camp, state.origX, state.origY)
    }
  }

  clearCampHold() {
    if (this._campHoldTimer) {
      window.clearTimeout(this._campHoldTimer)
      this._campHoldTimer = null
    }
    const state = this._campPointer
    if (state?.camp) {
      state.camp.classList.remove("is-dragging")
      try {
        if (state.camp.hasPointerCapture?.(state.pointerId)) {
          state.camp.releasePointerCapture(state.pointerId)
        }
      } catch (_error) { /* already released */ }
    }
    this.element.classList.remove("is-dragging")
    this._campPointer = null
  }

  ghostPick(event) {
    event.preventDefault()
    event.stopPropagation()

    const el = event.currentTarget
    const x = this.readCoord(el.dataset.trailX, 0.5)
    const y = this.readCoord(el.dataset.trailY, 0.55)
    this._presetSpot = { x, y }
    this.openPlant(x, y, { chooseSpot: false })
  }

  closePlant(event) {
    event?.preventDefault()
    event?.stopPropagation()
    this.hidePlant()
    this.cancelPlacing()
  }

  stop(event) {
    event.stopPropagation()
  }

  togglePeakMenu(event) {
    event?.preventDefault()
    event?.stopPropagation()
    if (!this.hasPeakMenuTarget) return
    const open = this.peakMenuTarget.hasAttribute("hidden")
    this.peakMenuTarget.toggleAttribute("hidden", !open)
    event.currentTarget?.setAttribute("aria-expanded", open ? "true" : "false")
  }

  editDestination(event) {
    event?.preventDefault()
    event?.stopPropagation()
    if (this.hasPeakMenuTarget) this.peakMenuTarget.hidden = true
    if (this.hasEditDialogTarget) this.editDialogTarget.showModal()
  }

  closeEdit(event) {
    event?.preventDefault()
    if (this.hasEditDialogTarget) this.editDialogTarget.close()
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

    const color =
      form.querySelector("input[name='color_key']:checked")?.value ||
      form.querySelector("input[name='color_key']")?.value ||
      "teal"

    const quantity = this.readQuantityFields(form)

    // Preset spot (ghost / tap) → plant immediately.
    if (this._presetSpot) {
      this._plantX = this._presetSpot.x
      this._plantY = this._presetSpot.y
      this.writeHiddenCoords()
      await this.postPlant({ title, color, x: this._plantX, y: this._plantY, quantity })
      return
    }

    // FAB flow → enter placing mode with glow dots.
    this._pendingPlant = { title, color, quantity }
    this.hidePlant({ keepPending: true })
    this.enterPlacing(title)
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

  enterPlacing(name = "…") {
    this._placing = true
    this.element.classList.add("is-placing")
    if (this.hasPlacingBannerTarget) {
      this.placingBannerTarget.hidden = false
      this.placingBannerTarget.setAttribute("aria-hidden", "false")
    }
    if (this.hasPlacingTextTarget) {
      const template = this.placingTextTarget.dataset.template ||
        this.placingTextTarget.textContent ||
        'Tap where "%{name}" belongs on the trail'
      // Store original once
      if (!this.placingTextTarget.dataset.template) {
        this.placingTextTarget.dataset.template = this.placingTextTarget.textContent
      }
      this.placingTextTarget.textContent =
        (this.placingTextTarget.dataset.template || template).replace("%{name}", name).replace("…", name)
    }
    this.renderGlowDots()
  }

  cancelPlacing(event) {
    event?.preventDefault()
    event?.stopPropagation()
    this._placing = false
    this._pendingPlant = null
    this.element.classList.remove("is-placing")
    if (this.hasPlacingBannerTarget) {
      this.placingBannerTarget.hidden = true
      this.placingBannerTarget.setAttribute("aria-hidden", "true")
    }
    if (this.hasGlowDotsTarget) {
      this.glowDotsTarget.hidden = true
      this.glowDotsTarget.innerHTML = ""
    }
  }

  renderGlowDots() {
    if (!this.hasGlowDotsTarget) return
    const curve = this.curveValue || []
    this.glowDotsTarget.innerHTML = ""
    curve.forEach((pair, i) => {
      if (i % 2 !== 0) return
      const [y, x] = pair
      const dot = document.createElement("span")
      dot.className = "lp-trail-glow"
      dot.style.setProperty("--lp-trail-x", x)
      dot.style.setProperty("--lp-trail-y", y)
      this.glowDotsTarget.appendChild(dot)
    })
    this.glowDotsTarget.hidden = false
  }

  async finishPlacing(x, y) {
    const pending = this._pendingPlant
    if (!pending) return
    this.cancelPlacing()
    await this.postPlant({
      title: pending.title,
      color: pending.color,
      x,
      y,
      quantity: pending.quantity
    })
  }

  async postPlant({ title, color, x, y, quantity = null }) {
    const url = this.createUrlValue
    if (!url) return

    const body = new FormData()
    body.set("title", title)
    body.set("horizon", "project")
    body.set("color_key", color)
    body.set("trail_x", String(x))
    body.set("trail_y", String(y))
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
    this.appendContext(body)
    const token = this.csrfToken()
    if (token) body.set("authenticity_token", token)

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
        window.Turbo.renderStreamMessage(await response.text())
        this.hidePlant()
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

  openLog(event) {
    event.preventDefault()
    event.stopPropagation()
    const btn = event.currentTarget
    if (!this.hasLogSheetTarget) return
    if (this.hasLogProjectIdTarget) this.logProjectIdTarget.value = btn.dataset.projectId || ""
    if (this.hasLogBattleIdTarget) this.logBattleIdTarget.value = btn.dataset.battleId || ""
    if (this.hasLogTitleTarget) {
      this.logTitleTarget.textContent = btn.dataset.projectTitle || "Log it"
    }
    if (this.hasLogPromptTarget) {
      const unit = btn.dataset.unit || ""
      const kind = btn.dataset.quantityKind || "up"
      const min = Number.parseFloat(btn.dataset.rangeMin)
      const max = Number.parseFloat(btn.dataset.rangeMax)
      let prompt
      if (kind === "range" && Number.isFinite(min) && Number.isFinite(max)) {
        prompt = `Healthy range ${min}–${max}${unit ? ` ${unit}` : ""}`
      } else if (kind === "down") {
        prompt = unit ? `How much (stay under ${unit})?` : "How much (stay under)?"
      } else {
        prompt = unit ? `How much toward ${unit}?` : "How much?"
      }
      this.logPromptTarget.textContent = prompt
      this.logPromptTarget.dataset.kind = kind
      this.logPromptTarget.dataset.rangeMin = btn.dataset.rangeMin || ""
      this.logPromptTarget.dataset.rangeMax = btn.dataset.rangeMax || ""
    }
    if (this.hasLogAmountTarget) this.logAmountTarget.value = "1"
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
    requestAnimationFrame(() => this.logAmountTarget?.focus())
  }

  closeLog(event) {
    event?.preventDefault()
    event?.stopPropagation()
    if (!this.hasLogSheetTarget) return
    this.logSheetTarget.hidden = true
    this.logSheetTarget.setAttribute("aria-hidden", "true")
    this.logSheetTarget.classList.remove("is-open")
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
    return raw.replace("%{prev}", String(vars.prev ?? ""))
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
          Accept: "text/html, application/xhtml+xml",
          "X-CSRF-Token": token,
          "X-Requested-With": "XMLHttpRequest"
        },
        body,
        credentials: "same-origin"
      })
      if (response.redirected) {
        window.location.href = response.url
        return
      }
      window.location.reload()
    } catch (_error) {
      window.location.reload()
    }
  }

  peakTitleKey(event) {
    if (event.key === "Enter") {
      event.preventDefault()
      event.currentTarget?.blur()
    }
  }

  async commitPeakTitle(event) {
    const el = event.currentTarget
    const title = (el.textContent || "").trim()
    if (!title || !this.goalUpdateUrlValue) return
    await this.patchGoal({ title })
  }

  async commitPeakTagline(event) {
    const text = (event.currentTarget.textContent || "").trim()
    if (!this.goalUpdateUrlValue) return
    await this.patchGoal({ description: text })
  }

  async patchGoal(fields) {
    const token = this.csrfToken()
    const body = new FormData()
    Object.entries(fields).forEach(([k, v]) => body.set(k, v))
    body.set("_method", "patch")
    if (token) body.set("authenticity_token", token)
    try {
      await fetch(this.goalUpdateUrlValue, {
        method: "POST",
        headers: {
          Accept: "text/vnd.turbo-stream.html, text/html",
          "X-CSRF-Token": token,
          "X-Requested-With": "XMLHttpRequest"
        },
        body,
        credentials: "same-origin"
      })
    } catch (_e) { /* inline edit is best-effort */ }
  }

  photoDragOver(event) {
    event.preventDefault()
    this.photoWrapTarget?.classList.add("is-dragover")
  }

  photoDragLeave(event) {
    event.preventDefault()
    this.photoWrapTarget?.classList.remove("is-dragover")
  }

  async photoDrop(event) {
    event.preventDefault()
    this.photoWrapTarget?.classList.remove("is-dragover")
    const file = event.dataTransfer?.files?.[0]
    if (!file || !this.journeyUpdateUrlValue) return

    const body = new FormData()
    body.set("mountain_photo_intent", "upload")
    body.set("life_journey[mountain_photo]", file)
    body.set("_method", "patch")
    const token = this.csrfToken()
    if (token) body.set("authenticity_token", token)

    try {
      const response = await fetch(this.journeyUpdateUrlValue, {
        method: "POST",
        headers: {
          Accept: "text/html",
          "X-CSRF-Token": token,
          "X-Requested-With": "XMLHttpRequest"
        },
        body,
        credentials: "same-origin"
      })
      if (response.redirected) {
        window.location.href = response.url
      } else {
        window.location.reload()
      }
    } catch (_e) {
      window.location.reload()
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

  // Pin destination pennant to the painted summit after object-fit: cover crop
  // (titleTop / peakRight from --lp-peak-y / --lp-peak-x on 1024×1536 art).
  bindPeakPin() {
    const mountain = this.hasMountainTarget ? this.mountainTarget : null
    if (!mountain) return

    this.syncPeakPin()
    if (typeof ResizeObserver === "undefined") return

    this._peakPinObserver = new ResizeObserver(() => this.syncPeakPin())
    this._peakPinObserver.observe(mountain)
  }

  unbindPeakPin() {
    if (this._peakPinObserver) {
      this._peakPinObserver.disconnect()
      this._peakPinObserver = null
    }
  }

  syncPeakPin() {
    const mountain = this.hasMountainTarget ? this.mountainTarget : null
    if (!mountain) return

    const width = mountain.clientWidth || 0
    const height = mountain.clientHeight || 0
    if (width < 1 || height < 1) return

    const styles = getComputedStyle(this.element)
    const peakXFrac = parseFloat(styles.getPropertyValue("--lp-peak-x")) || 0.566
    const peakYFrac = parseFloat(styles.getPropertyValue("--lp-peak-y")) || 0.22
    const artW = 1024
    const artH = 1536
    const widthScale = width / artW
    const heightScale = height / artH

    let peakX
    let titleTop
    if (widthScale > heightScale) {
      // Width fills; cover crops the top/bottom (object-position: 50% 40%).
      const scaledH = artH * widthScale
      peakX = Math.round(peakXFrac * width)
      titleTop = Math.round(peakYFrac * scaledH - 0.4 * (scaledH - height))
    } else {
      // Height fills; cover crops the sides (object-position X 50%).
      const scaledW = artW * heightScale
      peakX = Math.round(peakXFrac * scaledW - ((scaledW - width) / 2))
      titleTop = Math.round(height * peakYFrac)
    }
    const peakRight = Math.max(0, width - peakX)

    this.element.style.setProperty("--lp-title-top", `${titleTop}px`)
    this.element.style.setProperty("--lp-peak-right", `${peakRight}px`)
  }

  openPlant(x, y, { chooseSpot = false } = {}) {
    if (x != null && y != null) {
      this._plantX = this.clamp(x, 0.03, 0.97)
      this._plantY = this.clamp(y, 0.03, 0.985)
      this.writeHiddenCoords()
    } else {
      this._plantX = null
      this._plantY = null
    }

    if (!this.hasPlantFormTarget) return
    this.plantFormTarget.classList.add("is-open")
    this.plantFormTarget.hidden = false
    this.plantFormTarget.setAttribute("aria-hidden", "false")

    if (this.hasPlantSubmitTarget) {
      this.plantSubmitTarget.textContent = chooseSpot
        ? this.plantSubmitTarget.dataset.chooseLabel || this.plantSubmitTarget.textContent
        : this.plantSubmitTarget.dataset.plantLabel || this.plantSubmitTarget.textContent
    }

    const marker = this.plantFormTarget.querySelector("[data-trail-plant-marker]")
    if (marker && this._plantX != null) {
      marker.style.left = `${this._plantX * 100}%`
      marker.style.top = `${this._plantY * 100}%`
      marker.hidden = false
    } else if (marker) {
      marker.hidden = true
    }

    requestAnimationFrame(() => {
      this.plantTitleTarget?.focus({ preventScroll: true })
    })
  }

  hidePlant({ keepPending = false } = {}) {
    if (!this.hasPlantFormTarget) return
    this.plantFormTarget.classList.remove("is-open")
    this.plantFormTarget.hidden = true
    this.plantFormTarget.setAttribute("aria-hidden", "true")
    if (this.hasPlantTitleTarget && !keepPending) this.plantTitleTarget.value = ""
    if (!keepPending) {
      this._plantX = null
      this._plantY = null
      this._presetSpot = null
      this.resetMetricFlow()
      if (this.hasAdvancedTarget) this.advancedTarget.hidden = true
      this.plantFormTarget.querySelector(".lp-trail-plant__advanced-toggle")?.setAttribute("aria-expanded", "false")
    }
  }

  writeHiddenCoords() {
    if (this._plantX == null || this._plantY == null) return
    if (this.hasPlantXTarget) this.plantXTarget.value = String(this._plantX)
    if (this.hasPlantYTarget) this.plantYTarget.value = String(this._plantY)
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
      target.closest(".lp-trail-ghost") ||
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
      : this.surfaceTarget?.querySelector(".lp-trail__mountain")
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
}
