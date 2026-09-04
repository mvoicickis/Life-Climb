export const TITLE_MAX = 200

export function maxLengthFor(input) {
  return input.maxLength > 0 ? input.maxLength : TITLE_MAX
}

export function formatAtMax(count, max, template) {
  return (template || "%{count} of %{max} letters used")
    .replace("%{count}", String(count))
    .replace("%{max}", String(max))
}

export function attachTitleLimit(input, { template } = {}) {
  const max = maxLengthFor(input)
  const countEl = document.createElement("p")
  countEl.className = "lp-title-limit__count"
  countEl.hidden = true
  countEl.setAttribute("role", "status")

  const refresh = () => {
    const len = input.value.length
    if (len >= max) {
      countEl.textContent = formatAtMax(max, max, template)
      countEl.hidden = false
    } else {
      countEl.hidden = true
    }
  }

  input.addEventListener("input", refresh)
  input.insertAdjacentElement("afterend", countEl)
  refresh()

  return {
    countEl,
    refresh,
    detach() {
      input.removeEventListener("input", refresh)
      countEl.remove()
    }
  }
}
