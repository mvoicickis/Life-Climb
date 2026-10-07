// Query params for Mountain camp / base deep links (Today handoff, empty Battles card).
export function parseTrailDeepLink(search = window.location.search) {
  const params = new URLSearchParams(search)
  return {
    campId: params.get("open_camp"),
    openComposer: params.get("open_composer") === "1",
    openBase: params.get("open_base") === "1"
  }
}

export function stripTrailDeepLinkParams(search = window.location.search) {
  const params = new URLSearchParams(search)
  params.delete("open_camp")
  params.delete("open_composer")
  params.delete("open_base")
  const query = params.toString()
  const next = `${window.location.pathname}${query ? `?${query}` : ""}${window.location.hash}`
  history.replaceState(history.state, "", next)
}

export function trailBattlesRootId(campId) {
  return `trail-battles-${campId}`
}
