import { Controller } from "@hotwired/stimulus"

// Modern share sheet: platform grid + native "More" via Web Share API.
export default class extends Controller {
  static targets = ["dialog", "backdrop", "panel", "preview", "toast"]
  static values = {
    text: String,
    url: String,
    title: { type: String, default: "Life Climb" }
  }

  connect() {
    this.previouslyFocused = null
    this.boundKeydown = this.onKeydown.bind(this)
  }

  disconnect() {
    this.teardownOpenState()
  }

  open(event) {
    event?.preventDefault()
    event?.stopPropagation()

    if (event?.params?.text) this.textValue = event.params.text
    if (event?.params?.url) this.urlValue = event.params.url
    if (event?.params?.title) this.titleValue = event.params.title

    if (this.hasPreviewTarget) {
      this.previewTarget.textContent = this.fullMessage
    }

    this.previouslyFocused = document.activeElement
    this.dialogTarget.hidden = false
    this.dialogTarget.setAttribute("aria-hidden", "false")
    document.body.classList.add("share-sheet-open")
    document.addEventListener("keydown", this.boundKeydown)

    requestAnimationFrame(() => {
      this.dialogTarget.classList.add("is-open")
      const focusable = this.panelTarget.querySelector("button, [href], [tabindex]:not([tabindex='-1'])")
      focusable?.focus()
    })
  }

  close(event) {
    event?.preventDefault()
    this.teardownOpenState()
  }

  closeOnBackdrop(event) {
    if (event.target === this.backdropTarget) this.close(event)
  }

  onKeydown(event) {
    if (event.key === "Escape") this.close(event)
  }

  teardownOpenState() {
    if (!this.hasDialogTarget || this.dialogTarget.hidden) {
      document.removeEventListener("keydown", this.boundKeydown)
      return
    }

    this.dialogTarget.classList.remove("is-open")
    document.body.classList.remove("share-sheet-open")
    document.removeEventListener("keydown", this.boundKeydown)
    this.dialogTarget.setAttribute("aria-hidden", "true")

    window.setTimeout(() => {
      this.dialogTarget.hidden = true
      if (this.previouslyFocused?.focus) this.previouslyFocused.focus()
    }, 180)
  }

  get fullMessage() {
    const text = (this.textValue || "").trim()
    const url = (this.urlValue || "").trim()
    if (!url) return text
    if (text.includes(url)) return text
    return `${text}\n\nTry it:\n${url}`
  }

  get shareText() {
    return (this.textValue || "").trim()
  }

  get shareUrl() {
    return (this.urlValue || "").trim()
  }

  // Facebook's sharer does not officially support pre-filled post text.
  // We share the landing URL (OG tags power the preview) and copy the message
  // so the user can paste it into the composer if they want.
  async facebook(event) {
    event.preventDefault()
    await this.copySilent(this.fullMessage)
    this.openExternal(`https://www.facebook.com/sharer/sharer.php?u=${encodeURIComponent(this.shareUrl)}`)
    this.showToast("Link opened · message copied to paste")
  }

  // Messenger web dialogs require a Facebook App ID. Without one, copy + open Messenger.
  async messenger(event) {
    event.preventDefault()
    await this.copySilent(this.fullMessage)
    const deepLink = `fb-messenger://share/?link=${encodeURIComponent(this.shareUrl)}`
    const webFallback = "https://www.messenger.com/"

    if (this.isMobile()) {
      window.location.href = deepLink
      window.setTimeout(() => this.openExternal(webFallback), 700)
    } else {
      this.openExternal(webFallback)
    }
    this.showToast("Message copied — paste in Messenger")
  }

  whatsapp(event) {
    event.preventDefault()
    this.openExternal(`https://wa.me/?text=${encodeURIComponent(this.fullMessage)}`)
    this.close()
  }

  telegram(event) {
    event.preventDefault()
    const url = `https://t.me/share/url?url=${encodeURIComponent(this.shareUrl)}&text=${encodeURIComponent(this.shareText)}`
    this.openExternal(url)
    this.close()
  }

  twitter(event) {
    event.preventDefault()
    this.openExternal(`https://twitter.com/intent/tweet?text=${encodeURIComponent(this.fullMessage)}`)
    this.close()
  }

  email(event) {
    event.preventDefault()
    const subject = encodeURIComponent(this.titleValue || "Life Climb")
    const body = encodeURIComponent(this.fullMessage)
    window.location.href = `mailto:?subject=${subject}&body=${body}`
    this.close()
  }

  async copyLink(event) {
    event.preventDefault()
    await this.copy(this.shareUrl, "Link copied")
  }

  async copyMessage(event) {
    event.preventDefault()
    await this.copy(this.fullMessage, "Message copied")
  }

  async more(event) {
    event.preventDefault()

    if (navigator.share) {
      try {
        await navigator.share({
          title: this.titleValue || "Life Climb",
          text: this.shareText,
          url: this.shareUrl
        })
        this.close()
        return
      } catch (error) {
        if (error?.name === "AbortError") return
      }
    }

    await this.copy(this.fullMessage, "Message copied")
  }

  openExternal(url) {
    window.open(url, "_blank", "noopener,noreferrer")
  }

  isMobile() {
    return /Android|iPhone|iPad|iPod|Mobile/i.test(navigator.userAgent || "")
  }

  async copySilent(text) {
    try {
      await navigator.clipboard.writeText(text)
      return true
    } catch (_error) {
      return false
    }
  }

  async copy(text, doneLabel) {
    const ok = await this.copySilent(text)
    if (!ok) {
      window.prompt("Copy this:", text)
      return
    }
    this.showToast(doneLabel)
  }

  showToast(message) {
    if (!this.hasToastTarget) return
    this.toastTarget.textContent = message
    this.toastTarget.hidden = false
    this.toastTarget.classList.add("is-visible")
    window.clearTimeout(this.toastTimer)
    this.toastTimer = window.setTimeout(() => {
      this.toastTarget.classList.remove("is-visible")
      this.toastTarget.hidden = true
    }, 2200)
  }
}
