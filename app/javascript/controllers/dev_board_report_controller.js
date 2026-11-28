import { Controller } from "@hotwired/stimulus"

// Dev board — report / edit (native <dialog>).
export default class extends Controller {
  static targets = ["dialog", "form", "heading", "submit"]
  static values = { open: Boolean }

  connect() {
    if (this.openValue) this.showDialog()
  }

  open(event) {
    event?.preventDefault()
    this.resetForCreate()
    this.showDialog()
  }

  openEdit(event) {
    event?.preventDefault()
    const button = event.currentTarget
    if (!this.hasFormTarget) return

    const url = button.dataset.devBoardReportUrlValue
    const heading = button.dataset.devBoardReportTitleLabelValue
    const submitLabel = button.dataset.devBoardReportSubmitLabelValue

    this.setPatchForm(url)
    if (this.hasHeadingTarget && heading) this.headingTarget.textContent = heading
    if (this.hasSubmitTarget && submitLabel) this.submitTarget.value = submitLabel

    this.setFieldValue("dev_board_item[title]", button.dataset.devBoardReportItemTitleValue || "")
    this.setFieldValue("dev_board_item[description]", button.dataset.devBoardReportItemDescriptionValue || "")
    this.setFieldValue("dev_board_item[kind]", button.dataset.devBoardReportItemKindValue || "bug")
    this.setFieldValue("dev_board_item[priority]", button.dataset.devBoardReportItemPriorityValue || "important")
    this.setFieldValue("dev_board_item[owner_id]", button.dataset.devBoardReportItemOwnerIdValue || "")
    this.setFieldValue("dev_board_item[reporter_note]", button.dataset.devBoardReportItemReporterNoteValue || "")

    this.showDialog()
  }

  close(event) {
    event?.preventDefault()
    if (!this.hasDialogTarget) return
    if (this.dialogTarget.open) this.dialogTarget.close()
  }

  backdropClose(event) {
    if (!this.hasDialogTarget) return
    if (event.target === this.dialogTarget) this.close()
  }

  resetForCreate() {
    if (!this.hasFormTarget) return
    const createUrl = this.formTarget.dataset.devBoardReportCreateUrlValue
    if (createUrl) this.formTarget.action = createUrl
    this.setFormMethod("post")
    if (this.hasHeadingTarget) {
      this.headingTarget.textContent = this.headingTarget.dataset.defaultTitle || "Report a bug or idea"
    }
    if (this.hasSubmitTarget) {
      this.submitTarget.value = this.submitTarget.dataset.defaultLabel || "Add to board"
    }
  }

  setPatchForm(url) {
    if (!this.hasFormTarget || !url) return
    this.formTarget.action = url
    this.setFormMethod("patch")
  }

  setFormMethod(method) {
    let input = this.formTarget.querySelector("input[name='_method']")
    if (method === "patch") {
      if (!input) {
        input = document.createElement("input")
        input.type = "hidden"
        input.name = "_method"
        this.formTarget.prepend(input)
      }
      input.value = "patch"
    } else if (input) {
      input.remove()
    }
  }

  setFieldValue(name, value) {
    const field = this.formTarget.querySelector(`[name="${name}"]`)
    if (field) field.value = value
  }

  showDialog() {
    if (!this.hasDialogTarget) return
    if (typeof this.dialogTarget.showModal === "function") {
      this.dialogTarget.showModal()
    }
    const field = this.formTarget?.querySelector("[name='dev_board_item[title]']")
    field?.focus()
  }
}