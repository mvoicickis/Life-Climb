import { Controller } from "@hotwired/stimulus"
import { queueIdle } from "lib/lp_overlay_queue"

const PADDING = 6
const BUBBLE_GAP = 16
const VIEWPORT_PAD = 10
const NAV_CLEARANCE = 76
const RING_INSET = 8
const GUIDE_FACE_ZONE = 52

export default class extends Controller {
  static targets = ["hole", "ring", "bubble", "capture", "guide", "copy"]
  static values = {
    selector: String,
    shape: { type: String, default: "auto" },
    side: { type: String, default: "above" },
    pick: { type: String, default: "first" },
    guideUrl: String,
    guideInitial: String,
    key: String,
    habitAddSelector: String,
    habitAddCopy: String,
    ackUrl: String
  }

  connect() {
    this.dismissed = false
    this.targetEl = null
    this.habitStage = this.keyValue === "habit" ? 1 : null
    this.boundReposition = this.reposition.bind(this)
    this.boundTurboRender = this.onTurboRender.bind(this)

    if (this.hasGuideTarget) {
      if (this.guideUrlValue) {
        this.guideTarget.style.backgroundImage = `url(${this.guideUrlValue})`
      } else if (this.guideInitialValue) {
        this.guideTarget.classList.add("is-initial")
        this.guideTarget.textContent = this.guideInitialValue
      }
    }

    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      this.element.classList.add("is-reduced-motion")
    } else if (this.hasBubbleTarget) {
      this.bubbleTarget.classList.add("is-spring")
    }

    void this.startWhenReady()
  }

  async startWhenReady() {
    const overlaysReady = await this.waitForOverlaysIdle()
    if (!overlaysReady || this.dismissed) return

    const found = await this.waitForTarget()
    if (!found || this.dismissed) return

    this.element.hidden = false
    this.reposition()
    window.addEventListener("resize", this.boundReposition)
    window.addEventListener("orientationchange", this.boundReposition)
    document.addEventListener("turbo:render", this.boundTurboRender)
  }

  disconnect() {
    this.teardownOverlayWait()
    window.removeEventListener("resize", this.boundReposition)
    window.removeEventListener("orientationchange", this.boundReposition)
    document.removeEventListener("turbo:render", this.boundTurboRender)
  }

  async onTurboRender() {
    if (this.dismissed) return
    if (!this.overlaysIdle()) {
      this.element.hidden = true
      await this.waitForOverlaysIdle()
      if (this.dismissed) return
      this.reposition()
      this.element.hidden = false
      return
    }
    this.reposition()
  }

  async waitForOverlaysIdle() {
    if (this.overlaysIdle()) return true

    return new Promise((resolve) => {
      const finish = (ok) => {
        this.teardownOverlayWait()
        resolve(ok)
      }

      const check = () => {
        if (this.dismissed) {
          finish(false)
          return
        }
        if (this.overlaysIdle()) finish(true)
      }

      const onSignal = () => check()

      document.addEventListener("lp-overlay-idle", onSignal)
      this._onOverlayIdle = onSignal

      this._overlayBodyObserver = new MutationObserver(onSignal)
      this._overlayBodyObserver.observe(document.body, {
        attributes: true,
        attributeFilter: [ "class" ]
      })

      this._overlayDomObserver = new MutationObserver(onSignal)
      this._overlayDomObserver.observe(document.body, {
        childList: true,
        subtree: true,
        attributes: true,
        attributeFilter: [ "hidden", "open" ]
      })

      requestAnimationFrame(check)
    })
  }

  teardownOverlayWait() {
    if (this._onOverlayIdle) {
      document.removeEventListener("lp-overlay-idle", this._onOverlayIdle)
      this._onOverlayIdle = null
    }
    this._overlayBodyObserver?.disconnect()
    this._overlayBodyObserver = null
    this._overlayDomObserver?.disconnect()
    this._overlayDomObserver = null
  }

  overlaysIdle() {
    if (!queueIdle()) return false
    if (document.body.classList.contains("lp-overlay-open")) return false
    if (document.querySelector("#first-camp-reveal-overlay:not([hidden])")) return false
    if (document.querySelector(".lp-base-camp-intro:not([hidden])")) return false
    if (document.querySelector('[data-controller~="today-finale"]:not([hidden])')) return false
    if (document.querySelector('[data-controller~="streak-moment"]:not([hidden])')) return false

    const climbDialog = document.querySelector("#climb-reward-host dialog[open]")
    if (climbDialog) return false

    return true
  }

  async waitForTarget() {
    for (let attempt = 0; attempt < 60; attempt += 1) {
      this.targetEl = this.findTarget()
      if (this.targetEl) return true
      await new Promise((resolve) => requestAnimationFrame(resolve))
    }
    this.dismissWithoutAckForCircle()
    return false
  }

  findTarget() {
    const sel = this.currentSelector()
    if (!sel) return null
    if (this.pickValue === "last") {
      const nodes = document.querySelectorAll(sel)
      return nodes.length ? nodes[nodes.length - 1] : null
    }
    return document.querySelector(sel)
  }

  currentSelector() {
    if (this.keyValue === "habit" && this.habitStage === 2 && this.habitAddSelectorValue) {
      return this.habitAddSelectorValue
    }
    return this.selectorValue
  }

  reposition() {
    this.targetEl = this.findTarget()
    if (!this.targetEl) return

    const rect = this.targetEl.getBoundingClientRect()
    if (rect.width < 1 && rect.height < 1) return

    const rawBox = this.spotlightBox(rect)
    const frameW = window.innerWidth
    const frameH = window.innerHeight
    const box = this.insetSpotlightBox(rawBox, frameW, frameH, this.targetEl)
    const radius = this.borderRadiusFor(this.targetEl)

    ;[this.holeTarget, this.ringTarget].forEach((el) => {
      el.hidden = false
      el.style.left = `${box.left}px`
      el.style.top = `${box.top}px`
      el.style.width = `${box.width}px`
      el.style.height = `${box.height}px`
      el.style.borderRadius = radius
    })

    this.placeBubble(box, frameW, frameH)
  }

  spotlightBox(rect) {
    return {
      left: rect.left - PADDING,
      top: rect.top - PADDING,
      width: rect.width + PADDING * 2,
      height: rect.height + PADDING * 2,
      right: rect.right + PADDING,
      bottom: rect.bottom + PADDING
    }
  }

  insetSpotlightBox(box, frameW, frameH, target = null) {
    const minTop = VIEWPORT_PAD + RING_INSET
    const minLeft = VIEWPORT_PAD + RING_INSET
    const maxRight = frameW - VIEWPORT_PAD - RING_INSET
    const inDashNav = target?.closest(".lp-dash-nav")
    const maxBottom = inDashNav
      ? frameH - VIEWPORT_PAD - RING_INSET
      : frameH - NAV_CLEARANCE - RING_INSET

    let { left, top, width, height } = box

    if (left < minLeft) {
      width -= minLeft - left
      left = minLeft
    }
    if (top < minTop) {
      height -= minTop - top
      top = minTop
    }
    if (left + width > maxRight) {
      width = maxRight - left
    }
    if (top + height > maxBottom) {
      height = maxBottom - top
    }

    width = Math.max(width, 12)
    height = Math.max(height, 12)

    return {
      left,
      top,
      width,
      height,
      right: left + width,
      bottom: top + height
    }
  }

  bubbleAnchorBox(spotlightBox) {
    if (this.keyValue === "circle") {
      const row = this.targetEl?.closest(".lp-today-v2-row")
      if (row) return this.spotlightBox(row.getBoundingClientRect())
    }
    return spotlightBox
  }

  aimPointX(spotlightBox, anchorBox) {
    return spotlightBox.left + spotlightBox.width / 2
  }

  borderRadiusFor(target) {
    const shape = this.shapeValue
    if (shape === "circle") return "50%"
    if (shape === "pill") return "0.75rem"
    const br = window.getComputedStyle(target).borderRadius
    if (br && br !== "0px") return br
    return "var(--lp-radius-card)"
  }

  placeBubble(spotlightBox, frameW, frameH) {
    const bubble = this.bubbleTarget
    let side = this.sideValue
    const anchorBox = this.bubbleAnchorBox(spotlightBox)

    bubble.hidden = false
    bubble.style.visibility = "hidden"
    bubble.style.left = "0"
    bubble.style.top = "0"
    bubble.style.right = "auto"
    bubble.style.bottom = "auto"
    bubble.style.transform = "none"
    bubble.classList.remove("is-guide-right")

    const bH = bubble.offsetHeight || 40
    const bW = bubble.offsetWidth || 120

    let left
    let top

    if (this.keyValue === "animal") {
      ;({ left, top } = this.animalBubblePosition(bW, frameW, frameH))
      side = "below"
    } else {
      ;({ left, top, side } = this.defaultBubblePosition(anchorBox, bW, bH, side, frameH, frameW))
      ;({ left, top, side } = this.avoidSpotlightOverlap(
        { left, top, side },
        anchorBox,
        spotlightBox,
        bW,
        bH,
        frameH,
        frameW
      ))
    }

    bubble.style.left = `${left}px`
    bubble.style.top = `${top}px`

    const aimX = this.aimPointX(spotlightBox, anchorBox)
    this.layoutArrow(bubble, left, aimX, side)

    bubble.style.visibility = ""
  }

  layoutArrow(bubble, bubbleLeft, aimX, side) {
    const baseW = bubble.offsetWidth
    let arrowX = aimX - bubbleLeft
    arrowX = this.clamp(arrowX, 14, baseW - 14)

    const inLeftFace = arrowX < GUIDE_FACE_ZONE
    bubble.classList.toggle("is-guide-right", inLeftFace)

    const adjustedBW = bubble.offsetWidth
    arrowX = this.clamp(aimX - bubbleLeft, 14, adjustedBW - 14)
    if (bubble.classList.contains("is-guide-right")) {
      const inRightFace = arrowX > adjustedBW - GUIDE_FACE_ZONE
      if (inRightFace) arrowX = adjustedBW - GUIDE_FACE_ZONE - 8
    }

    bubble.style.setProperty("--lp-first-tip-arrow-x", `${arrowX}px`)

    const bubbleBelowTarget = side === "below"
    bubble.classList.toggle("lp-first-tip__bubble--arrow-up", bubbleBelowTarget)
    bubble.classList.toggle("lp-first-tip__bubble--arrow-down", !bubbleBelowTarget)
  }

  defaultBubblePosition(anchorBox, bW, bH, side, frameH, frameW) {
    let top
    let left
    if (side === "below") {
      top = anchorBox.top + anchorBox.height + BUBBLE_GAP
      left = anchorBox.left + anchorBox.width / 2 - bW / 2
    } else {
      top = anchorBox.top - bH - BUBBLE_GAP
      left = anchorBox.left + anchorBox.width / 2 - bW / 2
    }

    top = this.clamp(top, VIEWPORT_PAD, frameH - bH - NAV_CLEARANCE)
    left = this.clamp(left, VIEWPORT_PAD, frameW - bW - VIEWPORT_PAD)

    const belowTop = anchorBox.top + anchorBox.height + BUBBLE_GAP
    const aboveTop = anchorBox.top - bH - BUBBLE_GAP
    const belowFits = belowTop + bH <= frameH - NAV_CLEARANCE
    const aboveFits = aboveTop >= VIEWPORT_PAD

    if (side === "below" && !belowFits && aboveFits) {
      side = "above"
      top = this.clamp(aboveTop, VIEWPORT_PAD, frameH - bH - NAV_CLEARANCE)
    } else if (side === "above" && !aboveFits && belowFits) {
      side = "below"
      top = belowTop
    }

    return { left, top, side }
  }

  animalBubblePosition(bW, frameW, frameH) {
    const name = document.querySelector(".lp-you__name-text.is-hero")
    const stats = document.querySelector(".lp-you__stats")
    const profile = document.querySelector(".lp-you__profile.is-hero")
    const bH = this.bubbleTarget.offsetHeight || 48

    let left = VIEWPORT_PAD
    let top = VIEWPORT_PAD

    if (name && stats) {
      const nameRect = name.getBoundingClientRect()
      const statsRect = stats.getBoundingClientRect()
      const gap = statsRect.top - nameRect.bottom

      top = nameRect.bottom + Math.max(BUBBLE_GAP, (gap - bH) / 2)
      top = this.clamp(top, nameRect.bottom + 4, statsRect.top - bH - 4)

      const profileRect = profile?.getBoundingClientRect()
      if (profileRect) {
        left = profileRect.left + profileRect.width / 2 - bW / 2
      } else {
        left = nameRect.left + nameRect.width / 2 - bW / 2
      }
    }

    left = this.clamp(left, VIEWPORT_PAD, frameW - bW - VIEWPORT_PAD)
    top = this.clamp(top, VIEWPORT_PAD, frameH - bH - NAV_CLEARANCE)

    return { left, top }
  }

  avoidSpotlightOverlap(pos, anchorBox, spotlightBox, bW, bH, frameH, frameW) {
    if (this.keyValue === "animal") return pos

    let { left, top, side } = pos
    const bubbleRect = () => ({
      left,
      top,
      right: left + bW,
      bottom: top + bH
    })

    const blocked =
      this.rectOverlap(bubbleRect(), anchorBox) || this.rectOverlap(bubbleRect(), spotlightBox)

    if (!blocked) return pos

    if (side === "above") {
      top = anchorBox.top + anchorBox.height + BUBBLE_GAP
      side = "below"
    } else {
      top = anchorBox.top - bH - BUBBLE_GAP
      side = "above"
    }

    top = this.clamp(top, VIEWPORT_PAD, frameH - bH - NAV_CLEARANCE)
    left = this.clamp(left, VIEWPORT_PAD, frameW - bW - VIEWPORT_PAD)

    return { left, top, side }
  }

  rectOverlap(a, b) {
    return !(a.right <= b.left || a.left >= b.right || a.bottom <= b.top || a.top >= b.bottom)
  }

  captureClick(event) {
    if (this.dismissed) return
    const target = this.targetEl || this.findTarget()
    if (!target) {
      this.dismissWithoutAckForCircle()
      return
    }
    const rect = target.getBoundingClientRect()
    const x = event.clientX
    const y = event.clientY
    const hit =
      x >= rect.left - PADDING &&
      x <= rect.right + PADDING &&
      y >= rect.top - PADDING &&
      y <= rect.bottom + PADDING

    if (hit) {
      if (this.keyValue === "habit" && this.habitStage === 1) {
        target.click()
        this.advanceHabitStage()
        return
      }
      this.dismissAndAct(target)
    } else {
      this.dismissWithoutAckForCircle()
    }
  }

  async advanceHabitStage() {
    this.habitStage = 2
    if (this.hasCopyTarget && this.habitAddCopyValue) {
      this.copyTarget.innerHTML = this.habitAddCopyValue
    }

    for (let attempt = 0; attempt < 40; attempt += 1) {
      await new Promise((resolve) => requestAnimationFrame(resolve))
      this.targetEl = this.findTarget()
      if (this.targetEl) {
        const body = this.targetEl.closest(".lp-dash-anytime__body")
        if (!body || !body.hidden) {
          break
        }
      }
    }

    this.reposition()
  }

  dismiss() {
    if (this.dismissed) return
    this.dismissed = true
    if (this.ackOnPlainDismiss()) void this.sendAck()
    this.element.remove()
  }

  dismissWithoutAckForCircle() {
    if (this.keyValue === "circle") {
      this.dismissSilently()
    } else {
      this.dismiss()
    }
  }

  dismissSilently() {
    if (this.dismissed) return
    this.dismissed = true
    this.element.remove()
  }

  ackOnPlainDismiss() {
    return this.keyValue !== "circle"
  }

  dismissAndAct(target) {
    const el = target
    if (this.dismissed) return
    this.dismissed = true
    void this.sendAck()
    this.element.remove()
    window.requestAnimationFrame(() => el.click())
  }

  async sendAck() {
    if (!this.ackUrlValue || !this.keyValue) return
    if (this.habitAckDeferred()) return

    try {
      const token = document.querySelector('meta[name="csrf-token"]')?.content
      await fetch(this.ackUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          "X-CSRF-Token": token
        },
        body: JSON.stringify({ key: this.keyValue }),
        credentials: "same-origin"
      })
    } catch (_err) {
      // Dismiss either way — no toast on Mountain surfaces.
    }
  }

  habitAckDeferred() {
    return this.keyValue === "habit" && this.habitStage === 1
  }

  clamp(n, min, max) {
    return Math.min(max, Math.max(min, n))
  }
}