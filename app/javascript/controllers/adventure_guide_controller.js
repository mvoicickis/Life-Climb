import { Controller } from "@hotwired/stimulus"

// Cinematic How the Game Works: stack → strike → persistence → map/badge.
export default class extends Controller {
  static targets = [
    "shell", "panel", "dot", "sceneLine", "flag", "bar", "pct",
    "wonNote", "winButton", "battleOne", "apPop", "remain", "mapNode", "badge"
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

    if (scene === "stack") this.playStack()
    if (scene === "persist") this.playRemain()
    if (scene === "map") this.playMap()
  }

  playStack() {
    this.flagTargets.forEach((flag) => flag.classList.remove("is-in"))
    if (this.reducedMotion()) {
      this.flagTargets.forEach((flag) => flag.classList.add("is-in"))
      return
    }

    // Staged beats: Goal → Plans → Projects → Battle peek (data-stack-beat 0..3)
    this.flagTargets.forEach((flag, i) => {
      const beat = Number(flag.dataset.stackBeat)
      const delay = Number.isFinite(beat) ? 160 + beat * 420 : 120 + i * 180
      this.queue(() => flag.classList.add("is-in"), delay)
    })
  }

  playRemain() {
    this.remainTargets.forEach((el) => el.classList.remove("is-pulse"))
    if (this.reducedMotion()) return
    this.remainTargets.forEach((el, i) => {
      this.queue(() => el.classList.add("is-pulse"), 200 + i * 160)
    })
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
