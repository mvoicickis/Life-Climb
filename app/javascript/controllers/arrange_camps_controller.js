import { Controller } from "@hotwired/stimulus"
import { createPointerReorder } from "lib/pointer_reorder"

export default class extends Controller {
  static targets = [
    "scroll", "list", "toast", "saveNotice", "nextTag", "newStage",
    "deleteSheet", "deleteTitle", "deleteDesc", "deleteQuantifiedLine", "deleteConfirm"
  ]

  static values = {
    url: String,
    openUrl: String,
    reopenUrl: String,
    winNotSaved: String,
    planId: Number,
    csrf: String,
    saved: String,
    next: String,
    newStage: String,
    maxLength: { type: Number, default: 120 },
    openOverlay: Boolean,
    deleteTitleTemplate: String,
    deleteBody: String,
    deleteBodyQuantified: String,
    deleteFailed: String
  }

  connect() {
    this.pointerReorder = null
    this.dragSnapshot = null
    this.deleting = false
    this.pendingDeleteUrl = null
    this._clearBodyArrangeOpen = this.clearBodyArrangeOpen.bind(this)
    document.addEventListener("turbo:before-visit", this._clearBodyArrangeOpen)
    document.addEventListener("turbo:before-cache", this._clearBodyArrangeOpen)

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
    this.clearBodyArrangeOpen()
  }

  clearBodyArrangeOpen() {
    this.setArrangeOpen(false)
  }

  setArrangeOpen(open) {
    document.body.classList.toggle("is-arrange-open", open)
    document.getElementById("mountain-trail")?.classList.toggle("is-arrange-open", open)
  }

  trailCanvas() {
    const trail = document.getElementById("mountain-trail")
    if (!trail) return null
    return this.application.getControllerForElementAndIdentifier(trail, "trail-canvas")
  }

  openPlantFromArrange(event) {
    event?.preventDefault()
    this.trailCanvas()?.openPlantFromArrange()
  }

  closeFromOverlay(event) {
    event?.preventDefault()
    const canvas = this.trailCanvas()
    if (canvas?.isPlantOpen?.()) {
      canvas.closePlant(event)
      return
    }
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

    const canvas = this.trailCanvas()
    if (canvas?.isPlantOpen?.()) return

    event.preventDefault()
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
      onDragStart: () => {
        this.dragSnapshot = this.captureListsSnapshot()
        this.beginArranging()
      },
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

  activeRowCampId(row) {
    const id = row.dataset.campId
    if (!id) return null
    if (row.dataset.completed === "true") return null
    return id
  }

  // Finished camps: finished list only (not draggable). Active steps: step lists only.
  // Each camp id appears once in the payload (global dedupe); finished wins over stale active rows.
  buildGroups() {
    const finishedByStage = new Map()
    const finishedIdSet = new Set()
    this.element.querySelectorAll("[data-arrange-finished-list] [data-camp-id]").forEach((el) => {
      const stage = Number(el.dataset.stage)
      const id = el.dataset.campId
      if (!id) return
      finishedIdSet.add(id)
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
        ? [...list.querySelectorAll(".lp-pointer-reorder__row")]
            .map((row) => this.activeRowCampId(row))
            .filter((id) => id && !finishedIdSet.has(id))
        : []
      activeByStage.set(stage, campIds)
    })

    const assigned = new Set()
    const stageKeys = [...new Set([...finishedByStage.keys(), ...activeByStage.keys()])].sort((a, b) => a - b)
    const groups = stageKeys.map((stage) => {
      const campIds = []
      const pushUnique = (id) => {
        if (!id || assigned.has(id)) return
        campIds.push(id)
        assigned.add(id)
      }

      const finishedIds = finishedByStage.get(stage) || []
      finishedIds.forEach((id) => pushUnique(id))

      const activeIds = activeByStage.get(stage) || []
      activeIds.forEach((id) => pushUnique(id))

      return { camp_ids: campIds }
    }).filter((group) => group.camp_ids.length)

    const newStageList = this.element.querySelector("[data-arrange-new-stage-list]")
    if (newStageList) {
      const campIds = []
      ;[...newStageList.querySelectorAll(".lp-pointer-reorder__row")].forEach((row) => {
        const id = this.activeRowCampId(row)
        if (!id || finishedIdSet.has(id) || assigned.has(id)) return
        campIds.push(id)
        assigned.add(id)
      })
      if (campIds.length) groups.push({ camp_ids: campIds })
    }

    return groups
  }

  captureListsSnapshot() {
    const lists = []
    this.element.querySelectorAll("[data-arrange-list], [data-arrange-new-stage-list]").forEach((list) => {
      const rows = [...list.querySelectorAll(".lp-pointer-reorder__row")]
      lists.push({
        list,
        rowIds: rows.map((row) => row.dataset.campId).filter(Boolean)
      })
    })
    const finished = [...this.element.querySelectorAll("[data-arrange-finished-list] [data-camp-id]")]
      .map((el) => el.dataset.campId)
      .filter(Boolean)
    return { lists, finished }
  }

  restoreListsSnapshot(snapshot) {
    if (!snapshot?.lists) return

    const rowsById = new Map()
    this.element.querySelectorAll(".lp-pointer-reorder__row").forEach((row) => {
      const id = row.dataset.campId
      if (id) rowsById.set(id, row)
    })

    snapshot.lists.forEach(({ list, rowIds }) => {
      rowIds.forEach((id) => {
        const row = rowsById.get(id)
        if (row && row.parentElement !== list) list.appendChild(row)
      })
    })
    this.bindDrag()
  }

  clearSaveNotice() {
    if (!this.hasSaveNoticeTarget) return
    this.saveNoticeTarget.textContent = ""
    this.saveNoticeTarget.hidden = true
    this.saveNoticeTarget.setAttribute("hidden", "")
    this.element.classList.remove("has-arrange-save-notice")
  }

  showSaveFailed() {
    const message = this.winNotSavedValue || "Not saved. Tap to try again."
    if (this.hasSaveNoticeTarget) {
      this.saveNoticeTarget.textContent = message
      this.saveNoticeTarget.hidden = false
      this.saveNoticeTarget.removeAttribute("hidden")
      this.element.classList.add("has-arrange-save-notice")
    } else {
      this.showToast(message)
    }
  }

  retrySave(event) {
    event?.preventDefault()
    if (!this.hasSaveNoticeTarget || this.saveNoticeTarget.hidden) return
    this.clearSaveNotice()
    this.saveOrder()
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
      this.clearSaveNotice()
      this.dragSnapshot = null
      const html = await response.text()
      if (html.includes("turbo-stream")) {
        window.Turbo?.renderStreamMessage?.(html)
      }
      this.showSaved()
      return
    }

    if (this.dragSnapshot) {
      this.restoreListsSnapshot(this.dragSnapshot)
    }
    this.showSaveFailed()
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
