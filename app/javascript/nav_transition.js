const OPTED_IN = [ "mountain", "today" ]

export function navSurface(pathname) {
  const path = new URL(pathname, "https://lifepoints.local").pathname.replace(/\/+$/, "") || "/"
  if (path === "/dashboard") return "today"
  if (/^\/life_journeys\/\d+$/.test(path)) return "mountain"
  return null
}

export function navDirection(fromPath, toPath) {
  const from = navSurface(fromPath)
  const to = navSurface(toPath)
  if (!from || !to || from === to) return null

  const fromIndex = OPTED_IN.indexOf(from)
  const toIndex = OPTED_IN.indexOf(to)
  if (fromIndex < 0 || toIndex < 0) return null

  return toIndex > fromIndex ? "forward" : "back"
}

function clearNav() {
  document.documentElement.removeAttribute("data-lp-nav")
}

function onBeforeVisit(event) {
  const dir = navDirection(window.location.href, event.detail.url)
  if (dir) {
    document.documentElement.dataset.lpNav = dir
  } else {
    clearNav()
  }
}

function onBeforeFetchResponse(event) {
  const response = event.detail?.fetchResponse
  if (response && response.succeeded === false) clearNav()
}

export function startNavTransition() {
  document.addEventListener("turbo:before-visit", onBeforeVisit)
  document.addEventListener("turbo:load", clearNav)
  document.addEventListener("turbo:before-fetch-response", onBeforeFetchResponse)
  document.addEventListener("turbo:fetch-request-error", clearNav)
}

if (typeof window !== "undefined") {
  window.lpNavDirection = navDirection
  window.lpNavSurface = navSurface
}
