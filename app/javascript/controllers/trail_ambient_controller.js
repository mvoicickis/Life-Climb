import { Controller } from "@hotwired/stimulus"

// Sun/moon arc, stars, snow, backlight, lightning, companion wind — local clock.
export default class extends Controller {
  static targets = [
    "sun", "moon", "mist", "embers", "stars", "snow",
    "backlight", "lightning", "footprints", "companion"
  ]
  static values = {
    dormant: Boolean,
    builtinPhotos: Boolean,
    campsDone: { type: Number, default: 0 },
    campsTotal: { type: Number, default: 0 },
    openBattles: { type: Number, default: 0 },
    energy: { type: Number, default: 0 }
  }

  connect() {
    this._reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    if (this.builtinPhotosValue) {
      if (this._reduced) {
        this.applyBuiltinPhotosStatic()
      } else {
        this.tickBuiltinPhotos()
        this._timer = window.setInterval(() => this.tickBuiltinPhotos(), 60_000)
      }
      return
    }

    if (this._reduced) {
      this.applyStatic()
      return
    }

    this.tick()
    this._timer = window.setInterval(() => this.tick(), 60_000)
    this.scheduleLightning()
    this.syncEmberIntensity()
  }

  disconnect() {
    if (this._timer) window.clearInterval(this._timer)
    if (this._lightningTimer) window.clearTimeout(this._lightningTimer)
    this._timer = null
    this._lightningTimer = null
  }

  tickBuiltinPhotos() {
    const now = new Date()
    const hrs = now.getHours() + now.getMinutes() / 60
    const isDay = hrs >= 6 && hrs < 18
    const root = this.element

    root.classList.toggle("is-day", isDay)
    root.classList.toggle("is-night", !isDay)
    root.classList.toggle("is-dormant", this.dormantValue)
    root.classList.remove("is-stars", "is-snow", "is-mist", "is-embers")
    this.ensureNightPhotoLoaded(isDay)
  }

  applyBuiltinPhotosStatic() {
    const root = this.element
    const hrs = new Date().getHours()
    const isDay = hrs >= 6 && hrs < 18

    root.classList.toggle("is-day", isDay)
    root.classList.toggle("is-night", !isDay)
    root.classList.toggle("is-dormant", this.dormantValue)
    root.classList.remove("is-stars", "is-snow", "is-mist", "is-embers")
    this.ensureNightPhotoLoaded(isDay)
  }

  tick() {
    const now = new Date()
    const hrs = now.getHours() + now.getMinutes() / 60
    const isDay = hrs >= 6 && hrs < 18
    const cycleFrac = isDay
      ? (hrs - 6) / 12
      : (hrs >= 18 ? (hrs - 18) / 12 : (hrs + 6) / 12)

    // Light elevation: 1 at noon, 0 at the horizon.
    const sunElev = isDay ? Math.sin(cycleFrac * Math.PI) : 0
    const x = 8 + cycleFrac * 84
    const y = 28 - Math.sin(cycleFrac * Math.PI) * 18

    const root = this.element
    root.classList.toggle("is-day", isDay)
    root.classList.toggle("is-night", !isDay)
    root.classList.toggle("is-dormant", this.dormantValue)
    if (!this.builtinPhotosValue) {
      root.classList.toggle("is-stars", !isDay)
    } else {
      root.classList.remove("is-stars")
    }
    root.classList.toggle("is-snow", this.isSnowSeason(now))

    const backlightSize = Math.round(300 + (1 - sunElev) * 260)
    const windOpacity = (!isDay && this.openBattlesValue > 0 && !this.dormantValue)
      ? Math.min(0.55, 0.18 + this.openBattlesValue * 0.06)
      : 0

    root.style.setProperty("--lp-trail-backlight-size", `${backlightSize}px`)
    root.style.setProperty("--lp-trail-backlight", isDay
      ? (0.18 + sunElev * 0.35).toFixed(3)
      : "0.08")
    root.style.setProperty("--lp-trail-wind-opacity", windOpacity.toFixed(3))
    root.style.setProperty("--lp-trail-stars", (!isDay ? (0.35 + Math.sin(cycleFrac * Math.PI) * 0.55) : 0).toFixed(3))

    if (this.builtinPhotosValue) {
      this.ensureNightPhotoLoaded(isDay)
    }

    if (isDay) {
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
      if (this.builtinPhotosValue) {
        root.style.setProperty("--lp-trail-night", "0")
      } else {
        const nightDepth = Math.sin(cycleFrac * Math.PI)
        root.style.setProperty("--lp-trail-night", (0.12 + nightDepth * 0.5).toFixed(3))
      }
      root.style.setProperty("--lp-trail-warm", "0")
    }

    const misty = (!isDay && cycleFrac < 0.2) || (isDay && (cycleFrac < 0.08 || cycleFrac > 0.92))
    const showEmbers = !isDay || hrs >= 17
    this.toggleMist(misty)
    this.toggleEmbers(showEmbers)
    this.syncEmberIntensity()

    if (this.hasCompanionTarget) {
      const windy = windOpacity > 0.15
      this.companionTarget.classList.toggle("is-wind", windy)
    }
  }

  isSnowSeason(date = new Date()) {
    const m = date.getMonth() + 1
    return m === 11 || m === 12 || m === 1 || m === 2
  }

  scheduleLightning() {
    if (this._reduced) return
    const delay = 45_000 + Math.random() * 45_000
    this._lightningTimer = window.setTimeout(() => {
      this.flashLightning()
      this.scheduleLightning()
    }, delay)
  }

  flashLightning() {
    const now = new Date()
    const hrs = now.getHours()
    const isNight = hrs < 6 || hrs >= 18
    if (!isNight || this.dormantValue || this.openBattlesValue <= 0) return
    if (!this.hasLightningTarget) return

    this.lightningTarget.classList.remove("is-flash")
    // Force reflow so the animation can restart.
    void this.lightningTarget.offsetWidth
    this.lightningTarget.classList.add("is-flash")
    window.setTimeout(() => this.lightningTarget.classList.remove("is-flash"), 700)
  }

  applyStatic() {
    const root = this.element
    const hrs = new Date().getHours()
    const isDay = hrs >= 6 && hrs < 18
    root.classList.toggle("is-day", isDay)
    root.classList.toggle("is-night", !isDay)
    root.classList.toggle("is-dormant", this.dormantValue)
    if (!this.builtinPhotosValue) {
      root.classList.toggle("is-stars", !isDay)
    } else {
      root.classList.remove("is-stars")
    }
    root.classList.toggle("is-snow", this.isSnowSeason())
    root.style.setProperty("--lp-trail-sun-x", "56.6%")
    root.style.setProperty("--lp-trail-sun-y", "20%")
    root.style.setProperty("--lp-trail-moon-x", "72%")
    root.style.setProperty("--lp-trail-moon-y", "16%")
    if (this.builtinPhotosValue) {
      this.ensureNightPhotoLoaded(isDay)
      root.style.setProperty("--lp-trail-night", "0")
    } else {
      root.style.setProperty("--lp-trail-night", isDay ? "0" : "0.28")
    }
    root.style.setProperty("--lp-trail-warm", "0")
    root.style.setProperty("--lp-trail-mist", "0")
    root.style.setProperty("--lp-trail-backlight-size", "360px")
    root.style.setProperty("--lp-trail-backlight", isDay ? "0.3" : "0.08")
    root.style.setProperty("--lp-trail-stars", isDay ? "0" : "0.55")
    root.style.setProperty("--lp-trail-wind-opacity", "0")
    root.classList.remove("is-mist")
    root.classList.remove("is-embers")
    this.syncEmberIntensity()
  }

  syncEmberIntensity() {
    const energy = Math.min(1, Math.max(0, this.energyValue))
    this.element.style.setProperty("--lp-trail-energy", energy.toFixed(3))

    if (!this.hasEmbersTarget) return
    const embers = this.embersTarget.querySelectorAll(".lp-trail__ember")
    const active = Math.max(1, Math.round(2 + energy * 6))
    embers.forEach((ember, index) => {
      const on = index < active
      ember.style.opacity = on ? String(0.25 + energy * 0.75) : "0"
      ember.style.animationPlayState = on ? "running" : "paused"
    })
  }

  toggleMist(on) {
    this.element.classList.toggle("is-mist", on)
    this.element.style.setProperty("--lp-trail-mist", on ? "0.28" : "0")
    if (this.hasMistTarget) this.mistTarget.classList.toggle("is-on", on)
  }

  toggleEmbers(on) {
    this.element.classList.toggle("is-embers", on)
    if (this.hasEmbersTarget) this.embersTarget.classList.toggle("is-on", on)
  }

  ensureNightPhotoLoaded(isDay) {
    if (isDay) return
    const img = this.element.querySelector(".lp-trail__photo--night")
    if (!img || img.getAttribute("src")) return
    const src = img.dataset.src
    if (src) img.src = src
  }
}
