import { Controller } from "@hotwired/stimulus"

const PARALLAX_FACTOR = 0.14
const PARALLAX_CLAMP = 32
const TAP_MS = 12

// Feature-detect Vibration API — iOS has no navigator.vibrate (silent no-op).
export function tapHaptic(nav = typeof navigator !== "undefined" ? navigator : null) {
  if (nav && typeof nav.vibrate === "function") {
    nav.vibrate(TAP_MS)
  }
}

// Vertical climb path — focus scroll, entrance IO, scenic parallax, tap haptic.
export default class extends Controller {
  static targets = ["current", "selected", "node"]

  connect() {
    this.scrollRoot = this.element.closest(".lp-rpg__stage-trail")
    this.scenic = document.querySelector(".lp-rpg-scenic")
    this._parallaxRaf = null
    this._onScroll = () => this.queueParallax()

    this.setupEntrance()
    this.setupParallax()
  }

  disconnect() {
    this.teardownEntrance()
    this.teardownParallax()
  }

  scrollToFocus({ behavior } = {}) {
    const el = this.hasSelectedTarget
      ? this.selectedTarget
      : (this.hasCurrentTarget ? this.currentTarget : null)
    if (!el) return

    const reduce = this.prefersReducedMotion()
    el.scrollIntoView({
      block: "center",
      inline: "nearest",
      behavior: behavior || (reduce ? "auto" : "smooth")
    })
  }

  tap() {
    tapHaptic()
  }

  prefersReducedMotion() {
    return window.matchMedia("(prefers-reduced-motion: reduce)").matches
  }

  setupEntrance() {
    const nodes = this.nodeTargets
    if (!nodes.length) return

    // Flat list cards must paint immediately. Trail pins still fade in on scroll.
    if (
      this.element.classList.contains("is-list") ||
      this.prefersReducedMotion() ||
      !("IntersectionObserver" in window)
    ) {
      nodes.forEach((el) => {
        el.classList.remove("is-pending")
        el.classList.add("is-visible")
      })
      return
    }

    this.observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (!entry.isIntersecting) return
          entry.target.classList.remove("is-pending")
          entry.target.classList.add("is-visible")
          this.observer.unobserve(entry.target)
        })
      },
      {
        root: this.scrollRoot || null,
        threshold: 0.12,
        rootMargin: "0px 0px -8% 0px"
      }
    )

    nodes.forEach((el) => {
      el.classList.add("is-pending")
      this.observer.observe(el)
    })
  }

  teardownEntrance() {
    this.observer?.disconnect()
    this.observer = null
  }

  setupParallax() {
    if (this.prefersReducedMotion() || !this.scrollRoot || !this.scenic) return

    this.scrollRoot.addEventListener("scroll", this._onScroll, { passive: true })
    this.queueParallax()
  }

  teardownParallax() {
    this.scrollRoot?.removeEventListener("scroll", this._onScroll)
    if (this._parallaxRaf) {
      cancelAnimationFrame(this._parallaxRaf)
      this._parallaxRaf = null
    }
    if (this.scenic) this.scenic.style.transform = ""
  }

  queueParallax() {
    if (this._parallaxRaf) return
    this._parallaxRaf = requestAnimationFrame(() => {
      this._parallaxRaf = null
      this.applyParallax()
    })
  }

  applyParallax() {
    if (!this.scrollRoot || !this.scenic) return
    const y = Math.max(-PARALLAX_CLAMP, Math.min(PARALLAX_CLAMP, -this.scrollRoot.scrollTop * PARALLAX_FACTOR))
    this.scenic.style.transform = `translate3d(0, ${y}px, 0)`
  }
}
