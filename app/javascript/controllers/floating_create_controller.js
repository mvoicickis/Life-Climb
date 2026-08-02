import { Controller } from "@hotwired/stimulus"

// Floating planning card for Mountain “+ Checkpoint” / “+ Add Practice”.
// Reuses the native <details> trigger + Rails form; portals the card to <body>
// so trail transforms / overflow cannot clip it.
//
// Important: after portaling, Stimulus actions inside the shell no longer reach
// this controller (targets/actions must live inside the controller element).
// Close clicks are bound manually on the portaled shell.
export default class extends Controller {
  static targets = ["shell", "card", "title"]

  connect() {
    this._onKey = (event) => this.onKeydown(event)
    this._onReposition = () => this.positionCard()
    this._onShellClick = (event) => this.onShellClick(event)
    this._ported = false
    this.cacheRefs()
  }

  disconnect() {
    this.restoreShell()
    this.unbindOpenGuards()
  }

  cacheRefs() {
    // Cache before portaling — Stimulus targets must live inside the controller element.
    if (this.hasShellTarget) this.shellEl = this.shellTarget
    if (this.hasCardTarget) this.cardEl = this.cardTarget
    if (this.hasTitleTarget) this.titleEl = this.titleTarget
  }

  onToggle() {
    if (this.element.open) {
      this.open()
    } else {
      this.afterClose()
    }
  }

  open() {
    this.cacheRefs()
    this.portShell()
    if (this.shellEl) this.shellEl.hidden = false
    this.positionCard()
    this.bindOpenGuards()
    requestAnimationFrame(() => {
      this.positionCard()
      if (this.titleEl) {
        this.titleEl.focus({ preventScroll: true })
        if (typeof this.titleEl.select === "function") this.titleEl.select()
      }
    })
  }

  close(event) {
    event?.preventDefault()
    event?.stopPropagation()
    if (this.element.open) this.element.open = false
    this.afterClose()
  }

  afterClose() {
    this.unbindOpenGuards()
    if (this.shellEl) this.shellEl.hidden = true
    this.restoreShell()
    if (this.cardEl) {
      this.cardEl.style.left = ""
      this.cardEl.style.top = ""
      this.cardEl.style.transformOrigin = ""
    }
  }

  portShell() {
    if (!this.shellEl || this._ported) return
    this._placeholder = document.createComment("lp-floating-create-home")
    this.shellEl.parentNode.insertBefore(this._placeholder, this.shellEl)
    document.body.appendChild(this.shellEl)
    this._ported = true
  }

  restoreShell() {
    if (!this._ported || !this.shellEl || !this._placeholder?.parentNode) return
    this._placeholder.parentNode.insertBefore(this.shellEl, this._placeholder)
    this._placeholder.remove()
    this._placeholder = null
    this._ported = false
  }

  bindOpenGuards() {
    this.unbindOpenGuards()
    document.addEventListener("keydown", this._onKey)
    window.addEventListener("resize", this._onReposition)
    window.visualViewport?.addEventListener("resize", this._onReposition)
    window.addEventListener("scroll", this._onReposition, true)
    // Portaled shell is outside the controller element — wire Cancel / backdrop here.
    this.shellEl?.addEventListener("click", this._onShellClick)
  }

  unbindOpenGuards() {
    document.removeEventListener("keydown", this._onKey)
    window.removeEventListener("resize", this._onReposition)
    window.visualViewport?.removeEventListener("resize", this._onReposition)
    window.removeEventListener("scroll", this._onReposition, true)
    this.shellEl?.removeEventListener("click", this._onShellClick)
  }

  onShellClick(event) {
    const target = event.target
    if (!(target instanceof Element)) return

    const closes =
      target.closest(".lp-rpg-float-create__backdrop") ||
      target.closest(".lp-rpg-float-create__btn.is-cancel")
    if (!closes || !this.shellEl?.contains(closes)) return

    this.close(event)
  }

  onKeydown(event) {
    if (event.key === "Escape") {
      this.close(event)
      return
    }

    if (event.key !== "Enter" || event.target !== this.titleEl || event.isComposing) return
    const form = this.titleEl.form
    if (!form?.requestSubmit) return
    event.preventDefault()
    form.requestSubmit()
  }

  positionCard() {
    if (!this.cardEl || !this.element.open) return

    const trigger = this.element.querySelector("summary")
    if (!trigger) return

    const card = this.cardEl
    const rect = trigger.getBoundingClientRect()
    const margin = 12
    const gap = 10
    const width = Math.min(card.offsetWidth || 360, window.innerWidth - margin * 2)
    const height = card.offsetHeight || 280

    let left = rect.right - width
    left = Math.max(margin, Math.min(left, window.innerWidth - width - margin))

    let top = rect.bottom + gap
    if (top + height > window.innerHeight - margin) {
      top = Math.max(margin, rect.top - height - gap)
    }

    card.style.left = `${Math.round(left)}px`
    card.style.top = `${Math.round(top)}px`

    const originX = rect.left + rect.width / 2 - left
    const originY = rect.top + rect.height / 2 - top
    card.style.transformOrigin = `${Math.round(originX)}px ${Math.round(originY)}px`
  }
}
