import { Controller } from "@hotwired/stimulus"
import {
  canPrompt,
  ensureCapture,
  isStandalonePwa,
  onInstallPromptChange,
  promptInstall
} from "pwa_install_prompt"

// Today tip + Settings row for Chrome/Android PWA install (BIP only).
export default class extends Controller {
  static targets = ["root", "title", "body", "actions", "message", "row"]
  static values = {
    surface: { type: String, default: "tip" },
    dismissUrl: String,
    installedUrl: String,
    dismissedMessage: String,
    browserMenuMessage: String
  }

  connect() {
    ensureCapture()
    this.unsubscribe = onInstallPromptChange((detail) => this.onPromptChange(detail))
    this.refreshVisibility()
  }

  disconnect() {
    if (this.unsubscribe) this.unsubscribe()
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

    // Settings: always rendered; hide only when already installed.
    this.element.classList.remove("hidden")
    this.element.hidden = false
  }

  hideForInstalled() {
    this.element.hidden = true
    this.element.classList.add("hidden")
  }

  async install(event) {
    event.preventDefault()
    this.clearMessage()

    if (isStandalonePwa()) {
      this.hideForInstalled()
      return
    }

    if (!canPrompt()) {
      if (this.surfaceValue === "settings") {
        this.showMessage(
          this.browserMenuMessageValue ||
            "Your browser will offer this from its own menu."
        )
      }
      return
    }

    const result = await promptInstall()
    if (result.outcome === "accepted") {
      await this.markInstalled()
      return
    }

    this.refreshVisibility()
  }

  async dismiss(event) {
    event.preventDefault()
    this.clearMessage()

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
    } else {
      this.showMessage(
        this.dismissedMessageValue ||
          "Alright. I'll be in Settings if you change your mind."
      )
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

  showMessage(text) {
    if (!this.hasMessageTarget) return
    this.messageTarget.textContent = text
    this.messageTarget.hidden = false
  }

  clearMessage() {
    if (!this.hasMessageTarget) return
    this.messageTarget.hidden = true
    this.messageTarget.textContent = ""
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
