import { application } from "controllers/application"

// Opens a trail camp sheet after planting — wired from create.turbo_stream only.
Turbo.StreamActions.open_trail_camp = function () {
  // turbo_stream_action_tag emits camp_id= (underscore); not camp-id.
  const campId = this.getAttribute("camp_id") || this.getAttribute("camp-id")
  const root = this.targetElements?.[0] || document.getElementById(this.target)
  if (!root || !campId) return

  const controller = application.getControllerForElementAndIdentifier(root, "trail-camp-sheet")
  controller?.openCampById(campId)
}

Turbo.StreamActions.update_mountain_trail_root = function () {
  const root = this.targetElements?.[0] || document.getElementById(this.target)
  if (!root) return

  const summit = this.getAttribute("summit_reached") === "true"
  const dormant = this.getAttribute("dormant") === "true"
  root.classList.toggle("is-summit-reached", summit)
  root.classList.toggle("is-dormant", dormant)

  const glow = this.getAttribute("summit_glow")
  const climb = this.getAttribute("climb_frac")
  const energy = this.getAttribute("trail_energy")
  if (glow) root.style.setProperty("--lp-summit-glow", glow)
  if (climb) root.style.setProperty("--lp-climb-frac", climb)
  if (energy) root.style.setProperty("--lp-trail-energy", energy)
}
