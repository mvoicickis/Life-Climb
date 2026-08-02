import { Controller } from "@hotwired/stimulus"

// Board ↔ slide-in quest detail for Mountain Quest Space.
export default class extends Controller {
  static targets = ["board", "detail", "undoBar", "undoText"]
  static values = {
    openId: Number,
    createUrl: String
  }

  connect() {
    this.deleted = null
    if (this.hasOpenIdValue && this.openIdValue > 0) {
      this.showDetail()
    }
  }

  disconnect() {
    this.clearUndoTimer()
  }

  open(event) {
    const id = Number(event.currentTarget.dataset.questId)
    if (!id) return
    this.openIdValue = id
    this.showDetail()
  }

  close() {
    // Allow turbo navigation (back link); hide panel immediately for feel.
    this.openIdValue = 0
    this.hideDetail()
  }

  showDetail() {
    if (!this.hasDetailTarget) return
    this.detailTarget.classList.add("is-open")
    this.detailTarget.setAttribute("aria-hidden", "false")
    if (this.hasBoardTarget) this.boardTarget.setAttribute("aria-hidden", "true")
  }

  hideDetail() {
    if (!this.hasDetailTarget) return
    this.detailTarget.classList.remove("is-open")
    this.detailTarget.setAttribute("aria-hidden", "true")
    if (this.hasBoardTarget) this.boardTarget.setAttribute("aria-hidden", "false")
  }

  addObjective(event) {
    if (event.key !== "Enter" || event.isComposing) return
    event.preventDefault()
    const input = event.currentTarget
    const title = input.value.trim()
    if (!title) return

    const url = input.dataset.createUrl
    if (!url) return

    const form = document.createElement("form")
    form.method = "post"
    form.action = url
    form.style.display = "none"

    const token = document.querySelector("meta[name='csrf-token']")?.content
    if (token) {
      const csrf = document.createElement("input")
      csrf.type = "hidden"
      csrf.name = "authenticity_token"
      csrf.value = token
      form.appendChild(csrf)
    }

    const field = document.createElement("input")
    field.type = "hidden"
    field.name = "title"
    field.value = title
    form.appendChild(field)

    document.body.appendChild(form)
    form.requestSubmit()
  }

  saveTitle(event) {
    if (event.type === "keydown" && (event.key !== "Enter" || event.isComposing)) return
    if (event.type === "keydown") event.preventDefault()

    const input = event.currentTarget
    const url = input.dataset.updateUrl
    const title = input.value.trim()
    if (!url || !title || title === input.dataset.originalTitle) {
      if (!title) input.value = input.dataset.originalTitle || ""
      input.blur()
      return
    }

    this.postForm(url, { title }, "patch")
  }

  toggleComplete(event) {
    event.preventDefault()
    const btn = event.currentTarget
    const url = btn.dataset.updateUrl
    const completed = btn.dataset.completed === "1" ? "0" : "1"
    if (!url) return
    this.postForm(url, { completed }, "patch")
  }

  deleteObjective(event) {
    event.preventDefault()
    const btn = event.currentTarget
    const row = btn.closest("[data-quest-space-row]")
    if (!row) return

    const snapshot = {
      title: row.dataset.title,
      position: row.dataset.position,
      completed: row.dataset.completed,
      createUrl: row.dataset.createUrl,
      destroyUrl: row.dataset.destroyUrl
    }

    this.clearUndoTimer()
    this.deleted = snapshot
    row.hidden = true

    if (this.hasUndoTextTarget) {
      this.undoTextTarget.textContent = `"${snapshot.title}" removed`
    }
    if (this.hasUndoBarTarget) this.undoBarTarget.classList.add("is-show")

    this.undoTimer = window.setTimeout(() => {
      this.commitDelete()
    }, 5000)

    // Destroy immediately; keep the promise so undo waits for it.
    this.destroyPromise = this.postForm(snapshot.destroyUrl, {}, "delete", { navigate: false })
  }

  async undoDelete(event) {
    event?.preventDefault()
    if (!this.deleted) return

    const snap = this.deleted
    this.clearUndoTimer()
    this.deleted = null
    if (this.hasUndoBarTarget) this.undoBarTarget.classList.remove("is-show")

    if (this.destroyPromise) {
      try { await this.destroyPromise } catch (_) { /* still attempt restore */ }
      this.destroyPromise = null
    }

    this.postForm(snap.createUrl, {
      title: snap.title,
      position: snap.position,
      completed: snap.completed
    }, "post")
  }

  commitDelete() {
    this.deleted = null
    if (this.hasUndoBarTarget) this.undoBarTarget.classList.remove("is-show")
  }

  clearUndoTimer() {
    if (this.undoTimer) {
      window.clearTimeout(this.undoTimer)
      this.undoTimer = null
    }
  }

  postForm(url, fields, method, { navigate = true } = {}) {
    if (!url) return null
    const form = document.createElement("form")
    form.method = "post"
    form.action = url
    form.style.display = "none"
    if (!navigate) form.dataset.turbo = "false"

    const token = document.querySelector("meta[name='csrf-token']")?.content
    if (token) {
      const csrf = document.createElement("input")
      csrf.type = "hidden"
      csrf.name = "authenticity_token"
      csrf.value = token
      form.appendChild(csrf)
    }

    if (method && method.toLowerCase() !== "post") {
      const m = document.createElement("input")
      m.type = "hidden"
      m.name = "_method"
      m.value = method
      form.appendChild(m)
    }

    Object.entries(fields).forEach(([name, value]) => {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = name
      input.value = value
      form.appendChild(input)
    })

    document.body.appendChild(form)
    if (navigate === false) {
      return fetch(url, {
        method: "POST",
        headers: {
          "X-CSRF-Token": token || "",
          Accept: "text/html"
        },
        body: new FormData(form),
        credentials: "same-origin",
        redirect: "manual"
      }).finally(() => form.remove())
    }

    form.requestSubmit()
    return null
  }
}
