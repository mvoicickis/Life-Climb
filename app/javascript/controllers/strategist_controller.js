import { Controller } from "@hotwired/stimulus"

// Strategy-Space AI helper via fetch (avoids nested forms).
export default class extends Controller {
  static targets = ["submit", "panel"]
  static values = {
    url: String,
    acceptAs: { type: String, default: "fill" },
    horizon: { type: String, default: "plan" },
    goal: { type: String, default: "" },
    ideal: { type: String, default: "" },
    reality: { type: String, default: "" },
    lifeArea: { type: String, default: "" },
    goalTitle: { type: String, default: "" },
    planTitle: { type: String, default: "" },
    projectTitle: { type: String, default: "" },
    parentId: { type: String, default: "" },
    lifeAreaId: { type: String, default: "" },
    journeyId: { type: String, default: "" },
    targetInput: { type: String, default: "" },
    panelId: { type: String, default: "strategist-panel" },
    sourceForm: { type: Boolean, default: false },
    goalRequired: { type: String, default: "Add your goal title first." }
  }

  async requestHelp(event) {
    event.preventDefault()

    let goal = this.goalValue
    let ideal = this.idealValue
    let reality = this.realityValue

    if (this.sourceFormValue) {
      goal =
        document.querySelector("#life_journey_title")?.value?.trim() ||
        document.querySelector("input[name='life_journey[title]']")?.value?.trim() ||
        document.querySelector("#onboarding_title")?.value?.trim() ||
        document.querySelector("#next-up-title")?.value?.trim() ||
        ""
      ideal =
        document.querySelector("#life_journey_ideal_scene")?.value?.trim() ||
        document.querySelector("textarea[name='life_journey[ideal_scene]']")?.value?.trim() ||
        ""
      reality =
        document.querySelector("#life_journey_current_reality")?.value?.trim() ||
        document.querySelector("textarea[name='life_journey[current_reality]']")?.value?.trim() ||
        ""
    }

    if (!goal) {
      window.alert(this.goalRequiredValue)
      return
    }

    const body = new URLSearchParams()
    body.set("goal", goal)
    body.set("ideal_scene", ideal || "")
    body.set("current_reality", reality || "")
    body.set("life_area", this.lifeAreaValue || "")
    body.set("accept_as", this.acceptAsValue || "fill")
    body.set("horizon", this.horizonValue || "plan")
    if (this.goalTitleValue) body.set("goal_title", this.goalTitleValue)
    if (this.planTitleValue) body.set("plan_title", this.planTitleValue)
    if (this.projectTitleValue) body.set("project_title", this.projectTitleValue)
    if (this.parentIdValue) body.set("parent_id", this.parentIdValue)
    if (this.lifeAreaIdValue) body.set("life_area_id", this.lifeAreaIdValue)
    if (this.journeyIdValue) body.set("life_journey_id", this.journeyIdValue)
    if (this.targetInputValue) body.set("target_input", this.targetInputValue)
    if (this.panelIdValue) body.set("panel_id", this.panelIdValue)

    this.busy(true)
    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          Accept: "text/vnd.turbo-stream.html, text/html",
          "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8",
          "X-CSRF-Token": this.csrfToken()
        },
        body,
        credentials: "same-origin"
      })

      const html = await response.text()
      if (html.includes("turbo-stream")) {
        window.Turbo?.renderStreamMessage(html)
      } else if (this.hasPanelTarget) {
        this.panelTarget.innerHTML = html
      }
    } catch (_error) {
      if (this.hasPanelTarget) {
        this.panelTarget.innerHTML = `<p class="lp-strategist__error">Something went wrong. Try again.</p>`
      }
    } finally {
      this.busy(false)
    }
  }

  fillTitle(event) {
    const title = event.currentTarget.dataset.title
    if (!title) return

    const selector = this.targetInputValue || event.currentTarget.dataset.targetInput
    let input = null

    if (selector) {
      input = document.querySelector(selector)
    }

    if (!input) {
      const root = this.element.closest(".lp-strategy-next, .lp-strategy-add, .lp-home, .lp-adventure, form, body") || document
      input =
        root.querySelector("#next-up-title") ||
        root.querySelector("#add-battle-title") ||
        root.querySelector("#board-add-battle-title") ||
        root.querySelector("#life_journey_title") ||
        root.querySelector("#onboarding_title") ||
        root.querySelector("input[name='life_journey[title]']") ||
        root.querySelector("input[name='title']") ||
        root.querySelector("input[id^='strategy-add-']")
    }

    if (input) {
      input.value = title
      input.focus()
      input.dispatchEvent(new Event("input", { bubbles: true }))
    }
  }

  busy(isBusy) {
    if (!this.hasSubmitTarget) return
    this.submitTarget.disabled = !!isBusy
    if (isBusy) {
      this.submitTarget.dataset.originalLabel = this.submitTarget.textContent
      this.submitTarget.textContent = "Thinking…"
    } else if (this.submitTarget.dataset.originalLabel) {
      this.submitTarget.textContent = this.submitTarget.dataset.originalLabel
    }
  }

  csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }
}
