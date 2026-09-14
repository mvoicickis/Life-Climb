const DEFAULTS = {
  holdMs: 250,
  moveCancelPx: 8,
  rowSelector: ".lp-pointer-reorder__row",
  handleSelector: ".lp-pointer-reorder__handle",
  placeholderClass: "lp-pointer-reorder__placeholder",
  draggingClass: "is-dragging"
}

function handleSvg() {
  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><circle cx="9" cy="7" r="1.5"/><circle cx="15" cy="7" r="1.5"/><circle cx="9" cy="12" r="1.5"/><circle cx="15" cy="12" r="1.5"/><circle cx="9" cy="17" r="1.5"/><circle cx="15" cy="17" r="1.5"/></svg>'
}

export function createPointerReorder(options) {
  const opts = { ...DEFAULTS, ...options }
  const listRoots = Array.isArray(opts.listRoots) ? opts.listRoots : [ opts.listRoot ]
  const state = { activeDrag: null, dragId: null }

  function allRows() {
    return listRoots.flatMap((root) => [...root.querySelectorAll(opts.rowSelector)])
  }

  function rowsInList(listRoot) {
    return [...listRoot.querySelectorAll(opts.rowSelector)]
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

    teardownDragDom(drag.row, drag)
    drag.handle.classList.remove("is-grabbing")
    state.activeDrag = null
    state.dragId = null
  }

  function updateDragPosition(clientY) {
    const drag = state.activeDrag
    if (!drag) return

    drag.row.style.top = `${clientY - drag.pointerOffsetY}px`
    drag.row.style.left = `${drag.anchorLeft}px`
  }

  function listForPlaceholder(clientY) {
    for (const root of listRoots) {
      const rect = root.getBoundingClientRect()
      if (clientY >= rect.top && clientY <= rect.bottom) return root
    }
    let best = listRoots[0]
    let bestDist = Infinity
    for (const root of listRoots) {
      const rect = root.getBoundingClientRect()
      const mid = rect.top + rect.height / 2
      const dist = Math.abs(clientY - mid)
      if (dist < bestDist) {
        bestDist = dist
        best = root
      }
    }
    return best
  }

  function updatePlaceholderPosition(clientY) {
    const drag = state.activeDrag
    if (!drag) return

    const listRoot = listForPlaceholder(clientY)
    const rows = rowsInList(listRoot).filter((row) => row !== drag.row)
    let inserted = false

    for (const other of rows) {
      const rect = other.getBoundingClientRect()
      const mid = rect.top + rect.height / 2
      if (clientY < mid) {
        listRoot.insertBefore(drag.placeholder, other)
        inserted = true
        break
      }
    }

    if (!inserted) {
      listRoot.appendChild(drag.placeholder)
    }
    drag.homeList = listRoot
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
    const placeholder = document.createElement("li")
    placeholder.className = opts.placeholderClass
    placeholder.setAttribute("aria-hidden", "true")
    placeholder.style.height = `${rowRect.height}px`

    homeList.insertBefore(placeholder, row)
    document.body.appendChild(row)

    row.classList.add(opts.draggingClass)
    row.style.width = `${rowRect.width}px`
    row.style.left = `${rowRect.left}px`
    row.style.top = `${rowRect.top}px`

    try {
      handle.setPointerCapture(pointerId)
    } catch (_) {
      // capture may fail on some browsers
    }

    state.activeDrag = {
      handle,
      row,
      placeholder,
      pointerId,
      pointerOffsetY: startY - rowRect.top,
      anchorLeft: rowRect.left,
      dragId: row.dataset.id,
      homeList,
      fromList: homeList,
      fromIndex: rowsInList(homeList).indexOf(row)
    }
    state.dragId = row.dataset.id
  }

  function finishDrag(row) {
    const drag = state.activeDrag
    if (!drag) return

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
  }

  function onHandlePointerDown(event) {
    if (event.button !== 0) return

    const handle = event.currentTarget
    const row = handle.closest(opts.rowSelector)
    if (!row) return
    if (opts.canDragRow && !opts.canDragRow(row)) return

    const listRoot = row.parentElement
    if (!listRoots.includes(listRoot)) return

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

  function bind() {
    listRoots.forEach((root) => {
      root.querySelectorAll(opts.handleSelector).forEach((handle) => {
        handle.removeEventListener("pointerdown", onHandlePointerDown)
        handle.addEventListener("pointerdown", onHandlePointerDown)
      })
    })
  }

  function destroy() {
    cancelActiveDrag()
    listRoots.forEach((root) => {
      root.querySelectorAll(opts.handleSelector).forEach((handle) => {
        handle.removeEventListener("pointerdown", onHandlePointerDown)
      })
    })
  }

  bind()

  return {
    cancelActiveDrag,
    destroy,
    rebind: bind,
    handleSvg
  }
}
