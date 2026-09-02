import { Controller } from "@hotwired/stimulus"

// Five-bubble Mountain tour after new onboarding bootstrap.
export default class extends Controller {
  static targets = ["overlay", "spotlight", "bubble", "step", "text", "actions"]
  static values = {
    url: String,
    eventsUrl: String,
    steps: Array
  }

  connect() {
    this.index = 0
    this._onReflow = () => this.schedulePosition()
    this._scrollRoot = document.querySelector("#mountain-trail .lp-trail__scroll")

    window.addEventListener("resize", this._onReflow, { passive: true })
    window.addEventListener("scroll", this._onReflow, true)
    if (this._scrollRoot) this._scrollRoot.addEventListener("scroll", this._onReflow, { passive: true })

    this._resizeObserver = new ResizeObserver(() => this.schedulePosition())

    requestAnimationFrame(() => requestAnimationFrame(() => this.show()))
  }

  disconnect() {
    window.removeEventListener("resize", this._onReflow)
    window.removeEventListener("scroll", this._onReflow, true)
    if (this._scrollRoot) this._scrollRoot.removeEventListener("scroll", this._onReflow)
    this._resizeObserver?.disconnect()
    if (this._positionFrame) cancelAnimationFrame(this._positionFrame)
  }

  schedulePosition() {
    if (this._positionFrame) cancelAnimationFrame(this._positionFrame)
    this._positionFrame = requestAnimationFrame(() => {
      requestAnimationFrame(() => this.position())
    })
  }

  show() {
    const step = this.stepsValue[this.index]
    if (!step) return

    this.trackStep("viewed", step.key)

    this.overlayTarget.hidden = false
    this.overlayTarget.classList.add("is-active")
    this.bubbleTarget.hidden = false
    this.stepTarget.textContent = step.step
    this.textTarget.textContent = step.text
    this.actionsTarget.innerHTML = ""

    if (step.final) {
      this._resizeObserver.disconnect()
      this.spotlightTarget.hidden = true
      this.bubbleTarget.classList.add("is-centered")
      this.bubbleTarget.style.top = "50%"
      this.bubbleTarget.style.left = "50%"

      const btn = document.createElement("a")
      btn.href = step.todayUrl
      btn.className = "lp-onboarding-tour__cta"
      btn.textContent = step.todayLabel
      btn.dataset.turbo = "false"
      btn.addEventListener("click", () => {
        this.trackStep("completed", step.key)
        this.persist()
      })
      this.actionsTarget.appendChild(btn)
    } else {
      this.bubbleTarget.classList.remove("is-centered")
      this.bubbleTarget.style.top = ""
      this.bubbleTarget.style.left = ""
      this.spotlightTarget.hidden = false

      const skip = document.createElement("button")
      skip.type = "button"
      skip.className = "lp-onboarding-tour__skip"
      skip.textContent = step.skipLabel
      skip.addEventListener("click", () => this.dismiss())

      const next = document.createElement("button")
      next.type = "button"
      next.className = "lp-onboarding-tour__next"
      next.textContent = step.nextLabel
      next.addEventListener("click", () => this.next())

      this.actionsTarget.append(skip, next)
      this.observeTarget(step.target)

      if (step.target === "onboarding-tour-add-camp") {
        requestAnimationFrame(() => this.schedulePosition())
      } else {
        this.schedulePosition()
      }
    }

    this.bubbleTarget.classList.add("is-visible")
  }

  observeTarget(targetId) {
    this._resizeObserver.disconnect()
    const el = this.targetElement(targetId)
    if (el) this._resizeObserver.observe(el)
  }

  targetElement(targetId) {
    return document.getElementById(targetId)
  }

  usableRegion() {
    const margin = 12
    const style = getComputedStyle(document.documentElement)
    const safeTop = parseFloat(style.getPropertyValue("env(safe-area-inset-top)")) || 0
    const safeLeft = parseFloat(style.getPropertyValue("env(safe-area-inset-left)")) || 0
    const safeRight = parseFloat(style.getPropertyValue("env(safe-area-inset-right)")) || 0
    const viewportBottom = window.innerHeight

    let top = safeTop + margin
    const hud = document.querySelector(".lp-trail-hud")
    if (hud) {
      const hr = hud.getBoundingClientRect()
      if (hr.height > 0 && hr.bottom > 0) top = Math.max(top, hr.bottom + margin)
    }

    let bottom = viewportBottom - margin
    const nav = document.querySelector(".lp-dash-nav")
    if (nav) {
      const nr = nav.getBoundingClientRect()
      if (nr.height > 0 && nr.top < viewportBottom) bottom = Math.min(bottom, nr.top - margin)
    }

    const fab = document.querySelector(".lp-dash-nav__fab")
    if (fab) {
      const fr = fab.getBoundingClientRect()
      if (fr.height > 0 && fr.top < viewportBottom) bottom = Math.min(bottom, fr.top - margin)
    }

    const dock = document.querySelector(".lp-trail__dock")
    if (dock) {
      const dr = dock.getBoundingClientRect()
      if (dr.height > 0 && dr.top < viewportBottom) bottom = Math.min(bottom, dr.top - margin)
    }

    return {
      top,
      left: safeLeft + margin,
      right: window.innerWidth - safeRight - margin,
      bottom
    }
  }

  intersectRect(a, b) {
    const left = Math.max(a.left, b.left)
    const top = Math.max(a.top, b.top)
    const right = Math.min(a.right, b.right)
    const bottom = Math.min(a.bottom, b.bottom)
    if (right <= left || bottom <= top) return null

    return { left, top, right, bottom, width: right - left, height: bottom - top }
  }

  paddedRect(rect, pad) {
    return {
      left: rect.left - pad,
      top: rect.top - pad,
      right: rect.right + pad,
      bottom: rect.bottom + pad,
      width: rect.width + pad * 2,
      height: rect.height + pad * 2
    }
  }

  scrollTargetIntoSafeArea(el, region) {
    el.scrollIntoView({ block: "center", inline: "center", behavior: "instant" })
    this.nudgeTargetIntoRegion(el, region)
  }

  nudgeTargetIntoRegion(el, region) {
    if (!this._scrollRoot) return

    for (let pass = 0; pass < 2; pass += 1) {
      const rect = el.getBoundingClientRect()
      let delta = 0
      if (rect.bottom > region.bottom) delta += rect.bottom - region.bottom
      if (rect.top < region.top) delta -= region.top - rect.top
      if (delta === 0) break
      this._scrollRoot.scrollTop += delta
    }
  }

  rectsOverlap(a, b, margin = 12) {
    return !(
      a.right + margin <= b.left ||
      a.left >= b.right + margin ||
      a.bottom + margin <= b.top ||
      a.top >= b.bottom + margin
    )
  }

  placeBubble(spotlightRect, region, bubble, preferredPlacement) {
    const margin = 12
    const bubbleW = bubble.offsetWidth || 264
    const bubbleH = bubble.offsetHeight || 120

    const spaceAbove = spotlightRect.top - region.top
    const spaceBelow = region.bottom - spotlightRect.bottom
    const fitsAbove = spaceAbove >= bubbleH + margin
    const fitsBelow = spaceBelow >= bubbleH + margin

    let below
    if (fitsBelow && fitsAbove) {
      below = preferredPlacement !== "above"
    } else if (fitsBelow) {
      below = true
    } else if (fitsAbove) {
      below = false
    } else {
      below = spaceBelow >= spaceAbove
    }

    const bubbleRectAt = (isBelow, left) => {
      const top = isBelow
        ? spotlightRect.bottom + margin
        : spotlightRect.top - bubbleH - margin
      return { left, top, right: left + bubbleW, bottom: top + bubbleH }
    }

    let left = spotlightRect.left + spotlightRect.width / 2 - bubbleW / 2
    left = Math.max(region.left, Math.min(left, region.right - bubbleW))

    let br = bubbleRectAt(below, left)
    if (this.rectsOverlap(br, spotlightRect)) {
      below = !below
      br = bubbleRectAt(below, left)
    }

    if (this.rectsOverlap(br, spotlightRect)) {
      let top = region.top
      br = { left, top, right: left + bubbleW, bottom: top + bubbleH }
      if (this.rectsOverlap(br, spotlightRect)) {
        top = Math.min(region.bottom - bubbleH, spotlightRect.bottom + margin)
        br = { left, top, right: left + bubbleW, bottom: top + bubbleH }
      }
    }

    let top = Math.max(region.top, Math.min(br.top, region.bottom - bubbleH))
    left = Math.max(region.left, Math.min(br.left, region.right - bubbleW))

    bubble.style.top = `${top}px`
    bubble.style.left = `${left}px`
  }

  position() {
    const step = this.stepsValue[this.index]
    if (!step || step.final) return

    const el = this.targetElement(step.target)
    if (!el) return

    const region = this.usableRegion()
    if (step.scrollIntoView !== false) {
      this.scrollTargetIntoSafeArea(el, region)
    }

    const raw = el.getBoundingClientRect()
    if (raw.width <= 0 || raw.height <= 0) return

    const pad = 8
    const padded = this.paddedRect(raw, pad)
    const regionRect = {
      left: region.left,
      top: region.top,
      right: region.right,
      bottom: region.bottom
    }

    const fitsInRegion =
      padded.top >= region.top &&
      padded.bottom <= region.bottom &&
      padded.left >= region.left &&
      padded.right <= region.right

    let spotlightRect = padded
    if (!fitsInRegion) {
      const intersection = this.intersectRect(padded, regionRect)
      if (intersection) spotlightRect = intersection
    }

    const spotlight = this.spotlightTarget
    spotlight.style.top = `${spotlightRect.top}px`
    spotlight.style.left = `${spotlightRect.left}px`
    spotlight.style.width = `${spotlightRect.width}px`
    spotlight.style.height = `${spotlightRect.height}px`

    this.placeBubble(spotlightRect, region, this.bubbleTarget, step.placement)
  }

  next() {
    const step = this.stepsValue[this.index]
    if (step?.key) this.trackStep("completed", step.key)

    this.index += 1
    this.bubbleTarget.classList.remove("is-visible")
    requestAnimationFrame(() => this.show())
  }

  dismiss() {
    const step = this.stepsValue[this.index]
    if (step?.key) this.trackStep("completed", step.key)

    this.persist()
    this.hide()
  }

  hide() {
    this.overlayTarget.classList.remove("is-active")
    this.bubbleTarget.classList.remove("is-visible")
    setTimeout(() => { this.overlayTarget.hidden = true }, 250)
  }

  async persist() {
    const url = this.urlValue
    if (!url) return
    const token = document.querySelector("meta[name='csrf-token']")?.content
    const body = new URLSearchParams()
    body.set("authenticity_token", token || "")
    try {
      await fetch(url, { method: "PATCH", headers: { Accept: "text/vnd.turbo-stream.html" }, body })
    } catch (_e) {
      // Tour is non-blocking; user can still climb.
    }
  }

  trackStep(event, key) {
    const url = this.eventsUrlValue
    if (!url || !key) return

    const token = document.querySelector("meta[name='csrf-token']")?.content
    const body = new URLSearchParams()
    body.set("authenticity_token", token || "")
    body.set("event", event)
    body.set("step", key)

    fetch(url, {
      method: "POST",
      headers: { Accept: "application/json" },
      body
    }).catch(() => {
      // Analytics is non-blocking.
    })
  }
}
