import { Controller } from "@hotwired/stimulus"
import { createPointerReorder } from "lib/pointer_reorder"

export default class extends Controller {
  static targets = [ "scroll", "list", "toast", "nextTag", "newStage" ]

  static values = {
    url: String,
    reopenUrl: String,
    stageCampUrl: String,
    planId: Number,
    csrf: String,
    saved: String,
    next: String,
    newStage: String,
    maxLength: { type: Number, default: 120 },
    focusStage: Number
  }

  connect() {
    this.pointerReorder = null
    const trail = document.getElementById("mountain-trail")
    if (trail?.classList.contains("is-arrange-open")) {
      this.element.hidden = false
      this.element.setAttribute("aria-hidden", "false")
    }
    this.bindDrag()
    this.focusAddInput()
  }

  disconnect() {
    this.pointerReorder?.destroy()
  }

  bindDrag() {
    this.pointerReorder?.destroy()
    const lists = this.listTargets.length ? this.listTargets : [...this.element.querySelectorAll("[data-arrange-list]")]
    if (lists.length === 0) return

    const stageSections = [...this.element.querySelectorAll(".lp-trail-arrange-group")].map((section) => ({
      list: section.querySelector("[data-arrange-list]")
    })).filter((section) => section.list)

    const newStageList = this.element.querySelector("[data-arrange-new-stage-list]")

    this.pointerReorder = createPointerReorder({
      listRoots: lists,
      stageSections,
      newStageList,
      newStageZone: this.hasNewStageTarget ? this.newStageTarget : null,
      scrollRoot: this.hasScrollTarget ? this.scrollTarget : null,
      edgeScrollBandPx: window.matchMedia("(max-width: 360px)").matches ? 48 : 64,
      rowSelector: ".lp-pointer-reorder__row",
      handleSelector: ".lp-pointer-reorder__handle",
      placeholderClass: "lp-pointer-reorder__placeholder",
      draggingClass: "is-dragging",
      canDragRow: (row) => row.dataset.completed !== "true",
      onDragStart: () => this.beginArranging(),
      onDragEnd: () => this.endArranging(),
      onReorder: () => this.saveOrder()
    })
  }

  listTargetsChanged() {
    this.bindDrag()
  }

  beginArranging() {
    this.element.classList.add("is-arranging")
    if (this.hasNewStageTarget) {
      this.newStageTarget.hidden = false
    }
  }

  endArranging() {
    this.element.classList.remove("is-arranging")
    if (this.hasNewStageTarget) {
      const list = this.newStageTarget.querySelector("[data-arrange-new-stage-list]")
      const hasRows = Boolean(list?.querySelector(".lp-pointer-reorder__row"))
      if (!hasRows) {
        if (list) list.innerHTML = ""
        this.newStageTarget.hidden = true
      }
    }
  }

  buildGroups() {
    const groups = []

    this.element.querySelectorAll(".lp-trail-arrange-group [data-arrange-list]").forEach((list) => {
      const camp_ids = [...list.querySelectorAll(".lp-pointer-reorder__row")].map((row) => row.dataset.campId)
      if (camp_ids.length) groups.push({ camp_ids })
    })

    const newStageList = this.element.querySelector("[data-arrange-new-stage-list]")
    if (newStageList) {
      const camp_ids = [...newStageList.querySelectorAll(".lp-pointer-reorder__row")].map((row) => row.dataset.campId)
      if (camp_ids.length) groups.push({ camp_ids })
    }

    return groups
  }

  async saveOrder() {
    const groups = this.buildGroups()
    const token = this.csrfValue || document.querySelector("meta[name='csrf-token']")?.content

    const body = new FormData()
    body.set("plan_id", String(this.planIdValue))
    body.set("authenticity_token", token || "")
    groups.forEach((group, index) => {
      group.camp_ids.forEach((id) => {
        body.append(`groups[${index}][camp_ids][]`, id)
      })
    })

    const response = await fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        Accept: "text/vnd.turbo-stream.html",
        "X-CSRF-Token": token || ""
      },
      body,
      credentials: "same-origin"
    })

    if (response.ok) {
      const html = await response.text()
      if (html.includes("turbo-stream")) {
        window.Turbo?.renderStreamMessage?.(html)
      }
      this.showSaved()
      return
    }

    window.location.reload()
  }

  async openAgain(event) {
    event.preventDefault()
    const campId = event.currentTarget.dataset.campId
    if (!campId || !this.reopenUrlValue) return

    const token = this.csrfValue || document.querySelector("meta[name='csrf-token']")?.content
    const body = new FormData()
    body.set("camp_id", campId)
    body.set("authenticity_token", token || "")

    const response = await fetch(this.reopenUrlValue, {
      method: "POST",
      headers: {
        Accept: "text/vnd.turbo-stream.html",
        "X-CSRF-Token": token || ""
      },
      body,
      credentials: "same-origin"
    })

    if (response.ok) {
      const html = await response.text()
      if (html.includes("turbo-stream")) {
        window.Turbo?.renderStreamMessage?.(html)
      }
      return
    }

    window.location.reload()
  }

  addStageCampKeydown(event) {
    if (event.key !== "Enter") return
    event.preventDefault()
    this.addStageCamp(event)
  }

  async addStageCamp(event) {
    const input = event.currentTarget
    const title = input.value.trim()
    const stage = input.dataset.stage
    if (!title || stage == null || !this.stageCampUrlValue) return

    const token = this.csrfValue || document.querySelector("meta[name='csrf-token']")?.content
    const body = new FormData()
    body.set("plan_id", String(this.planIdValue))
    body.set("stage", String(stage))
    body.set("title", title)
    body.set("authenticity_token", token || "")

    this._refocusStage = stage

    const response = await fetch(this.stageCampUrlValue, {
      method: "POST",
      headers: {
        Accept: "text/vnd.turbo-stream.html",
        "X-CSRF-Token": token || ""
      },
      body,
      credentials: "same-origin"
    })

    if (response.ok) {
      const html = await response.text()
      if (html.includes("turbo-stream")) {
        window.Turbo?.renderStreamMessage?.(html)
      }
      return
    }

    window.location.reload()
  }

  focusAddInput() {
    const stage = this.hasFocusStageValue ? this.focusStageValue : this._refocusStage
    if (stage == null || stage === "") return

    requestAnimationFrame(() => {
      const input = this.element.querySelector(
        `.lp-trail-arrange-add-camp__input[data-stage="${stage}"]`
      )
      input?.focus()
    })
  }

  showSaved() {
    if (!this.hasToastTarget) return
    this.toastTarget.textContent = this.savedValue
    this.toastTarget.hidden = false
    this.toastTarget.classList.add("is-visible")
    window.clearTimeout(this._toastTimer)
    this._toastTimer = window.setTimeout(() => {
      this.toastTarget.classList.remove("is-visible")
      this.toastTarget.hidden = true
    }, 1600)
  }

  beginRename(event) {
    event.preventDefault()
    const btn = event.currentTarget
    const row = btn.closest(".lp-pointer-reorder__row")
    if (!row || row.classList.contains("is-editing")) return

    row.classList.add("is-editing")
    const input = document.createElement("input")
    input.type = "text"
    input.className = "lp-trail-arrange-row__input"
    input.value = btn.textContent.trim()
    input.maxLength = this.maxLengthValue
    input.autocomplete = "off"

    const commit = async () => {
      const next = input.value.trim()
      if (!next) {
        row.classList.remove("is-editing")
        btn.textContent = btn.textContent
        input.replaceWith(btn)
        return
      }

      const url = row.dataset.updateUrl
      const token = this.csrfValue || document.querySelector("meta[name='csrf-token']")?.content
      const body = new FormData()
      body.set("title", next)
      body.set("authenticity_token", token || "")

      await fetch(url, {
        method: "PATCH",
        headers: {
          Accept: "text/vnd.turbo-stream.html, text/html",
          "X-CSRF-Token": token || ""
        },
        body,
        credentials: "same-origin"
      })

      btn.textContent = next
      row.classList.remove("is-editing")
      input.replaceWith(btn)
    }

    input.addEventListener("keydown", (ev) => {
      if (ev.key === "Enter") {
        ev.preventDefault()
        input.blur()
      } else if (ev.key === "Escape") {
        ev.preventDefault()
        row.classList.remove("is-editing")
        input.replaceWith(btn)
      }
    })
    input.addEventListener("blur", commit)

    btn.replaceWith(input)
    input.focus()
    input.select()
  }
}
