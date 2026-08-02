import { Controller } from "@hotwired/stimulus"

// Camp workspace helpers — open Prepare New Practice from empty CTA.
export default class extends Controller {
  prepare(event) {
    event?.preventDefault()
    const id = event?.params?.id || this.element.dataset.prepareId
    if (!id) return
    const details = document.getElementById(`rpg-add-practice-${id}`)
    const summary = details?.querySelector("summary.lp-rpg-practice-add")
    if (!details || !summary) return
    if (!details.open) summary.click()
    summary.scrollIntoView({ block: "nearest", inline: "nearest" })
  }
}
