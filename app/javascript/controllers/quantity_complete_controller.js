import { Controller } from "@hotwired/stimulus"

// Intercepts checkbox complete for quantified battles, asks for an amount, then submits.
export default class extends Controller {
  static targets = ["form", "dialog", "amount"]

  connect() {
    this.readyToSubmit = false
  }

  intercept(event) {
    if (this.readyToSubmit) return

    event.preventDefault()
    event.stopPropagation()

    if (!this.hasDialogTarget) return

    this.dialogTarget.showModal()
    if (this.hasAmountTarget) {
      this.amountTarget.value = ""
      this.amountTarget.focus()
    }
  }

  confirm(event) {
    event.preventDefault()
    if (!this.hasAmountTarget || !this.hasFormTarget) return

    const raw = this.amountTarget.value.trim()
    const amount = Number(raw)
    if (!raw || !Number.isFinite(amount) || amount <= 0) {
      this.amountTarget.reportValidity()
      return
    }

    let input = this.formTarget.querySelector("input[name='amount']")
    if (!input) {
      input = document.createElement("input")
      input.type = "hidden"
      input.name = "amount"
      this.formTarget.appendChild(input)
    }
    input.value = String(amount)

    this.close()
    this.readyToSubmit = true
    if (typeof this.formTarget.requestSubmit === "function") {
      this.formTarget.requestSubmit()
    } else {
      this.formTarget.submit()
    }
  }

  close(event) {
    event?.preventDefault?.()
    if (this.hasDialogTarget && this.dialogTarget.open) {
      this.dialogTarget.close()
    }
  }

  backdropClose(event) {
    if (event.target === this.dialogTarget) this.close()
  }
}
