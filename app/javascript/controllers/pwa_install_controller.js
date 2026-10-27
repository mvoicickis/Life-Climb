import { Controller } from "@hotwired/stimulus"
import { isInAppBrowser } from "in_app_browser"
import {
  canPrompt,
  ensureCapture,
  isStandalonePwa,
  onInstallPromptChange,
  promptInstall
} from "pwa_install_prompt"
import { isIos } from "push_subscription"

// Settings row: native BIP on Chrome/Android, otherwise a light install-guide sheet.
export default class extends Controller {
  static targets = [
    "root",
    "title",
    "body",
    "actions",
    "row",
    "dialog",
    "backdrop",
    "panel",
    "safariCopy",
    "inAppCopy",
    "otherCopy",
    "gotIt"
  ]
  static values = {
    surface: { type: String, default: "tip" },
    dismissUrl: String,
    installedUrl: String,
    dismissedMessage: String
  }

  connect() {
    ensureCapture()
    this.previouslyFocused = null
    this.boundKeydown = this.onKeydown.bind(this)
    this.unsubscribe = onInstallPromptChange((detail) => this.onPromptChange(detail))
    this.refreshVisibility()
  }

  disconnect() {
    if (this.unsubscribe) this.unsubscribe()
    this.teardownOpenState()
  }

  onPromptChange(detail = {}) {
    if (detail.installed) {
      this.markInstalled()
      return
    }
    this.refreshVisibility()
  }

  refreshVisibility() {
    if (isStandalonePwa()) {
      this.hideForInstalled()
      return
    }

    if (this.surfaceValue === "tip") {
      if (canPrompt()) {
        this.element.hidden = false
      } else {
        this.element.hidden = true
      }
      return
    }

    this.element.classList.remove("hidden")
    this.element.hidden = false
  }

  hideForInstalled() {
    this.closeGuide()
    this.element.hidden = true
    this.element.classList.add("hidden")
  }

  async install(event) {
    event.preventDefault()

    if (isStandalonePwa()) {
      this.hideForInstalled()
      return
    }

    if (!canPrompt()) {
      this.openGuide()
      return
    }

    const result = await promptInstall()
    if (result.outcome === "accepted") {
      await this.markInstalled()
      return
    }

    this.refreshVisibility()
  }

  openGuide() {
    if (!this.hasDialogTarget) return

    this.showGuideMode(this.guideMode())
    this.previouslyFocused = document.activeElement
    this.dialogTarget.hidden = false
    this.dialogTarget.setAttribute("aria-hidden", "false")
    document.body.classList.add("share-sheet-open")
    document.addEventListener("keydown", this.boundKeydown)

    requestAnimationFrame(() => {
      this.dialogTarget.classList.add("is-open")
      if (this.hasGotItTarget) this.gotItTarget.focus()
    })
  }

  closeGuide(event) {
    event?.preventDefault()
    this.teardownOpenState()
  }

  closeOnBackdrop(event) {
    if (event.target === this.backdropTarget) this.closeGuide(event)
  }

  onKeydown(event) {
    if (event.key === "Escape") this.closeGuide(event)
  }

  guideMode() {
    if (isInAppBrowser()) return "in_app"
    if (isIos()) return "safari"
    return "other"
  }

  showGuideMode(mode) {
    const blocks = [
      ["safari", this.hasSafariCopyTarget ? this.safariCopyTarget : null],
      ["in_app", this.hasInAppCopyTarget ? this.inAppCopyTarget : null],
      ["other", this.hasOtherCopyTarget ? this.otherCopyTarget : null]
    ]
    blocks.forEach(([key, node]) => {
      if (!node) return
      const visible = key === mode
      node.hidden = !visible
    })

    const visible = blocks.find(([key]) => key === mode)?.[1]
    const title = visible?.querySelector("[id]")
    if (this.hasPanelTarget && title?.id) {
      this.panelTarget.setAttribute("aria-labelledby", title.id)
    }
  }

  teardownOpenState() {
    if (!this.hasDialogTarget) {
      document.removeEventListener("keydown", this.boundKeydown)
      return
    }
    if (this.dialogTarget.hidden && !this.dialogTarget.classList.contains("is-open")) {
      document.removeEventListener("keydown", this.boundKeydown)
      return
    }

    this.dialogTarget.classList.remove("is-open")
    this.dialogTarget.hidden = true
    this.dialogTarget.setAttribute("aria-hidden", "true")
    document.body.classList.remove("share-sheet-open")
    document.removeEventListener("keydown", this.boundKeydown)

    if (this.previouslyFocused?.focus) {
      this.previouslyFocused.focus()
    }
    this.previouslyFocused = null
  }

  async dismiss(event) {
    event.preventDefault()

    try {
      await this.request(this.dismissUrlValue, "DELETE")
    } catch (_error) {
      return
    }

    if (this.hasActionsTarget) this.actionsTarget.hidden = true
    if (this.hasTitleTarget) this.titleTarget.hidden = true
    if (this.hasBodyTarget) {
      this.bodyTarget.textContent =
        this.dismissedMessageValue ||
        "Alright. I'll be in Settings if you change your mind."
    }

    window.setTimeout(() => {
      this.element.hidden = true
    }, 2200)
  }

  async markInstalled() {
    try {
      if (this.installedUrlValue) {
        await this.request(this.installedUrlValue, "PATCH")
      }
    } catch (_error) {
      /* still hide locally */
    }
    this.hideForInstalled()
  }

  async request(url, method) {
    const token = document.querySelector("meta[name='csrf-token']")?.content
    const response = await fetch(url, {
      method,
      credentials: "same-origin",
      headers: {
        Accept: "application/json",
        "X-CSRF-Token": token || ""
      }
    })
    if (!response.ok) throw new Error("request failed")
    return response
  }
}
