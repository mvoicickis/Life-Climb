const DEFAULTS = {
  holdMs: 250,
  moveCancelPx: 8,
  rowSelector: ".lp-pointer-reorder__row",
  handleSelector: ".lp-pointer-reorder__handle",
  placeholderClass: "lp-pointer-reorder__placeholder",
  draggingClass: "is-dragging",
  edgeScrollBandPx: 64,
  edgeScrollStepPx: 12
}

function handleSvg() {
  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><circle cx="9" cy="7" r="1.5"/><circle cx="15" cy="7" r="1.5"/><circle cx="9" cy="12" r="1.5"/><circle cx="15" cy="12" r="1.5"/><circle cx="9" cy="17" r="1.5"/><circle cx="15" cy="17" r="1.5"/></svg>'
}

export function createPointerReorder(options) {
  const opts = { ...DEFAULTS, ...options }
  const listRoots = Array.isArray(opts.listRoots) ? opts.listRoots : [ opts.listRoot ]
  const stageSections = Array.isArray(opts.stageSections) ? opts.stageSections : null
  const multiList = Boolean(stageSections?.length)
  const state = { activeDrag: null, dragId: null, edgeScrollRaf: null, lastClientY: 0 }

  function allRows() {
    if (multiList) {
      return stageSections.flatMap((section) => [...section.list.querySelectorAll(opts.rowSelector)])
    }
    return listRoots.flatMap((root) => [...root.querySelectorAll(opts.rowSelector)])
  }

  function rowsInList(listRoot) {
    return [...listRoot.querySelectorAll(opts.rowSelector)]
  }

  function stopEdgeScroll() {
    if (state.edgeScrollRaf) {
      cancelAnimationFrame(state.edgeScrollRaf)
      state.edgeScrollRaf = null
    }
  }

  function edgeScrollLimits(root) {
    const maxScroll = Math.max(0, root.scrollHeight - root.clientHeight)
    return {
      atTop: root.scrollTop <= 0,
      atBottom: root.scrollTop >= maxScroll
    }
  }

  function tickEdgeScroll() {
    state.edgeScrollRaf = null
    if (!state.activeDrag || !opts.scrollRoot) return

    const root = opts.scrollRoot
    const rect = root.getBoundingClientRect()
    const band = opts.edgeScrollBandPx
    const step = opts.edgeScrollStepPx
    const y = state.lastClientY
    const inBand = y < rect.top + band || y > rect.bottom - band
    if (!inBand) return

    let delta = 0
    if (y < rect.top + band) {
      delta = -step
    } else if (y > rect.bottom - band) {
      delta = step
    }

    const { atTop, atBottom } = edgeScrollLimits(root)
    const canScroll = (delta < 0 && !atTop) || (delta > 0 && !atBottom)

    if (delta !== 0 && canScroll) {
      const prevScrollTop = root.scrollTop
      root.scrollTop += delta
      if (root.scrollTop !== prevScrollTop) {
        updatePlaceholderPosition(y)
      }
    }

    const limits = edgeScrollLimits(root)
    const stillCanScroll = (delta < 0 && !limits.atTop) || (delta > 0 && !limits.atBottom)
    if (delta !== 0 && stillCanScroll) {
      state.edgeScrollRaf = requestAnimationFrame(tickEdgeScroll)
    }
  }

  function maybeStartEdgeScroll(clientY) {
    if (!opts.scrollRoot || !state.activeDrag) return

    state.lastClientY = clientY
    const root = opts.scrollRoot
    const rect = root.getBoundingClientRect()
    const band = opts.edgeScrollBandPx
    const nearEdge = clientY < rect.top + band || clientY > rect.bottom - band

    if (nearEdge && !state.edgeScrollRaf) {
      state.edgeScrollRaf = requestAnimationFrame(tickEdgeScroll)
    } else if (!nearEdge) {
      stopEdgeScroll()
    }
  }

  function teardownDragDom(row, drag, keepInPlace = false) {
    drag.placeholder.remove()
    row.classList.remove(opts.draggingClass)
    row.style.width = ""
    row.style.left = ""
    row.style.top = ""
    if (!keepInPlace) {
      const home = drag.homeList || listRoots[0]
      home.appendChild(row)
    }

    try {
      drag.handle.releasePointerCapture(drag.pointerId)
    } catch (_) {
      // pointer already released
    }
  }

  function cancelActiveDrag() {
    const drag = state.activeDrag
    if (!drag) return

    stopEdgeScroll()
    teardownDragDom(drag.row, drag)
    drag.handle.classList.remove("is-grabbing")
    state.activeDrag = null
    state.dragId = null
    opts.onDragEnd?.()
  }

  function updateDragPosition(clientY) {
    const drag = state.activeDrag
    if (!drag) return

    drag.row.style.top = `${clientY - drag.pointerOffsetY}px`
    drag.row.style.left = `${drag.anchorLeft}px`
  }

  // Geometry is valid for one drag session only; turbo replace or mid-drag height changes stale these numbers.
  function captureDropGeometry(draggedRow) {
    const startScrollTop = opts.scrollRoot?.scrollTop ?? 0
    const rows = allRows()
      .filter((row) => row !== draggedRow)
      .map((row) => {
        const rect = row.getBoundingClientRect()
        return { row, midY: rect.top + rect.height / 2 }
      })

    let newStageZone = null
    const zone = opts.newStageZone
    if (zone && !zone.hidden) {
      const rect = zone.getBoundingClientRect()
      newStageZone = { top: rect.top, bottom: rect.bottom }
    }

    return { startScrollTop, rows, newStageZone }
  }

  function currentPlacement(placeholder) {
    const parent = placeholder.parentElement
    let el = placeholder.nextElementSibling
    while (el && !el.matches(opts.rowSelector)) {
      el = el.nextElementSibling
    }
    return { parent, beforeNode: el }
  }

  function placementEqual(a, b) {
    return Boolean(a && b && a.parent === b.parent && a.beforeNode === b.beforeNode)
  }

  function targetFromGeometry(adjustedY, geometry) {
    if (multiList && geometry.newStageZone && opts.newStageList) {
      const zone = geometry.newStageZone
      if (adjustedY >= zone.top && adjustedY <= zone.bottom) {
        return { parent: opts.newStageList, beforeNode: null }
      }
    }

    for (const entry of geometry.rows) {
      if (adjustedY < entry.midY) {
        return { parent: entry.row.parentElement, beforeNode: entry.row }
      }
    }

    if (geometry.rows.length) {
      const last = geometry.rows[geometry.rows.length - 1]
      return { parent: last.row.parentElement, beforeNode: null }
    }

    if (multiList) {
      const lastSection = stageSections[stageSections.length - 1]
      if (lastSection?.list) {
        return { parent: lastSection.list, beforeNode: null }
      }
    }

    return { parent: listRoots[0], beforeNode: null }
  }

  function applyPlaceholderTarget(target) {
    const drag = state.activeDrag
    if (!drag || !target?.parent) return

    if (target.beforeNode) {
      target.parent.insertBefore(drag.placeholder, target.beforeNode)
    } else {
      target.parent.appendChild(drag.placeholder)
    }
    drag.homeList = target.parent
    drag.placement = target
  }

  function updatePlaceholderPosition(clientY) {
    const drag = state.activeDrag
    if (!drag?.geometry) return

    const scrollTop = opts.scrollRoot?.scrollTop ?? 0
    if (clientY === drag.lastPlacementY && scrollTop === drag.lastPlacementScrollTop) {
      return
    }
    drag.lastPlacementY = clientY
    drag.lastPlacementScrollTop = scrollTop

    const adjustedY = clientY + (scrollTop - drag.geometry.startScrollTop)
    const target = targetFromGeometry(adjustedY, drag.geometry)
    if (placementEqual(drag.placement, target)) return
    applyPlaceholderTarget(target)
  }

  function placeholderIndex() {
    const drag = state.activeDrag
    if (!drag) return { list: null, index: -1 }

    const listRoot = drag.placeholder.parentElement
    let index = 0
    for (const child of listRoot.children) {
      if (child === drag.placeholder) return { list: listRoot, index }
      if (child.matches(opts.rowSelector)) index += 1
    }
    return { list: listRoot, index: -1 }
  }

  function startDrag(handle, row, pointerId, startY) {
    const rowRect = row.getBoundingClientRect()
    const homeList = row.parentElement
    const fromList = homeList
    const fromIndex = rowsInList(homeList).indexOf(row)
    const originNext = row.nextSibling
    const placeholder = document.createElement("li")
    placeholder.className = opts.placeholderClass
    placeholder.setAttribute("aria-hidden", "true")
    placeholder.style.height = `${rowRect.height}px`

    document.body.appendChild(row)

    row.classList.add(opts.draggingClass)
    row.style.width = `${rowRect.width}px`
    row.style.left = `${rowRect.left}px`
    row.style.top = `${rowRect.top}px`

    homeList.insertBefore(placeholder, originNext)

    try {
      handle.setPointerCapture(pointerId)
    } catch (_) {
      // capture may fail on some browsers
    }

    opts.onDragStart?.()

    const geometry = captureDropGeometry(row)

    state.activeDrag = {
      handle,
      row,
      placeholder,
      pointerId,
      pointerOffsetY: startY - rowRect.top,
      anchorLeft: rowRect.left,
      dragId: row.dataset.id,
      homeList,
      fromList,
      fromIndex,
      geometry,
      placement: currentPlacement(placeholder),
      lastPlacementY: startY,
      lastPlacementScrollTop: geometry.startScrollTop
    }
    state.dragId = row.dataset.id
  }

  function finishDrag(row) {
    const drag = state.activeDrag
    if (!drag) return

    stopEdgeScroll()

    const { list: toList, index: toIndex } = placeholderIndex()
    const fromList = drag.fromList
    const fromIndex = drag.fromIndex
    const moved = fromList !== toList || (fromIndex > -1 && toIndex > -1 && fromIndex !== toIndex)

    if (moved && toList) {
      toList.insertBefore(row, drag.placeholder)
      opts.onReorder?.({
        row,
        fromList,
        toList,
        fromIndex,
        toIndex
      })
      teardownDragDom(row, drag, true)
    } else {
      teardownDragDom(row, drag, false)
    }
    drag.handle.classList.remove("is-grabbing")
    state.activeDrag = null
    state.dragId = null
    opts.onDragEnd?.()
  }

  function onHandlePointerDown(event) {
    if (event.button !== 0) return

    const handle = event.currentTarget
    const row = handle.closest(opts.rowSelector)
    if (!row) return
    if (opts.canDragRow && !opts.canDragRow(row)) return

    const listRoot = row.parentElement
    const allowedLists = multiList
      ? [
          ...stageSections.map((section) => section.list),
          opts.newStageList
        ].filter(Boolean)
      : listRoots
    if (!allowedLists.includes(listRoot)) return

    const pointerId = event.pointerId
    const startX = event.clientX
    const startY = event.clientY
    let holdTimer = null
    let active = false

    const cleanupListeners = () => {
      document.removeEventListener("pointermove", onMove)
      document.removeEventListener("pointerup", onUp)
      document.removeEventListener("pointercancel", onUp)
    }

    const cancelHold = () => {
      if (holdTimer) {
        clearTimeout(holdTimer)
        holdTimer = null
      }
    }

    const onMove = (ev) => {
      if (ev.pointerId !== pointerId) return

      if (!active) {
        const dx = Math.abs(ev.clientX - startX)
        const dy = Math.abs(ev.clientY - startY)
        if (dx > opts.moveCancelPx || dy > opts.moveCancelPx) {
          cancelHold()
        }
        return
      }

      ev.preventDefault()
      updateDragPosition(ev.clientY)
      updatePlaceholderPosition(ev.clientY)
      maybeStartEdgeScroll(ev.clientY)
    }

    const onUp = (ev) => {
      if (ev.pointerId !== pointerId) return

      cancelHold()
      cleanupListeners()

      if (active) {
        finishDrag(row)
      }

      handle.classList.remove("is-grabbing")
    }

    holdTimer = setTimeout(() => {
      holdTimer = null
      active = true
      handle.classList.add("is-grabbing")
      startDrag(handle, row, pointerId, startY)
    }, opts.holdMs)

    document.addEventListener("pointermove", onMove)
    document.addEventListener("pointerup", onUp)
    document.addEventListener("pointercancel", onUp)
  }

  function onHandleContextMenu(event) {
    event.preventDefault()
  }

  function bindHandlesIn(root) {
    if (!root) return
    root.querySelectorAll(opts.handleSelector).forEach((handle) => {
      handle.removeEventListener("pointerdown", onHandlePointerDown)
      handle.removeEventListener("contextmenu", onHandleContextMenu)
      handle.addEventListener("pointerdown", onHandlePointerDown)
      handle.addEventListener("contextmenu", onHandleContextMenu)
    })
  }

  function unbindHandlesIn(root) {
    if (!root) return
    root.querySelectorAll(opts.handleSelector).forEach((handle) => {
      handle.removeEventListener("pointerdown", onHandlePointerDown)
      handle.removeEventListener("contextmenu", onHandleContextMenu)
    })
  }

  function bind() {
    if (multiList) {
      stageSections.forEach((section) => bindHandlesIn(section.list))
      bindHandlesIn(opts.newStageList)
      return
    }

    listRoots.forEach((root) => bindHandlesIn(root))
  }

  function destroy() {
    cancelActiveDrag()
    if (multiList) {
      stageSections.forEach((section) => unbindHandlesIn(section.list))
      unbindHandlesIn(opts.newStageList)
      return
    }

    listRoots.forEach((root) => unbindHandlesIn(root))
  }

  bind()

  return {
    cancelActiveDrag,
    destroy,
    rebind: bind,
    handleSvg
  }
}
