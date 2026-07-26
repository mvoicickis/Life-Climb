import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["brand", "heroCopy", "heroImage", "fade", "cta", "lpCount"]

  connect() {
    requestAnimationFrame(() => {
      this.brandTarget?.classList.add("landing-in")
      this.heroCopyTarget?.classList.add("landing-in")
      this.heroImageTarget?.classList.add("landing-zoom")
      this.ctaTargets.forEach((el) => el.classList.add("is-ready"))
    })

    if (!("IntersectionObserver" in window)) {
      this.fadeTargets.forEach((el) => el.classList.add("landing-in"))
      this.animateLpCount()
      return
    }

    this.observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add("landing-in")
            if (this.hasLpCountTarget && entry.target.contains(this.lpCountTarget)) {
              this.animateLpCount()
            }
            this.observer.unobserve(entry.target)
          }
        })
      },
      { threshold: 0.18 }
    )

    this.fadeTargets.forEach((el) => {
      el.classList.add("landing-pre")
      this.observer.observe(el)
    })
  }

  animateLpCount() {
    if (!this.hasLpCountTarget || this.lpCountTarget.dataset.done === "true") return

    const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    const end = 250
    if (reduce) {
      this.lpCountTarget.textContent = String(end)
      this.lpCountTarget.dataset.done = "true"
      return
    }

    const start = performance.now()
    const duration = 1600
    const tick = (now) => {
      const t = Math.min(1, (now - start) / duration)
      const eased = 1 - Math.pow(1 - t, 3)
      this.lpCountTarget.textContent = String(Math.round(end * eased))
      if (t < 1) {
        requestAnimationFrame(tick)
      } else {
        this.lpCountTarget.dataset.done = "true"
      }
    }
    requestAnimationFrame(tick)
  }

  disconnect() {
    this.observer?.disconnect()
  }
}
