import { stripTrailDeepLinkParams } from "lib/trail_deep_link"

const DATASET_KEY = "trailDeepLinkOpen"

export function setPendingDeepLinkOpen(element, { campId, openComposer }) {
  if (!element || !campId) return
  element.dataset[DATASET_KEY] = JSON.stringify({ campId: String(campId), openComposer: !!openComposer })
}

export function readPendingDeepLinkOpen(element) {
  if (!element?.dataset) return null
  const raw = element.dataset[DATASET_KEY]
  if (!raw) return null
  try {
    const parsed = JSON.parse(raw)
    if (!parsed?.campId) return null
    return { campId: String(parsed.campId), openComposer: !!parsed.openComposer }
  } catch (_error) {
    return null
  }
}

export function clearPendingDeepLinkOpen(element) {
  if (!element?.dataset) return
  delete element.dataset[DATASET_KEY]
}

export function consumeDeepLinkOpenOnSheet(sheetController) {
  if (!sheetController?.element) return false

  const pending = readPendingDeepLinkOpen(sheetController.element)
  if (!pending) return false

  clearPendingDeepLinkOpen(sheetController.element)

  if (pending.openComposer) {
    sheetController.flagComposerOnConnect(pending.campId)
  }

  sheetController.openCampById(pending.campId)
  stripTrailDeepLinkParams()
  return true
}
