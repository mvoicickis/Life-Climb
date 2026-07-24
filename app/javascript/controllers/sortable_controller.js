import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["item"]
  static values = { url: String }

  connect() {
    this.dragItem = null
    this.itemTargets.forEach((item) => {
      item.addEventListener("dragstart", this.onDragStart)
      item.addEventListener("dragover", this.onDragOver)
      item.addEventListener("drop", this.onDrop)
      item.addEventListener("dragend", this.onDragEnd)
    })
  }

  disconnect() {
    this.itemTargets.forEach((item) => {
      item.removeEventListener("dragstart", this.onDragStart)
      item.removeEventListener("dragover", this.onDragOver)
      item.removeEventListener("drop", this.onDrop)
      item.removeEventListener("dragend", this.onDragEnd)
    })
  }

  onDragStart = (event) => {
    this.dragItem = event.currentTarget
    event.dataTransfer.effectAllowed = "move"
    event.currentTarget.classList.add("opacity-50")
  }

  onDragOver = (event) => {
    event.preventDefault()
    const target = event.currentTarget
    if (!this.dragItem || target === this.dragItem) return

    const list = this.element
    const items = [...this.itemTargets]
    const dragIndex = items.indexOf(this.dragItem)
    const targetIndex = items.indexOf(target)
    if (dragIndex < targetIndex) {
      list.insertBefore(this.dragItem, target.nextSibling)
    } else {
      list.insertBefore(this.dragItem, target)
    }
  }

  onDrop = (event) => {
    event.preventDefault()
  }

  onDragEnd = async (event) => {
    event.currentTarget.classList.remove("opacity-50")
    this.dragItem = null
    await this.saveOrder()
  }

  async saveOrder() {
    const ids = this.itemTargets.map((item) => item.dataset.id)
    const token = document.querySelector("meta[name='csrf-token']")?.content

    await fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": token,
        Accept: "application/json"
      },
      body: JSON.stringify({ habit_ids: ids })
    })
  }
}
