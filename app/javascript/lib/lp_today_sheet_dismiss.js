// Today sheet exit: wait for CSS exit animation, then run teardown (with timeout fallback).

import { prefersReducedMotion } from "lib/lp_feedback"

const FALLBACK_PADDING_MS = 50

export function motionBaseMs() {
  const raw = getComputedStyle(document.documentElement).getPropertyValue("--lp-motion-base").trim()
  const match = raw.match(/^([\d.]+)\s*(ms|s)$/)
  if (!match) return 250
  const n = parseFloat(match[1])
  return match[2] === "s" ? n * 1000 : n
}

function primaryExitNode(nodes) {
  return (
    nodes.find((el) => el.classList?.contains("lp-dash-habit__sheet")) ||
    nodes.find((el) => el.classList?.contains("lp-strategy-sheet__panel")) ||
    nodes[0]
  )
}

export function afterExitMotion(elements, callback) {
  const nodes = elements.filter(Boolean)
  if (!nodes.length) {
    callback()
    return
  }

  const primary = primaryExitNode(nodes)
  let done = false
  const finish = () => {
    if (done) return
    done = true
    primary.removeEventListener("animationend", onEnd)
    clearTimeout(timer)
    callback()
  }

  const onEnd = (event) => {
    if (event.target !== primary) return
    finish()
  }

  primary.addEventListener("animationend", onEnd)
  const timer = setTimeout(finish, motionBaseMs() + FALLBACK_PADDING_MS)
}

export function todaySheetExitEnabled() {
  return !prefersReducedMotion() && Boolean(document.querySelector(".lp-dash.is-today-v2"))
}

export function dismissDialogAnimated(dialog, { onAfterClose } = {}) {
  if (!dialog?.open) {
    onAfterClose?.()
    return
  }

  if (!todaySheetExitEnabled()) {
    dialog.close()
    onAfterClose?.()
    return
  }

  if (dialog.classList.contains("is-sheet-closing")) return

  dialog.classList.add("is-sheet-closing")
  const panel = dialog.querySelector(".lp-strategy-sheet__panel")
  afterExitMotion([panel], () => {
    dialog.classList.remove("is-sheet-closing")
    if (dialog.open) dialog.close()
    onAfterClose?.()
  })
}