import { Controller } from "@hotwired/stimulus"
import { enqueue, release } from "lib/lp_overlay_queue"

// Dismissible climb reward ceremony — waits for overlay queue.
export default class extends Controller {
  static values = { auto: Boolean }

  connect() {
    if (!this.autoValue) return
    if (typeof this.element.showModal !== "function") return

    enqueue("climb_reward", {
      open: () => {
        if (!this.element.isConnected) {
          release("climb_reward")
          return
        }
        if (!this.element.open) this.element.showModal()
      },
      onFail: () => release("climb_reward")
    })
  }

  disconnect() {
    release("climb_reward")
  }

  dismiss(event) {
    // Allow navigation links to proceed; just close the dialog chrome.
    if (this.element.open) this.element.close()
    release("climb_reward")
    if (event?.currentTarget?.tagName === "BUTTON") {
      event.preventDefault()
    }
  }
}
