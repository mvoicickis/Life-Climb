import { Controller } from "@hotwired/stimulus"

// Camp notebook: Plan working area with progressive project → battle disclosure.
// Also drives the reactive tent + path spark on the mountain.
export default class extends Controller {
  static targets = [
    "notebook",
    "mountain",
    "goalPanel",
    "planPanel",
    "projectItem",
    "title",
    "crumb",
    "crumbPlan",
    "crumbPlanTitle",
    "crumbPlanSep",
    "crumbProject",
    "crumbProjectTitle",
    "crumbProjectSep",
    "contextAdd",
    "goalAdd",
    "reactTent",
    "reactTentLabel",
    "wire",
    "spark"
  ]

  static values = {
    planId: Number,
    projectId: Number,
    goalId: Number,
    journeyUrl: String,
    autoOpen: Boolean
  }

  connect() {
    if (this.planIdValue) {
      this.showNotebook()
      this.showPlanPanel(this.planIdValue)
      if (this.projectIdValue) this.expandProject(this.projectIdValue, { pulse: false })
      else this.clearReactTent()
    } else if (this.autoOpenValue) {
      this.focusGoal()
    }
  }

  openPlan(event) {
    event?.preventDefault()
    const btn = event.currentTarget
    const planId = Number(btn.dataset.planId)
    const title = btn.dataset.planTitle || ""
    this.planIdValue = planId
    this.projectIdValue = 0
    this.showNotebook()
    this.showPlanPanel(planId, title)
    this.clearReactTent()
    this.pulsePath(["is-goal", "is-plan"])
    this.pushHistory(planId)
    this.highlightPlanOnMap(planId)
  }

  openPlanById(planId, title = "") {
    this.planIdValue = Number(planId)
    this.projectIdValue = 0
    this.showNotebook()
    this.showPlanPanel(this.planIdValue, title)
    this.clearReactTent()
    this.pulsePath(["is-goal", "is-plan"])
    this.pushHistory(this.planIdValue)
    this.highlightPlanOnMap(this.planIdValue)
  }

  toggleProject(event) {
    event.preventDefault()
    const btn = event.currentTarget
    const projectId = Number(btn.dataset.projectId)
    const title = btn.dataset.projectTitle || ""
    const planId = Number(btn.dataset.planId || this.planIdValue)

    if (this.projectIdValue === projectId) {
      this.collapseProject(projectId)
      this.projectIdValue = 0
      this.clearReactTent()
      this.updateCrumb({ planId, projectId: 0 })
      this.updateContextAdd()
      this.pushHistory(planId)
      return
    }

    this.planIdValue = planId
    this.projectIdValue = projectId
    this.expandProject(projectId, { title, pulse: true })
    this.showReactTent(title)
    this.updateCrumb({ planId, projectId, projectTitle: title })
    this.updateContextAdd()
    this.pushHistory(projectId)
  }

  focusGoal(event) {
    event?.preventDefault()
    this.planIdValue = 0
    this.projectIdValue = 0
    this.showNotebook()
    this.showGoalPanel()
    this.clearReactTent()
    this.pulsePath(["is-goal"])
    this.pushHistory(this.goalIdValue || null)
  }

  focusPlanCrumb(event) {
    event?.preventDefault()
    if (!this.planIdValue) return
    this.projectIdValue = 0
    this.showPlanPanel(this.planIdValue)
    this.collapseAllProjects()
    this.clearReactTent()
    this.updateContextAdd()
    this.pulsePath(["is-goal", "is-plan"])
    this.pushHistory(this.planIdValue)
  }

  contextAdd(event) {
    event?.preventDefault()
    if (this.projectIdValue) {
      const item = this.projectItemTargets.find(
        (el) => Number(el.dataset.projectId) === this.projectIdValue
      )
      const add = item?.querySelector(".lp-camp-notebook__add.is-battle")
      if (add) {
        add.open = true
        add.querySelector("input[type='text'], input:not([type='hidden'])")?.focus()
      }
      return
    }
    if (this.planIdValue) {
      const panel = this.planPanelTargets.find(
        (el) => Number(el.dataset.planId) === this.planIdValue
      )
      const add = panel?.querySelector(".lp-camp-notebook__add.is-project")
      if (add) {
        add.open = true
        add.querySelector("input[type='text'], input:not([type='hidden'])")?.focus()
      }
      return
    }
    if (this.hasGoalAddTarget) {
      this.goalAddTarget.hidden = false
      this.goalAddTarget.open = true
      this.goalAddTarget.querySelector("input[type='text'], input:not([type='hidden'])")?.focus()
    }
  }

  close(event) {
    event?.preventDefault()
    this.hideNotebook()
    this.planIdValue = 0
    this.projectIdValue = 0
    this.clearReactTent()
    this.pushHistory(null)
  }

  showNotebook() {
    if (!this.hasNotebookTarget) return
    this.notebookTarget.hidden = false
    this.notebookTarget.classList.add("is-open")
    this.element.classList.add("is-notebook-open")
  }

  hideNotebook() {
    if (!this.hasNotebookTarget) return
    this.notebookTarget.hidden = true
    this.notebookTarget.classList.remove("is-open")
    this.element.classList.remove("is-notebook-open")
  }

  showGoalPanel() {
    if (this.hasGoalPanelTarget) this.goalPanelTarget.hidden = false
    this.planPanelTargets.forEach((el) => {
      el.hidden = true
    })
    if (this.hasTitleTarget) {
      const goalBtn = this.element.querySelector(".lp-camp-notebook__crumb-item.is-goal span:last-child")
      this.titleTarget.textContent = goalBtn?.textContent?.trim() || "Goal"
    }
    this.updateCrumb({ planId: 0, projectId: 0 })
    this.updateContextAdd()
    if (this.hasGoalAddTarget) this.goalAddTarget.hidden = false
  }

  showPlanPanel(planId, title = "") {
    if (this.hasGoalPanelTarget) this.goalPanelTarget.hidden = true
    if (this.hasGoalAddTarget) this.goalAddTarget.hidden = true
    let foundTitle = title
    this.planPanelTargets.forEach((el) => {
      const match = Number(el.dataset.planId) === Number(planId)
      el.hidden = !match
      if (match && !foundTitle) foundTitle = el.dataset.planTitle || ""
    })
    if (this.hasTitleTarget && foundTitle) this.titleTarget.textContent = foundTitle
    this.updateCrumb({ planId, planTitle: foundTitle, projectId: 0 })
    this.updateContextAdd()
  }

  expandProject(projectId, { title = "", pulse = true } = {}) {
    this.projectItemTargets.forEach((el) => {
      const match = Number(el.dataset.projectId) === Number(projectId)
      el.classList.toggle("is-expanded", match)
      const row = el.querySelector(".lp-camp-notebook__row.is-project")
      const battles = el.querySelector(".lp-camp-notebook__battles")
      const chevron = el.querySelector(".lp-camp-notebook__row-chevron")
      if (row) {
        row.classList.toggle("is-active", match)
        row.setAttribute("aria-expanded", match ? "true" : "false")
      }
      if (battles) battles.hidden = !match
      if (chevron) chevron.textContent = match ? "▾" : "›"
      if (match && !title) title = el.dataset.projectTitle || ""
    })
    if (pulse) this.pulsePath(["is-goal", "is-plan", "is-project"])
    if (title) this.showReactTent(title)
  }

  collapseProject(projectId) {
    this.projectItemTargets.forEach((el) => {
      if (Number(el.dataset.projectId) !== Number(projectId)) return
      el.classList.remove("is-expanded")
      const row = el.querySelector(".lp-camp-notebook__row.is-project")
      const battles = el.querySelector(".lp-camp-notebook__battles")
      const chevron = el.querySelector(".lp-camp-notebook__row-chevron")
      row?.classList.remove("is-active")
      row?.setAttribute("aria-expanded", "false")
      if (battles) battles.hidden = true
      if (chevron) chevron.textContent = "›"
    })
  }

  collapseAllProjects() {
    this.projectItemTargets.forEach((el) => {
      el.classList.remove("is-expanded")
      const row = el.querySelector(".lp-camp-notebook__row.is-project")
      const battles = el.querySelector(".lp-camp-notebook__battles")
      const chevron = el.querySelector(".lp-camp-notebook__row-chevron")
      row?.classList.remove("is-active")
      row?.setAttribute("aria-expanded", "false")
      if (battles) battles.hidden = true
      if (chevron) chevron.textContent = "›"
    })
  }

  updateCrumb({ planId = 0, planTitle = "", projectId = 0, projectTitle = "" } = {}) {
    if (this.hasCrumbPlanSepTarget) this.crumbPlanSepTarget.hidden = !planId
    if (this.hasCrumbPlanTarget) {
      this.crumbPlanTarget.hidden = !planId
      if (planTitle && this.hasCrumbPlanTitleTarget) this.crumbPlanTitleTarget.textContent = planTitle.slice(0, 18)
    }
    if (this.hasCrumbProjectSepTarget) this.crumbProjectSepTarget.hidden = !projectId
    if (this.hasCrumbProjectTarget) {
      this.crumbProjectTarget.hidden = !projectId
      if (projectTitle && this.hasCrumbProjectTitleTarget) {
        this.crumbProjectTitleTarget.textContent = projectTitle.slice(0, 18)
      }
    }
  }

  updateContextAdd() {
    if (!this.hasContextAddTarget) return
    if (this.projectIdValue) this.contextAddTarget.textContent = this.contextAddTarget.dataset.labelBattle || "+ Battle"
    else if (this.planIdValue) this.contextAddTarget.textContent = this.contextAddTarget.dataset.labelProject || "+ Project"
    else this.contextAddTarget.textContent = this.contextAddTarget.dataset.labelPlan || "+ Plan"

    // Prefer localized labels already rendered in the footer button when possible
    const labels = this.contextAddTarget.dataset
    if (this.projectIdValue && labels.battle) this.contextAddTarget.textContent = labels.battle
    else if (this.planIdValue && labels.project) this.contextAddTarget.textContent = labels.project
    else if (labels.plan) this.contextAddTarget.textContent = labels.plan
  }

  showReactTent(title) {
    if (!this.hasReactTentTarget) return
    this.reactTentTarget.hidden = false
    this.reactTentTarget.classList.add("is-focus", "is-lit")
    const label = this.hasReactTentLabelTarget ? this.reactTentLabelTarget : this.reactTentTarget.querySelector(".lp-camp-react-tent")
    if (label) {
      label.classList.add("is-glow")
      label.setAttribute("title", title)
      const titleEl = label.querySelector(".lp-camp-react-tent__title")
      if (titleEl) titleEl.textContent = title.length > 18 ? `${title.slice(0, 17)}…` : title
    }
  }

  clearReactTent() {
    if (!this.hasReactTentTarget) return
    this.reactTentTarget.hidden = true
    this.reactTentTarget.classList.remove("is-focus", "is-lit")
    const label = this.hasReactTentLabelTarget ? this.reactTentLabelTarget : null
    label?.classList.remove("is-glow")
  }

  pulsePath(segments = []) {
    if (this.hasWireTarget) {
      this.wireTargets.forEach((wire) => {
        const seg = wire.dataset.wireSegment || ""
        const active = segments.some((s) => seg.includes(s.replace("is-", "")) || seg === s)
        wire.classList.toggle("is-pulse", active)
      })
      window.setTimeout(() => {
        this.wireTargets.forEach((wire) => wire.classList.remove("is-pulse"))
      }, 900)
    }
    this.runSpark()
  }

  runSpark() {
    if (!this.hasSparkTarget) return
    const spark = this.sparkTarget
    spark.hidden = false
    spark.classList.remove("is-run")
    // Force reflow so animation restarts
    void spark.getBoundingClientRect()
    spark.classList.add("is-run")
    window.setTimeout(() => {
      spark.hidden = true
      spark.classList.remove("is-run")
    }, 850)
  }

  highlightPlanOnMap(planId) {
    this.element.querySelectorAll(".lp-strategy-mountain__slot.is-plan").forEach((slot) => {
      const match = Number(slot.dataset.cameraPlanId) === Number(planId)
      slot.classList.toggle("is-focus", match)
      slot.classList.toggle("is-pill", !match)
      const marker = slot.querySelector(".lp-strategy-marker")
      marker?.classList.toggle("is-lit", match)
      marker?.classList.toggle("is-spine", match)
      marker?.classList.toggle("is-side", !match)
      marker?.classList.toggle("is-quiet", !match)
    })
  }

  pushHistory(focusId) {
    if (!this.journeyUrlValue) return
    const url = new URL(this.journeyUrlValue, window.location.origin)
    if (focusId) url.searchParams.set("focus_id", String(focusId))
    else url.searchParams.delete("focus_id")
    url.searchParams.delete("peek")
    url.searchParams.delete("sheet")
    url.searchParams.delete("node_id")
    window.history.pushState({ notebook: true, focus: focusId }, "", url)
  }
}
