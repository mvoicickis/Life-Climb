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

Turbo.StreamActions.open_terrace_sheet = function () {
  const sheetId = this.getAttribute("sheet_id") || this.getAttribute("sheet-id")
  const title = this.getAttribute("sheet_title") || this.getAttribute("sheet-title") || ""
  const campId = this.getAttribute("camp_id") || this.getAttribute("camp-id")
  const root = this.targetElements?.[0] || document.getElementById(this.target)
  if (!root || !sheetId) return

  const controller = application.getControllerForElementAndIdentifier(root, "trail-camp-sheet")
  controller?.openTerraceSheetById(sheetId, title, campId)
}
