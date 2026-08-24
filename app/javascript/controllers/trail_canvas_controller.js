import { Controller } from "@hotwired/stimulus"

// Mountain V4 photo trail: composer → place mode, ghosts, drag camps.
export default class extends Controller {
  static targets = [
    "surface",
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
    "hueRange",
    "logSheet",
    "logProjectId",
    "logBattleId",
    "logTitle",
    "logPrompt",
    "logAmount",
    "logQuick"
  ]

  static values = {
    createUrl: String,
    journeyId: Number,
    planId: Number,
    lifeAreaId: Number,
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
    this._drag = null
    this._moved = false
    this._longPressTimer = null
    this._onPointerMove = (event) => this.onCampPointerMove(event)
    this._onPointerUp = (event) => this.onCampPointerUp(event)
    this.bindFab()
  }

  disconnect() {
    this.clearLongPress()
    this.unbindDrag()
    this.unbindFab()
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

  // Empty trail tap → plant at coords, or finish placing mode.
  surfaceClick(event) {
    if (this._moved) {
      this._moved = false
      return
    }
    if (this.shouldIgnoreClick(event.target)) return

    const coords = this.coordsFromEvent(event)
    if (!coords) return

    if (this._placing && this._pendingPlant) {
      this.finishPlacing(coords.x, coords.y)
      return
    }

    this._presetSpot = { x: coords.x, y: coords.y }
    this.openPlant(coords.x, coords.y, { chooseSpot: false })
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
  }

  colorPicked(event) {
    const hue = Number.parseFloat(event.currentTarget?.dataset?.hue)
    if (this.hasHueRangeTarget && Number.isFinite(hue)) {
      this.hueRangeTarget.value = String(Math.round(hue))
    }
  }

  hueSlide(event) {
    const hue = Number.parseFloat(event.currentTarget?.value)
    if (!Number.isFinite(hue) || !this.hasPlantFormTarget) return
    const nearest = this.nearestColorKey(hue)
    const input = this.plantFormTarget.querySelector(`input[name='color_key'][value='${nearest}']`)
    if (input) input.checked = true
  }

  nearestColorKey(hue) {
    const map = [
      [ "teal", 174 ],
      [ "coral", 18 ],
      [ "amber", 40 ],
      [ "purple", 263 ],
      [ "blue", 228 ],
      [ "green", 145 ],
      [ "pink", 340 ],
      [ "gray", 30 ]
    ]
    let best = map[0][0]
    let bestDist = 999
    map.forEach(([ key, h ]) => {
      const d = Math.min(Math.abs(hue - h), 360 - Math.abs(hue - h))
      if (d < bestDist) {
        bestDist = d
        best = key
      }
    })
    return best
  }

  readQuantityFields(form) {
    const track = form.querySelector("input[name='track_quantity'][type='checkbox']")
    const tracked = track?.checked
    if (!tracked) return null
    const target = form.querySelector("input[name='target_amount']")?.value
    const unit = form.querySelector("input[name='unit']")?.value
    return { track: true, target, unit }
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
    if (quantity?.track) {
      body.set("track_quantity", "1")
      if (quantity.target) body.set("target_amount", String(quantity.target))
      if (quantity.unit) body.set("unit", String(quantity.unit))
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
      this.logPromptTarget.textContent = unit ? `How much toward ${unit}?` : "How much?"
    }
    if (this.hasLogAmountTarget) this.logAmountTarget.value = "1"
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
  }

  logPlus(event) {
    event.preventDefault()
    if (!this.hasLogAmountTarget) return
    const n = Number.parseFloat(this.logAmountTarget.value) || 0
    this.logAmountTarget.value = String(Math.round((n + 1) * 100) / 100)
  }

  logQuick(event) {
    event.preventDefault()
    if (!this.hasLogAmountTarget) return
    const amount = event.currentTarget?.dataset?.amount
    if (amount) this.logAmountTarget.value = amount
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

  campPointerDown(event) {
    if (event.pointerType === "mouse" && event.button !== 0) return

    const camp = event.currentTarget
    event.stopPropagation()

    this._moved = false
    this.clearLongPress()
    this._drag = {
      camp,
      pointerId: event.pointerId,
      startX: event.clientX,
      startY: event.clientY,
      dragging: false,
      updateUrl: camp.dataset.updateUrl || "",
      campId: camp.dataset.campId || ""
    }

    this._longPressTimer = window.setTimeout(() => {
      if (!this._drag || this._drag.camp !== camp) return
      this._drag.dragging = true
      camp.classList.add("is-dragging")
      this.bindDrag()
      try {
        camp.setPointerCapture(event.pointerId)
      } catch (_e) { /* ignore */ }
    }, 420)

    camp.addEventListener("pointermove", this._onPointerMove)
    camp.addEventListener("pointerup", this._onPointerUp)
    camp.addEventListener("pointercancel", this._onPointerUp)
  }

  onCampPointerMove(event) {
    if (!this._drag || this._drag.pointerId !== event.pointerId) return

    const dx = event.clientX - this._drag.startX
    const dy = event.clientY - this._drag.startY
    if (!this._drag.dragging && Math.hypot(dx, dy) > 10) {
      this.clearLongPress()
      return
    }

    if (!this._drag.dragging) return

    event.preventDefault()
    event.stopPropagation()
    this._moved = true

    const coords = this.coordsFromClient(event.clientX, event.clientY)
    if (!coords) return

    this._drag.camp.style.setProperty("--lp-trail-x", coords.x)
    this._drag.camp.style.setProperty("--lp-trail-y", coords.y)
    this._drag.camp.dataset.trailX = String(coords.x)
    this._drag.camp.dataset.trailY = String(coords.y)
    this._drag.pending = coords
  }

  onCampPointerUp(event) {
    if (!this._drag || this._drag.pointerId !== event.pointerId) return

    const drag = this._drag
    this.clearLongPress()
    drag.camp.removeEventListener("pointermove", this._onPointerMove)
    drag.camp.removeEventListener("pointerup", this._onPointerUp)
    drag.camp.removeEventListener("pointercancel", this._onPointerUp)
    this.unbindDrag()
    drag.camp.classList.remove("is-dragging")

    try {
      drag.camp.releasePointerCapture(event.pointerId)
    } catch (_e) { /* ignore */ }

    const pending = drag.pending
    this._drag = null

    if (drag.dragging && pending && drag.updateUrl) {
      event.preventDefault()
      event.stopPropagation()
      this.patchCampCoords(drag.updateUrl, pending.x, pending.y)
      this._moved = true
      window.setTimeout(() => { this._moved = false }, 0)
    }
  }

  campClick(event) {
    if (this._moved) {
      event.preventDefault()
      event.stopPropagation()
      this._moved = false
    }
  }

  openPlant(x, y, { chooseSpot = false } = {}) {
    if (x != null && y != null) {
      this._plantX = this.clamp(x, 0.05, 0.95)
      this._plantY = this.clamp(y, 0.32, 0.88)
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

  async patchCampCoords(url, x, y) {
    const token = this.csrfToken()
    const body = new FormData()
    body.set("trail_x", String(x))
    body.set("trail_y", String(y))
    body.set("_method", "patch")
    if (token) body.set("authenticity_token", token)

    try {
      await fetch(url, {
        method: "POST",
        headers: {
          Accept: "text/vnd.turbo-stream.html, text/html, application/xhtml+xml",
          "X-CSRF-Token": token,
          "X-Requested-With": "XMLHttpRequest"
        },
        body,
        credentials: "same-origin"
      })
    } catch (_error) { /* optimistic */ }
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
    const surface = this.hasSurfaceTarget ? this.surfaceTarget : this.element
    const rect = surface.getBoundingClientRect()
    if (!rect.width || !rect.height) return null
    return {
      x: this.clamp((clientX - rect.left) / rect.width, 0.05, 0.95),
      y: this.clamp((clientY - rect.top) / rect.height, 0.28, 0.92)
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

  clearLongPress() {
    if (this._longPressTimer) {
      window.clearTimeout(this._longPressTimer)
      this._longPressTimer = null
    }
  }

  bindDrag() {
    window.addEventListener("pointermove", this._onPointerMove, { passive: false })
    window.addEventListener("pointerup", this._onPointerUp)
    window.addEventListener("pointercancel", this._onPointerUp)
  }

  unbindDrag() {
    window.removeEventListener("pointermove", this._onPointerMove)
    window.removeEventListener("pointerup", this._onPointerUp)
    window.removeEventListener("pointercancel", this._onPointerUp)
  }
}
