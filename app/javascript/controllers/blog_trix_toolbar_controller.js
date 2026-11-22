import { Controller } from "@hotwired/stimulus"

const ALLOW = new Set([
  "trix-button--icon-bold",
  "trix-button--icon-italic",
  "trix-button--icon-heading-1",
  "trix-button--icon-quote",
  "trix-button--icon-bullet-list",
  "trix-button--icon-link",
  "trix-button--icon-attach"
])

export default class extends Controller {
  connect() {
    this.element.addEventListener("trix-initialize", this.trimToolbar)
  }

  disconnect() {
    this.element.removeEventListener("trix-initialize", this.trimToolbar)
  }

  trimToolbar = (event) => {
    const toolbar = event.target.toolbarElement
    if (!toolbar) return

    toolbar.querySelectorAll("button").forEach((button) => {
      const iconClass = [ ...button.classList ].find((name) => name.startsWith("trix-button--icon-"))
      if (!iconClass || !ALLOW.has(iconClass)) {
        button.hidden = true
      }
    })

    toolbar.querySelectorAll(".trix-button-group").forEach((group) => {
      const visible = group.querySelectorAll("button:not([hidden])")
      group.hidden = visible.length === 0
    })

    toolbar.classList.add("lp-blog-writer__trix-toolbar")
  }
}