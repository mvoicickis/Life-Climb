import { Controller } from "@hotwired/stimulus"

// Cinematic How the Game Works: stack → strike → persistence → map/badge.
export default class extends Controller {
  static targets = [
    "shell", "panel", "dot", "sceneLine", "flag", "bar", "pct",
    "wonNote", "winButton", "battleOne", "apPop", "remain", "mapNode", "badge",
    "stackBody", "mountainHint"
  ]

  static values = {
    scenes: { type: Array, default: ["stack", "battle", "persist", "map"] },
    lines: { type: Array, default: [] }
  }

  connect() {
    this.index = 0
    this.timers = []
    this.linesValue = this.linesValue.length
      ? this.linesValue
      : [
          this.element.dataset.sceneStack || "The stack.",
          this.element.dataset.sceneBattle || "Strike.",
          this.element.dataset.scenePersist || "Not done yet.",
          this.element.dataset.sceneMap || "Your map."
        ]
    this.element.classList.add("is-alive")
    this.showPanel(0)
  }

  disconnect() {
    this.clearTimers()
  }

  next(event) {
    event?.preventDefault()
    this.showPanel(Math.min(this.index + 1, this.panelTargets.length - 1))
  }

  winBattle(event) {
    event?.preventDefault()
    if (this.hasWinButtonTarget && this.winButtonTarget.disabled) return

    if (this.hasWinButtonTarget) {
      this.winButtonTarget.disabled = true
      this.winButtonTarget.classList.add("is-won")
    }

    if (this.hasBattleOneTarget) {
      this.battleOneTarget.classList.add("is-struck")
      this.battleOneTarget.disabled = true
    }

    if (this.hasApPopTarget) {
      this.apPopTarget.hidden = false
      this.apPopTarget.classList.add("is-pop")
    }

    if (this.hasWonNoteTarget) this.wonNoteTarget.hidden = false

    this.animateProgress(40, 65)
    this.queue(() => this.showPanel(2), this.reducedMotion() ? 0 : 950)
  }

  stampBadge(event) {
    if (this.hasBadgeTarget) {
      this.badgeTarget.classList.add("is-stamp")
    }
    // Allow the form submit to continue (button_to).
  }

  showPanel(index) {
    this.clearTimers()
    this.index = index
    const scene = this.panelTargets[index]?.dataset.scene || this.scenesValue[index] || "stack"

    if (this.hasShellTarget) {
      this.shellTarget.dataset.scene = scene
    } else {
      this.element.dataset.scene = scene
    }

    this.panelTargets.forEach((panel, i) => {
      const on = i === index
      panel.classList.toggle("is-on", on)
      panel.classList.remove("is-ready")
      panel.hidden = !on
    })

    this.dotTargets.forEach((dot, i) => {
      dot.classList.toggle("is-on", i === index)
      dot.classList.toggle("is-done", i < index)
    })

    if (this.hasSceneLineTarget) {
      this.sceneLineTarget.textContent = this.linesValue[index] || ""
      this.sceneLineTarget.classList.remove("is-in")
      void this.sceneLineTarget.offsetWidth
      this.sceneLineTarget.classList.add("is-in")
    }

    if (this.hasStackBodyTarget) this.stackBodyTarget.classList.remove("is-in")
    if (this.hasMountainHintTarget) this.mountainHintTarget.classList.remove("is-in")

    if (scene === "stack") this.playStack()
    if (scene === "battle") this.playBattle()
    if (scene === "persist") this.playRemain()
    if (scene === "map") this.playMap()
  }

  playStack() {
    const panel = this.panelTargets[this.index]
    this.flagTargets.forEach((flag) => flag.classList.remove("is-in"))
    if (this.hasStackBodyTarget) this.stackBodyTarget.classList.remove("is-in")
    panel?.classList.remove("is-ready")

    if (this.reducedMotion()) {
      this.flagTargets.forEach((flag) => flag.classList.add("is-in"))
      if (this.hasStackBodyTarget) this.stackBodyTarget.classList.add("is-in")
      panel?.classList.add("is-ready")
      return
    }

    // Staged beats: Goal → Plans → Projects → Battle peek (data-stack-beat 0..3)
    this.flagTargets.forEach((flag, i) => {
      const beat = Number(flag.dataset.stackBeat)
      const delay = Number.isFinite(beat) ? 160 + beat * 480 : 120 + i * 180
      this.queue(() => flag.classList.add("is-in"), delay)
    })

    this.queue(() => {
      if (this.hasStackBodyTarget) this.stackBodyTarget.classList.add("is-in")
      panel?.classList.add("is-ready")
    }, 160 + 3 * 480 + 420)
  }

  playBattle() {
    if (this.hasBattleOneTarget) {
      this.battleOneTarget.classList.remove("is-struck")
      this.battleOneTarget.disabled = false
    }
    if (this.hasWinButtonTarget) {
      this.winButtonTarget.disabled = false
      this.winButtonTarget.classList.remove("is-won")
    }
    if (this.hasWonNoteTarget) this.wonNoteTarget.hidden = true
    if (this.hasApPopTarget) {
      this.apPopTarget.hidden = true
      this.apPopTarget.classList.remove("is-pop")
    }
    if (this.hasBarTarget && this.hasPctTarget) {
      this.barTarget.style.width = "40%"
      this.pctTarget.textContent = "40%"
    }
  }

  playRemain() {
    this.remainTargets.forEach((el) => el.classList.remove("is-pulse"))
    if (this.hasMountainHintTarget) this.mountainHintTarget.classList.remove("is-in")

    if (this.reducedMotion()) {
      if (this.hasMountainHintTarget) this.mountainHintTarget.classList.add("is-in")
      return
    }

    this.remainTargets.forEach((el, i) => {
      this.queue(() => el.classList.add("is-pulse"), 200 + i * 160)
    })
    this.queue(() => {
      if (this.hasMountainHintTarget) this.mountainHintTarget.classList.add("is-in")
    }, 520)
  }

  playMap() {
    this.mapNodeTargets.forEach((node) => node.classList.remove("is-in"))
    if (this.hasBadgeTarget) this.badgeTarget.classList.remove("is-stamp")
    if (this.reducedMotion()) {
      this.mapNodeTargets.forEach((node) => node.classList.add("is-in"))
      return
    }
    this.mapNodeTargets.forEach((node, i) => {
      this.queue(() => node.classList.add("is-in"), 140 + i * 160)
    })
  }

  animateProgress(from, to) {
    if (!this.hasBarTarget || !this.hasPctTarget) return

    if (this.reducedMotion()) {
      this.barTarget.style.width = `${to}%`
      this.pctTarget.textContent = `${to}%`
      return
    }

    this.barTarget.style.width = `${from}%`
    this.pctTarget.textContent = `${from}%`
    window.requestAnimationFrame(() => {
      this.barTarget.style.width = `${to}%`
      this.pctTarget.textContent = `${to}%`
    })
  }

  reducedMotion() {
    return window.matchMedia("(prefers-reduced-motion: reduce)").matches
  }

  queue(fn, ms) {
    this.timers.push(window.setTimeout(fn, ms))
  }

  clearTimers() {
    this.timers.forEach((id) => window.clearTimeout(id))
    this.timers = []
  }
}
