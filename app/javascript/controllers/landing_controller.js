import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["brand", "heroCopy", "heroImage", "fade"]

  connect() {
    requestAnimationFrame(() => {
      this.brandTarget?.classList.add("landing-in")
      this.heroCopyTarget?.classList.add("landing-in")
      this.heroImageTarget?.classList.add("landing-zoom")
    })

    if (!("IntersectionObserver" in window)) {
      this.fadeTargets.forEach((el) => el.classList.add("landing-in"))
      return
    }

    this.observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add("landing-in")
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

  disconnect() {
    this.observer?.disconnect()
  }
}
