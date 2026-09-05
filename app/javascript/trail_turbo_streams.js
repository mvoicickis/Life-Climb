import { application } from "controllers/application"

// Opens a trail camp sheet after planting — wired from create.turbo_stream only.
Turbo.StreamActions.open_trail_camp = function () {
  const campId = this.getAttribute("camp-id")
  const root = this.targetElements?.[0] || document.getElementById(this.target)
  if (!root || !campId) return

  const controller = application.getControllerForElementAndIdentifier(root, "trail-camp-sheet")
  controller?.openCampById(campId)
}
