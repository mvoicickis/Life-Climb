import { Controller } from "@hotwired/stimulus"
import { navSurface } from "nav_transition"

const LOADING_ATTR = "data-lp-today-loading"

let listenersBound = false

function targetsToday(url) {
  if (!url) return false
  return navSurface(url) === "today"
}

function skeletonNodes(doc = document) {
  return {
    root: doc.getElementById("today-dash-root"),
    skeleton: doc.getElementById("today-loading-skeleton")
  }
}

function setSkeletonVisible(visible, doc = document) {
  const { root, skeleton } = skeletonNodes(doc)
  if (!root || !skeleton) return

  root.classList.toggle("is-loading", visible)
  skeleton.hidden = !visible
  skeleton.setAttribute("aria-hidden", visible ? "false" : "true")
  if (visible) {
    skeleton.setAttribute("aria-busy", "true")
  } else {
    skeleton.removeAttribute("aria-busy")
  }
}

function armLoading() {
  document.documentElement.setAttribute(LOADING_ATTR, "true")
  setSkeletonVisible(true)
}

function disarmLoading() {
  document.documentElement.removeAttribute(LOADING_ATTR)
  setSkeletonVisible(false)
}

function onBeforeVisit(event) {
  const url = event.detail?.url
  if (!targetsToday(url)) return

  const from = navSurface(window.location.href)
  if (from === "today") return

  armLoading()
}

function onBeforeRender(event) {
  if (document.documentElement.getAttribute(LOADING_ATTR) !== "true") return

  const newBody = event.detail?.newBody
  if (!newBody) return

  const { root, skeleton } = skeletonNodes(newBody)
  if (!root || !skeleton) return

  root.classList.add("is-loading")
  skeleton.removeAttribute("hidden")
  skeleton.setAttribute("aria-hidden", "false")
  skeleton.setAttribute("aria-busy", "true")
}

function bindTurboListeners() {
  if (listenersBound) return
  listenersBound = true

  document.addEventListener("turbo:before-visit", onBeforeVisit)
  document.addEventListener("turbo:before-render", onBeforeRender)
  document.addEventListener("turbo:render", disarmLoading)
  document.addEventListener("turbo:load", disarmLoading)
  document.addEventListener("turbo:visit-failed", disarmLoading)
}

export default class extends Controller {
  connect() {
    bindTurboListeners()

    if (document.documentElement.getAttribute(LOADING_ATTR) === "true") {
      setSkeletonVisible(true)
    }
  }
}