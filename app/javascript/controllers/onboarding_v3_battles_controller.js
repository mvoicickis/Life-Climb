import { Controller } from "@hotwired/stimulus"

// Onboarding v3 battles step — add rows, enable Done planning when at least one battle title.
export default class extends Controller {
  static targets = ["list", "addInput", "submit", "form", "dock", "scroll"]

  connect() {
    this._viewportKeyboardInset = "0px"
    this._onViewport = () => this.syncKeyboardInset()
    this.bindDockViewport()
    this.refresh()
  }

  disconnect() {
    this.unbindDockViewport()
  }

  bindDockViewport() {
    if (!this.hasDockTarget) return

    window.visualViewport?.addEventListener("resize", this._onViewport)
    window.visualViewport?.addEventListener("scroll", this._onViewport)
    this._dockResizeObserver = new ResizeObserver(() => this.measureDockOffset())
    this._dockResizeObserver.observe(this.dockTarget)
    this.syncKeyboardInset()
    this.measureDockOffset()
  }

  unbindDockViewport() {
    window.visualViewport?.removeEventListener("resize", this._onViewport)
    window.visualViewport?.removeEventListener("scroll", this._onViewport)
    this._dockResizeObserver?.disconnect()
    this._dockResizeObserver = null
    this.element.style.setProperty("--lp-ob-keyboard-inset", "0px")
    if (this.hasScrollTarget) {
      this.scrollTarget.style.setProperty("--lp-ob-dock-offset", "0px")
    }
  }

  measureDockOffset() {
    if (!this.hasDockTarget || !this.hasScrollTarget) return

    const height = this.dockTarget.offsetHeight
    this.scrollTarget.style.setProperty("--lp-ob-dock-offset", `${height}px`)
  }

  syncKeyboardInset() {
    const viewport = window.visualViewport
    let inset = "0px"

    if (viewport) {
      const heightGap = window.innerHeight - viewport.height
      const keyboardOpen = heightGap > 120
      if (keyboardOpen) {
        const offset = Math.max(0, window.innerHeight - (viewport.height + viewport.offsetTop))
        inset = `${offset}px`
      }
    }

    if (this._viewportKeyboardInset === inset) return
    this._viewportKeyboardInset = inset
    this.element.style.setProperty("--lp-ob-keyboard-inset", inset)
  }

  add(event) {
    event.preventDefault()
    const title = this.addInputTarget.value.trim()
    if (!title) {
      this.addInputTarget.focus()
      return
    }

    const li = document.createElement("li")
    li.className = "lp-ob-battles__row"
    li.innerHTML = `
      <span class="lp-ob-battles__ring" aria-hidden="true"></span>
      <span class="lp-ob-battles__label"></span>
      <input type="hidden" name="onboarding[battle_titles][]" value="">`
    li.querySelector(".lp-ob-battles__label").textContent = title
    li.querySelector("input").value = title
    this.listTarget.appendChild(li)
    this.addInputTarget.value = ""
    this.addInputTarget.focus()
    this.refresh()
  }

  addFromEnter(event) {
    if (event.key !== "Enter") return
    event.preventDefault()
    this.add(event)
  }

  refresh() {
    const count = this.listTarget.querySelectorAll("input[type='hidden']").length
    if (this.hasSubmitTarget) this.submitTarget.disabled = count < 1
  }
}