import { Controller } from "@hotwired/stimulus"

// Living mountain camera: L1 whole world → L2 plan branch → L3 project battles.
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
    const nextLevel = kind === "project" || kind === "battle" ? 3 : kind === "plan" ? 2 : 1
    this.focusIdValue = Number(id)
    this.levelValue = nextLevel
    this.apply()
    if (push) this.pushHistory()
  }

  zoomOut(event) {
    event?.preventDefault()
    if (this.levelValue <= 1) return
    if (this.levelValue === 3) {
      const projectSlot = this.element.querySelector(`[data-camera-project-id="${this.focusIdValue}"]`)
      const planId = projectSlot?.dataset?.cameraPlanId
      if (planId) {
        this.focusIdValue = Number(planId)
        this.levelValue = 2
      } else {
        this.levelValue = 1
        this.focusIdValue = 0
      }
    } else {
      this.levelValue = 1
      this.focusIdValue = 0
    }
    this.apply()
    this.pushHistory()
  }

  levelForFocus(focusId) {
    if (this.element.querySelector(`[data-camera-project-id="${focusId}"][data-camera-layer="2"]`)) return 2
    if (this.element.querySelector(`[data-camera-project-id="${focusId}"][data-camera-layer="3"]`)) return 3
    if (this.element.querySelector(`[data-camera-plan-id="${focusId}"][data-camera-layer="1"]`)) return 2
    return 1
  }

  focusPlanId(focusId) {
    const fromProject = this.element.querySelector(`[data-camera-project-id="${focusId}"]`)
    if (fromProject?.dataset?.cameraPlanId) return Number(fromProject.dataset.cameraPlanId)
    const planSlot = this.element.querySelector(`[data-camera-plan-id="${focusId}"][data-camera-layer="1"]`)
    if (planSlot) return focusId
    return 0
  }

  apply() {
    const level = this.levelValue
    const focusId = Number(this.focusIdValue || 0)
    const focusPlanId = this.focusPlanId(focusId)
    this.element.dataset.cameraLevel = String(level)
    this.element.classList.toggle("is-zoomed", level > 1)
    this.element.classList.toggle("is-zoom-plan", level === 2)
    this.element.classList.toggle("is-zoom-project", level === 3)

    this.element.querySelectorAll("[data-camera-layer]").forEach((el) => {
      const layer = Number(el.dataset.cameraLayer || 1)
      const planId = Number(el.dataset.cameraPlanId || 0)
      const projectId = Number(el.dataset.cameraProjectId || 0)
      const isPill = el.classList.contains("is-pill") || el.classList.contains("is-plan-overflow")
      let visible = false
      let dimmed = false

      if (level === 1) {
        visible = layer === 1
      } else if (level === 2) {
        if (layer === 1) {
          if (isPill) {
            // Keep side plans quiet at L2 — only dimmed chips, no competing titles.
            visible = true
            dimmed = true
          } else if (planId > 0 && planId !== focusPlanId) {
            visible = true
            dimmed = true
          } else {
            visible = true
            dimmed = planId > 0 && planId !== focusId && planId !== focusPlanId
          }
        } else if (layer === 2) {
          visible = planId === focusPlanId || planId === focusId
        }
      } else {
        // L3: only the climb band — hide noisy side plan pills.
        if (layer === 1) {
          if (isPill || el.classList.contains("is-plan-overflow")) {
            visible = false
          } else if (el.classList.contains("is-goal") || el.classList.contains("is-you") || !planId) {
            visible = true
            dimmed = true
          } else if (planId === focusPlanId) {
            visible = true
            dimmed = true
          } else {
            visible = false
          }
        } else if (layer === 2) {
          if (projectId === focusId) {
            visible = true
            dimmed = false
          } else if (planId === focusPlanId) {
            visible = true
            dimmed = true
          } else {
            visible = false
          }
        } else if (layer === 3) {
          visible = projectId === focusId
        }
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
      this.element.querySelector(`[data-camera-project-id="${this.focusIdValue}"].is-focus`) ||
      this.element.querySelector(`[data-camera-plan-id="${this.focusIdValue}"].is-focus`) ||
      this.element.querySelector(`[data-camera-project-id="${this.focusIdValue}"]`) ||
      this.element.querySelector(`[data-camera-plan-id="${this.focusIdValue}"]`)

    const x = focusEl ? Number.parseFloat(getComputedStyle(focusEl).getPropertyValue("--lp-x")) || 50 : 50
    const y = focusEl ? Number.parseFloat(getComputedStyle(focusEl).getPropertyValue("--lp-y")) || 50 : 50
    const scale = this.levelValue === 3 ? 1.85 : 1.45
    stage.style.setProperty("--lp-cam-x", `${50 - x}%`)
    stage.style.setProperty("--lp-cam-y", `${48 - y}%`)
    stage.style.setProperty("--lp-cam-scale", String(scale))
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
