import { Controller } from "@hotwired/stimulus"

// Streak moment overlay on Today — celebrate / progress / goal, then optional commit + reminder.
export default class extends Controller {
  static targets = [ "celebrate", "commit", "choices", "commitCta", "error", "reminderHost" ]
  static values = {
    offerCommit: { type: Boolean, default: false },
    commitUrl: String,
    declineUrl: String,
    notSaved: String,
    commitCtaTemplate: String
  }

  connect() {
    this._busy = false
    this.element.classList.add("is-animating")
    this._doneTimer = window.setTimeout(() => {
      this.element.classList.remove("is-animating")
      this.element.classList.add("is-done")
    }, 1600)
  }

  disconnect() {
    window.clearTimeout(this._doneTimer)
  }

  dismiss(event) {
    event?.preventDefault?.()
    this.element.remove()
  }

  continue(event) {
    event?.preventDefault?.()
    if (this.offerCommitValue && this.hasCommitTarget) {
      this.showCommit()
      return
    }
    this.dismiss()
  }

  showCommit(event) {
    event?.preventDefault?.()
    if (!this.hasCommitTarget) {
      this.dismiss()
      return
    }
    if (this.hasCelebrateTarget) this.celebrateTarget.hidden = true
    this.commitTarget.hidden = false
    this.element.classList.remove("is-animating")
    this.element.classList.add("is-done")
  }

  selectDays(event) {
    event?.preventDefault?.()
    const button = event.currentTarget
    const days = Number(button.dataset.days)
    if (!days || !this.hasChoicesTarget) return

    this.choicesTarget.querySelectorAll(".lp-streak-moment__choice").forEach((el) => {
      const selected = el === button
      el.classList.toggle("is-selected", selected)
      el.setAttribute("aria-pressed", selected ? "true" : "false")
    })

    if (this.hasCommitCtaTarget) {
      this.commitCtaTarget.dataset.days = String(days)
      const template = this.commitCtaTemplateValue || "Commit to %{count} days"
      this.commitCtaTarget.textContent = template.replace("%{count}", String(days))
    }
  }

  async commit(event) {
    event?.preventDefault?.()
    if (this._busy) return

    const button = event.currentTarget
    const days = Number(button.dataset.days || this.commitCtaTarget?.dataset?.days)
    if (!days || !this.commitUrlValue) return

    this._busy = true
    this.clearError()
    button.disabled = true

    try {
      const response = await fetch(this.commitUrlValue, {
        method: "POST",
        credentials: "same-origin",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken()
        },
        body: JSON.stringify({ days })
      })
      if (!response.ok) throw new Error("Request failed")
      const data = await response.json()
      const html = (data && data.html) || ""
      if (html.trim()) {
        this.showReminder(html)
      } else {
        this.dismiss()
      }
    } catch (error) {
      console.error(error)
      this.showError()
      button.disabled = false
    } finally {
      this._busy = false
    }
  }

  async decline(event) {
    event?.preventDefault?.()
    if (this._busy) return
    if (!this.declineUrlValue) {
      this.dismiss()
      return
    }

    this._busy = true
    this.clearError()
    const button = event.currentTarget
    button.disabled = true

    try {
      const response = await fetch(this.declineUrlValue, {
        method: "POST",
        credentials: "same-origin",
        headers: {
          Accept: "application/json",
          "X-CSRF-Token": this.csrfToken()
        }
      })
      if (!response.ok) throw new Error("Request failed")
      this.dismiss()
    } catch (error) {
      console.error(error)
      this.showError()
      button.disabled = false
    } finally {
      this._busy = false
    }
  }

  showReminder(html) {
    if (this.hasCelebrateTarget) this.celebrateTarget.hidden = true
    if (this.hasCommitTarget) this.commitTarget.hidden = true
    if (!this.hasReminderHostTarget) {
      this.dismiss()
      return
    }
    this.reminderHostTarget.hidden = false
    this.reminderHostTarget.innerHTML = html
  }

  onReminderClosed() {
    this.dismiss()
  }

  csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }

  showError() {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = this.notSavedValue || "Not saved. Tap to try again."
    this.errorTarget.hidden = false
  }

  clearError() {
    if (!this.hasErrorTarget) return
    this.errorTarget.hidden = true
    this.errorTarget.textContent = ""
  }
}
