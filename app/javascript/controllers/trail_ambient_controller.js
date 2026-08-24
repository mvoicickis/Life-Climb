import { Controller } from "@hotwired/stimulus"

// Sun/moon arc + mist/ember toggles driven by local clock.
export default class extends Controller {
  static targets = ["sun", "moon", "mist", "embers"]
  static values = { dormant: Boolean }

  connect() {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      this.applyStatic()
      return
    }

    this.tick()
    this._timer = window.setInterval(() => this.tick(), 60_000)
  }

  disconnect() {
    if (this._timer) window.clearInterval(this._timer)
    this._timer = null
  }

  tick() {
    const now = new Date()
    const hrs = now.getHours() + now.getMinutes() / 60
    const isDay = hrs >= 6 && hrs < 18
    const cycleFrac = isDay
      ? (hrs - 6) / 12
      : (hrs >= 18 ? (hrs - 18) / 12 : (hrs + 6) / 12)

    const x = 8 + cycleFrac * 84
    const y = 28 - Math.sin(cycleFrac * Math.PI) * 18

    const root = this.element
    root.classList.toggle("is-day", isDay)
    root.classList.toggle("is-night", !isDay)
    root.classList.toggle("is-dormant", this.dormantValue)

    if (isDay) {
      // Park sun near peak during day (mockup).
      root.style.setProperty("--lp-trail-sun-x", "56.6%")
      root.style.setProperty("--lp-trail-sun-y", "20%")
      root.style.setProperty("--lp-trail-night", "0")
      const warm =
        cycleFrac < 0.12
          ? ((0.12 - cycleFrac) / 0.12) * 0.22
          : cycleFrac > 0.88
            ? ((cycleFrac - 0.88) / 0.12) * 0.22
            : 0
      root.style.setProperty("--lp-trail-warm", warm.toFixed(3))
    } else {
      root.style.setProperty("--lp-trail-moon-x", `${x}%`)
      root.style.setProperty("--lp-trail-moon-y", `${y}%`)
      const nightDepth = Math.sin(cycleFrac * Math.PI)
      root.style.setProperty("--lp-trail-night", (0.12 + nightDepth * 0.5).toFixed(3))
      root.style.setProperty("--lp-trail-warm", "0")
    }

    // Mist when dormant (no open battles) or dawn/dusk; embers at night.
    const misty = this.dormantValue || (!isDay && cycleFrac < 0.2) || (isDay && (cycleFrac < 0.08 || cycleFrac > 0.92))
    const showEmbers = !isDay || hrs >= 17
    this.toggleMist(misty)
    this.toggleEmbers(showEmbers)
  }

  applyStatic() {
    const root = this.element
    const hrs = new Date().getHours()
    const isDay = hrs >= 6 && hrs < 18
    root.classList.toggle("is-day", isDay)
    root.classList.toggle("is-night", !isDay)
    root.classList.toggle("is-dormant", this.dormantValue)
    root.style.setProperty("--lp-trail-sun-x", "56.6%")
    root.style.setProperty("--lp-trail-sun-y", "20%")
    root.style.setProperty("--lp-trail-moon-x", "72%")
    root.style.setProperty("--lp-trail-moon-y", "16%")
    root.style.setProperty("--lp-trail-night", isDay ? "0" : "0.28")
    root.style.setProperty("--lp-trail-warm", "0")
    root.style.setProperty("--lp-trail-mist", this.dormantValue ? "0.4" : "0")
    root.classList.toggle("is-mist", this.dormantValue)
    root.classList.remove("is-embers")
  }

  toggleMist(on) {
    this.element.classList.toggle("is-mist", on)
    this.element.style.setProperty("--lp-trail-mist", on ? (this.dormantValue ? "0.4" : "0.28") : "0")
    if (this.hasMistTarget) this.mistTarget.classList.toggle("is-on", on)
  }

  toggleEmbers(on) {
    this.element.classList.toggle("is-embers", on)
    if (this.hasEmbersTarget) this.embersTarget.classList.toggle("is-on", on)
  }
}
