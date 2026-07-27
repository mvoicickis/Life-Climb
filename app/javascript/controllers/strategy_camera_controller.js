import { Controller } from "@hotwired/stimulus"

// Simplified living mountain camera: L1 whole world; light pan when a Plan is focused.
// Battles no longer zoom the map — they live in the camp notebook.
export default class extends Controller {
  static targets = ["stage", "viewport", "zoomOut"]
  static values = {
    level: { type: Number, default: 1 },
    focusId: Number,
    journeyUrl: String
  }

  connect() {
    this.apply()
    this._onPop = () => {
      const params = new URLSearchParams(window.location.search)
      const focus = params.get("focus_id")
      if (focus) {
        this.focusIdValue = Number(focus)
        this.levelValue = this.levelForFocus(this.focusIdValue)
      } else {
        this.levelValue = 1
        this.focusIdValue = 0
      }
      this.apply()
    }
    window.addEventListener("popstate", this._onPop)
  }

  disconnect() {
    window.removeEventListener("popstate", this._onPop)
  }

  zoomTo({ id, kind, push = true } = {}) {
    if (!id) return
    // Projects no longer enter L3 map zoom — notebook owns that depth.
    const nextLevel = kind === "plan" || kind === "project" || kind === "battle" ? 2 : 1
    this.focusIdValue = Number(id)
    this.levelValue = nextLevel
    this.apply()
    if (push) this.pushHistory()
  }

  zoomOut(event) {
    event?.preventDefault()
    this.levelValue = 1
    this.focusIdValue = 0
    this.apply()
    this.pushHistory()
  }

  levelForFocus(focusId) {
    if (this.element.querySelector(`[data-camera-plan-id="${focusId}"]`)) return 2
    if (this.element.querySelector(`[data-camera-project-id="${focusId}"]`)) return 2
    return 1
  }

  apply() {
    const level = this.levelValue
    const focusId = Number(this.focusIdValue || 0)
    this.element.dataset.cameraLevel = String(level)
    this.element.classList.toggle("is-zoomed", level > 1)
    this.element.classList.toggle("is-zoom-plan", level === 2)
    this.element.classList.remove("is-zoom-project")

    this.element.querySelectorAll("[data-camera-layer]").forEach((el) => {
      // Camp notebook map only has layer-1 orientation pins.
      const visible = true
      let dimmed = false
      if (level === 2) {
        const planId = Number(el.dataset.cameraPlanId || 0)
        if (el.classList.contains("is-pill") && planId && planId !== focusId) dimmed = true
        if (el.classList.contains("is-plan-overflow")) dimmed = true
      }
      el.hidden = !visible
      el.classList.toggle("is-camera-visible", visible)
      el.classList.toggle("is-dimmed", dimmed)
    })

    this.panToFocus()
    if (this.hasZoomOutTarget) this.zoomOutTarget.hidden = level <= 1
  }

  panToFocus() {
    if (!this.hasStageTarget) return
    const stage = this.stageTarget
    if (this.levelValue <= 1 || !this.focusIdValue) {
      stage.style.setProperty("--lp-cam-x", "0%")
      stage.style.setProperty("--lp-cam-y", "0%")
      stage.style.setProperty("--lp-cam-scale", "1")
      return
    }

    const focusEl =
      this.element.querySelector(`[data-camera-plan-id="${this.focusIdValue}"].is-focus`) ||
      this.element.querySelector(`[data-camera-plan-id="${this.focusIdValue}"]`) ||
      this.element.querySelector(`[data-camera-project-id="${this.focusIdValue}"]`)

    const x = focusEl ? Number.parseFloat(getComputedStyle(focusEl).getPropertyValue("--lp-x")) || 50 : 50
    const y = focusEl ? Number.parseFloat(getComputedStyle(focusEl).getPropertyValue("--lp-y")) || 50 : 50
    stage.style.setProperty("--lp-cam-x", `${50 - x}%`)
    stage.style.setProperty("--lp-cam-y", `${46 - y}%`)
    stage.style.setProperty("--lp-cam-scale", "1.35")
  }

  pushHistory() {
    if (!this.journeyUrlValue) return
    const url = new URL(this.journeyUrlValue, window.location.origin)
    if (this.focusIdValue) url.searchParams.set("focus_id", String(this.focusIdValue))
    else url.searchParams.delete("focus_id")
    url.searchParams.delete("peek")
    url.searchParams.delete("sheet")
    url.searchParams.delete("node_id")
    window.history.pushState({ camera: true, focus: this.focusIdValue, level: this.levelValue }, "", url)
  }
}
