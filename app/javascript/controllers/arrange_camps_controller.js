import { Controller } from "@hotwired/stimulus"
import { createPointerReorder } from "lib/pointer_reorder"

export default class extends Controller {
  static targets = [
    "scroll", "list", "toast", "nextTag", "newStage",
    "deleteSheet", "deleteTitle", "deleteDesc", "deleteQuantifiedLine", "deleteConfirm",
    "addCamp", "addInput"
  ]

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
    openOverlay: Boolean,
    addFailed: String,
    deleteTitleTemplate: String,
    deleteBody: String,
    deleteBodyQuantified: String,
    deleteFailed: String
  }

  connect() {
    this.pointerReorder = null
    this.deleting = false
    this.pendingDeleteUrl = null
    this._addSaving = false
    this._skipAddBlur = false
    this._pendingBindDrag = false
    this._clearBodyArrangeOpen = this.clearBodyArrangeOpen.bind(this)
    this._afterStreamRender = this.afterStreamRender.bind(this)
    document.addEventListener("turbo:before-visit", this._clearBodyArrangeOpen)
    document.addEventListener("turbo:before-cache", this._clearBodyArrangeOpen)
    document.addEventListener("turbo:after-stream-render", this._afterStreamRender)

    const trail = document.getElementById("mountain-trail")
    const shouldBeOpen =
      (this.hasOpenOverlayValue && this.openOverlayValue) ||
      trail?.classList.contains("is-arrange-open")

    if (shouldBeOpen) {
      this.element.hidden = false
      this.element.setAttribute("aria-hidden", "false")
      this.setArrangeOpen(true)
    }
    this.bindDrag()
  }

  disconnect() {
    this.pointerReorder?.destroy()
    document.removeEventListener("turbo:before-visit", this._clearBodyArrangeOpen)
    document.removeEventListener("turbo:before-cache", this._clearBodyArrangeOpen)
    document.removeEventListener("turbo:after-stream-render", this._afterStreamRender)
    this.clearBodyArrangeOpen()
  }

  afterStreamRender() {
    if (!this._pendingBindDrag) return
    this._pendingBindDrag = false
    requestAnimationFrame(() => this.bindDrag())
  }

  clearBodyArrangeOpen() {
    this.setArrangeOpen(false)
  }

  setArrangeOpen(open) {
    document.body.classList.toggle("is-arrange-open", open)
    document.getElementById("mountain-trail")?.classList.toggle("is-arrange-open", open)
  }

  closeFromOverlay(event) {
    event?.preventDefault()
    const trail = document.getElementById("mountain-trail")
    const canvas = trail && this.application.getControllerForElementAndIdentifier(trail, "trail-canvas")
    if (canvas) {
      canvas.closeArrangeCamps(event)
      return
    }

    this.clearBodyArrangeOpen()
    this.element.hidden = true
    this.element.setAttribute("aria-hidden", "true")
  }

  closeOnEscape(event) {
    if (event.key !== "Escape") return
    if (this.element.hidden) return
    if (this.element.querySelector(".lp-trail-arrange-row.is-editing")) return

    event.preventDefault()
    if (this.isAddCampEditing()) {
      this.cancelAddCamp()
      return
    }
    if (this.isDeleteSheetOpen()) {
      this.closeDelete()
      return
    }
    this.closeFromOverlay(event)
  }

  openDelete(event) {
    event.preventDefault()
    event.stopPropagation()
    const row = event.currentTarget.closest(".lp-pointer-reorder__row")
    if (!row) return

    const title = row.dataset.campTitle || ""
    const url = row.dataset.deleteUrl
    if (!url) return

    this.pendingDeleteUrl = url
    if (this.hasDeleteTitleTarget) {
      const template = this.deleteTitleTemplateValue || "Delete %{title}"
      this.deleteTitleTarget.textContent = template.replace("%{title}", title)
    }
    if (this.hasDeleteDescTarget) {
      this.deleteDescTarget.textContent = this.deleteBodyValue || ""
    }
    if (this.hasDeleteQuantifiedLineTarget) {
      const quantified = row.dataset.quantified === "true"
      this.deleteQuantifiedLineTarget.hidden = !quantified
      if (quantified) {
        this.deleteQuantifiedLineTarget.textContent = this.deleteBodyQuantifiedValue || ""
      }
    }
    if (this.hasDeleteSheetTarget) {
      this.deleteSheetTarget.hidden = false
      this.element.classList.add("is-delete-sheet-open")
    }
    this.hasDeleteConfirmTarget && (this.deleteConfirmTarget.disabled = false)
  }

  closeDelete() {
    this.pendingDeleteUrl = null
    if (this.hasDeleteSheetTarget) {
      this.deleteSheetTarget.hidden = true
    }
    this.element.classList.remove("is-delete-sheet-open")
    this.deleting = false
    if (this.hasDeleteConfirmTarget) {
      this.deleteConfirmTarget.disabled = false
    }
  }

  isDeleteSheetOpen() {
    return this.hasDeleteSheetTarget && !this.deleteSheetTarget.hidden
  }

  backdropCloseDelete(event) {
    if (event.target === event.currentTarget) {
      event.preventDefault()
      this.closeDelete()
    }
  }

  stopDeletePanelClick(event) {
    event.stopPropagation()
  }

  async confirmDelete(event) {
    event.preventDefault()
    if (this.deleting || !this.pendingDeleteUrl) return

    this.deleting = true
    if (this.hasDeleteConfirmTarget) {
      this.deleteConfirmTarget.disabled = true
    }

    const token = this.csrfValue || document.querySelector("meta[name='csrf-token']")?.content
    const url = new URL(this.pendingDeleteUrl, window.location.origin)
    url.searchParams.set("arrange_open", "1")

    const response = await fetch(url.toString(), {
      method: "DELETE",
      headers: {
        Accept: "text/vnd.turbo-stream.html",
        "X-CSRF-Token": token || ""
      },
      credentials: "same-origin"
    })

    if (response.ok) {
      this.closeDelete()
      const html = await response.text()
      if (html.includes("turbo-stream") && window.Turbo?.renderStreamMessage) {
        window.Turbo.renderStreamMessage(html)
      }
      this.deleting = false
      return
    }

    this.deleting = false
    if (this.hasDeleteConfirmTarget) {
      this.deleteConfirmTarget.disabled = false
    }
    this.showToast(this.deleteFailedValue || "Could not delete camp.")
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

  // Finished ids first (by data-position), then active ids — preserves Trail order.
  buildGroups() {
    const finishedByStage = new Map()
    this.element.querySelectorAll("[data-arrange-finished-list] [data-camp-id]").forEach((el) => {
      const stage = Number(el.dataset.stage)
      const id = el.dataset.campId
      if (!id) return
      if (!finishedByStage.has(stage)) finishedByStage.set(stage, [])
      finishedByStage.get(stage).push({
        id,
        position: Number(el.dataset.position || 0)
      })
    })
    finishedByStage.forEach((rows, stage) => {
      finishedByStage.set(
        stage,
        rows
          .sort((a, b) => a.position - b.position || Number(a.id) - Number(b.id))
          .map((row) => row.id)
      )
    })

    const activeByStage = new Map()
    this.element.querySelectorAll(".lp-trail-arrange-group[data-stage]").forEach((section) => {
      const stage = Number(section.dataset.stage)
      const list = section.querySelector("[data-arrange-list]")
      const campIds = list
        ? [...list.querySelectorAll(".lp-pointer-reorder__row")].map((row) => row.dataset.campId).filter(Boolean)
        : []
      activeByStage.set(stage, campIds)
    })

    const stageKeys = [...new Set([...finishedByStage.keys(), ...activeByStage.keys()])].sort((a, b) => a - b)
    const groups = stageKeys.map((stage) => {
      const finishedIds = finishedByStage.get(stage) || []
      const activeIds = activeByStage.get(stage) || []
      return { camp_ids: finishedIds.concat(activeIds) }
    }).filter((group) => group.camp_ids.length)

    const newStageList = this.element.querySelector("[data-arrange-new-stage-list]")
    if (newStageList) {
      const campIds = [...newStageList.querySelectorAll(".lp-pointer-reorder__row")].map((row) => row.dataset.campId).filter(Boolean)
      if (campIds.length) groups.push({ camp_ids: campIds })
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

  isAddCampEditing() {
    return this.hasAddCampTarget && this.addCampTarget.classList.contains("is-editing")
  }

  openAddCamp(event) {
    event.preventDefault()
    if (!this.hasAddCampTarget || !this.hasAddInputTarget) return
    this.addCampTarget.classList.add("is-editing")
    this.addInputTarget.focus()
  }

  cancelAddCamp() {
    if (!this.hasAddCampTarget || !this.hasAddInputTarget) return
    this.addCampTarget.classList.remove("is-editing")
    this.addInputTarget.value = ""
  }

  addCampKeydown(event) {
    if (event.key === "Escape") {
      event.preventDefault()
      this.cancelAddCamp()
      return
    }
    if (event.key !== "Enter") return
    event.preventDefault()
    if (this._addSaving) return
    this._skipAddBlur = true
    this.saveAddCamp().finally(() => {
      this._skipAddBlur = false
    })
  }

  addCampBlur() {
    if (this._skipAddBlur || this._addSaving) return
    if (!this.isAddCampEditing()) return
    this.saveAddCamp()
  }

  async saveAddCamp() {
    if (this._addSaving || !this.hasAddInputTarget || !this.stageCampUrlValue) return

    const input = this.addInputTarget
    const title = input.value.trim()
    if (!title) return

    this._addSaving = true
    const token = this.csrfValue || document.querySelector("meta[name='csrf-token']")?.content
    const body = new FormData()
    body.set("plan_id", String(this.planIdValue))
    body.set("stage", "last")
    body.set("title", title)
    body.set("authenticity_token", token || "")

    try {
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
        if (html.includes("turbo-stream") && window.Turbo?.renderStreamMessage) {
          this._pendingBindDrag = true
          window.Turbo.renderStreamMessage(html)
        }
        input.value = ""
        input.focus()
        return
      }

      this.showToast(this.addFailedValue || "Could not add camp. Try again.")
    } finally {
      this._addSaving = false
    }
  }

  showToast(message) {
    if (!this.hasToastTarget) return
    this.toastTarget.textContent = message
    this.toastTarget.hidden = false
    this.toastTarget.classList.add("is-visible")
    window.clearTimeout(this._toastTimer)
    this._toastTimer = window.setTimeout(() => {
      this.toastTarget.classList.remove("is-visible")
      this.toastTarget.hidden = true
    }, 2600)
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
