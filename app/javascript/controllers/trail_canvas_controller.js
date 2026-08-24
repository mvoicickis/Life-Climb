import { Controller } from "@hotwired/stimulus"

// Mountain V4 photo trail: plant camps on empty taps, drag to reposition.
export default class extends Controller {
  static targets = [
    "surface",
    "camps",
    "plantForm",
    "plantX",
    "plantY",
    "plantTitle",
    "ghosts"
  ]

  static values = {
    createUrl: String,
    journeyId: Number,
    planId: Number,
    lifeAreaId: Number,
    csrf: String
  }

  connect() {
    this._plantX = null
    this._plantY = null
    this._drag = null
    this._moved = false
    this._longPressTimer = null
    this._onPointerMove = (event) => this.onCampPointerMove(event)
    this._onPointerUp = (event) => this.onCampPointerUp(event)
  }

  disconnect() {
    this.clearLongPress()
    this.unbindDrag()
  }

  // Empty trail tap → open plant composer at normalized coords.
  surfaceClick(event) {
    if (this._moved) {
      this._moved = false
      return
    }
    if (this.shouldIgnoreClick(event.target)) return

    const coords = this.coordsFromEvent(event)
    if (!coords) return

    this.openPlant(coords.x, coords.y)
  }

  // Ghost “Plant a project” pins.
  ghostPick(event) {
    event.preventDefault()
    event.stopPropagation()

    const el = event.currentTarget
    const x = this.readCoord(el.dataset.trailX, 0.5)
    const y = this.readCoord(el.dataset.trailY, 0.55)
    this.openPlant(x, y)
  }

  closePlant(event) {
    event?.preventDefault()
    event?.stopPropagation()
    this.hidePlant()
  }

  stop(event) {
    event.stopPropagation()
  }

  // Prefer turbo-stream fetch; fall back to normal form POST with hidden coords.
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

    this.writeHiddenCoords()

    const url = this.createUrlValue || form.action
    if (!url) return

    const body = new FormData(form)
    this.appendContext(body)
    if (!body.has("trail_x") && this._plantX != null) body.set("trail_x", this._plantX)
    if (!body.has("trail_y") && this._plantY != null) body.set("trail_y", this._plantY)
    if (!body.has("authenticity_token")) {
      const token = this.csrfToken()
      if (token) body.set("authenticity_token", token)
    }

    try {
      const response = await fetch(url, {
        method: "POST",
        headers: {
          Accept: "text/vnd.turbo-stream.html, text/html, application/xhtml+xml",
          "X-CSRF-Token": this.csrfToken(),
          "X-Requested-With": "XMLHttpRequest"
        },
        body,
        credentials: "same-origin"
      })

      const contentType = response.headers.get("content-type") || ""
      if (contentType.includes("turbo-stream") && window.Turbo?.renderStreamMessage) {
        const html = await response.text()
        window.Turbo.renderStreamMessage(html)
        this.hidePlant()
        return
      }

      if (response.redirected) {
        window.location.href = response.url
        return
      }

      // Fallback: classic form submit with hidden trail_x / trail_y.
      this.writeHiddenCoords()
      if (typeof form.requestSubmit === "function") form.requestSubmit()
      else form.submit()
    } catch (_error) {
      this.writeHiddenCoords()
      if (typeof form.requestSubmit === "function") form.requestSubmit()
      else form.submit()
    }
  }

  // Long-press / drag camp → PATCH trail coords only.
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
      // Movement before long-press threshold — treat as scroll intent; cancel drag arming.
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
      // Suppress the click that would open the sheet after a drag.
      this._moved = true
      window.setTimeout(() => { this._moved = false }, 0)
    }
  }

  campClick(event) {
    // After a drag, swallow the synthetic click so the sheet does not open.
    if (this._moved) {
      event.preventDefault()
      event.stopPropagation()
      this._moved = false
    }
  }

  openPlant(x, y) {
    this._plantX = this.clamp(x, 0.05, 0.95)
    this._plantY = this.clamp(y, 0.32, 0.88)
    this.writeHiddenCoords()

    if (!this.hasPlantFormTarget) return
    this.plantFormTarget.classList.add("is-open")
    this.plantFormTarget.hidden = false
    this.plantFormTarget.setAttribute("aria-hidden", "false")

    const marker = this.plantFormTarget.querySelector("[data-trail-plant-marker]")
    if (marker) {
      marker.style.left = `${this._plantX * 100}%`
      marker.style.top = `${this._plantY * 100}%`
    }

    requestAnimationFrame(() => {
      this.plantTitleTarget?.focus({ preventScroll: true })
    })
  }

  hidePlant() {
    if (!this.hasPlantFormTarget) return
    this.plantFormTarget.classList.remove("is-open")
    this.plantFormTarget.hidden = true
    this.plantFormTarget.setAttribute("aria-hidden", "true")
    if (this.hasPlantTitleTarget) this.plantTitleTarget.value = ""
    this._plantX = null
    this._plantY = null
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
    } catch (_error) {
      // Keep the optimistic position; next reload will reconcile.
    }
  }

  shouldIgnoreClick(target) {
    if (!target || !target.closest) return true
    return Boolean(
      target.closest(".lp-trail-camp") ||
      target.closest(".lp-trail-ghost") ||
      target.closest(".lp-trail-sheet") ||
      target.closest(".lp-trail-plant") ||
      target.closest(".lp-trail__chrome") ||
      target.closest(".lp-trail__controls") ||
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

    const x = this.clamp((clientX - rect.left) / rect.width, 0, 1)
    const y = this.clamp((clientY - rect.top) / rect.height, 0, 1)
    return { x, y }
  }

  readCoord(value, fallback) {
    const n = Number(value)
    return Number.isFinite(n) ? this.clamp(n, 0, 1) : fallback
  }

  clamp(n, min, max) {
    return Math.min(max, Math.max(min, n))
  }

  csrfToken() {
    return this.csrfValue || document.querySelector("meta[name='csrf-token']")?.content || ""
  }

  clearLongPress() {
    if (this._longPressTimer) window.clearTimeout(this._longPressTimer)
    this._longPressTimer = null
  }

  bindDrag() {
    document.addEventListener("pointermove", this._onPointerMove)
    document.addEventListener("pointerup", this._onPointerUp)
    document.addEventListener("pointercancel", this._onPointerUp)
  }

  unbindDrag() {
    document.removeEventListener("pointermove", this._onPointerMove)
    document.removeEventListener("pointerup", this._onPointerUp)
    document.removeEventListener("pointercancel", this._onPointerUp)
  }
}
