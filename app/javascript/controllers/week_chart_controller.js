import { Controller } from "@hotwired/stimulus"

// Premium SVG line chart for weekly scores (0–100).
export default class extends Controller {
  static targets = ["svg", "line", "area", "points", "tooltip", "tooltipLabel", "tooltipValue"]
  static values = {
    points: Array
  }

  connect() {
    this.render()
    this.boundResize = () => this.render()
    window.addEventListener("resize", this.boundResize)
  }

  disconnect() {
    window.removeEventListener("resize", this.boundResize)
  }

  render() {
    if (!this.hasSvgTarget || !this.pointsValue?.length) return

    const svg = this.svgTarget
    const width = svg.clientWidth || 360
    const height = svg.clientHeight || 180
    const padX = 18
    const padY = 18
    const plotW = width - padX * 2
    const plotH = height - padY * 2
    const maxY = 100
    const n = this.pointsValue.length
    const step = n > 1 ? plotW / (n - 1) : plotW

    const coords = this.pointsValue.map((point, index) => {
      const value = Math.max(0, Math.min(maxY, Number(point.percent) || 0))
      const x = padX + index * step
      const y = padY + plotH - (value / maxY) * plotH
      return { ...point, x, y, value }
    })

    this.coords = coords

    const lineD = coords.map((c, i) => `${i === 0 ? "M" : "L"} ${c.x.toFixed(1)} ${c.y.toFixed(1)}`).join(" ")
    const areaD = [
      `M ${coords[0].x.toFixed(1)} ${(padY + plotH).toFixed(1)}`,
      ...coords.map((c) => `L ${c.x.toFixed(1)} ${c.y.toFixed(1)}`),
      `L ${coords[coords.length - 1].x.toFixed(1)} ${(padY + plotH).toFixed(1)}`,
      "Z"
    ].join(" ")

    if (this.hasLineTarget) {
      this.lineTarget.setAttribute("d", lineD)
      this.animatePath(this.lineTarget)
    }

    if (this.hasAreaTarget) {
      this.areaTarget.setAttribute("d", areaD)
    }

    if (this.hasPointsTarget) {
      this.pointsTarget.innerHTML = coords.map((c, index) => `
        <circle
          class="week-line-dot ${c.current ? "is-current" : ""}"
          cx="${c.x.toFixed(1)}"
          cy="${c.y.toFixed(1)}"
          r="4.5"
          data-index="${index}"
          data-action="mouseenter->week-chart#showTip focus->week-chart#showTip mouseleave->week-chart#hideTip blur->week-chart#hideTip"
          tabindex="0"
          role="listitem"
          aria-label="${c.full_label || c.label}: ${c.value}%"
        ></circle>
      `).join("")
    }

    svg.setAttribute("viewBox", `0 0 ${width} ${height}`)
  }

  animatePath(path) {
    try {
      const length = path.getTotalLength()
      path.style.strokeDasharray = `${length}`
      path.style.strokeDashoffset = `${length}`
      path.getBoundingClientRect()
      path.style.transition = "stroke-dashoffset 900ms cubic-bezier(0.22, 1, 0.36, 1)"
      path.style.strokeDashoffset = "0"
    } catch (_error) {
      // ignore browsers without path length support
    }
  }

  showTip(event) {
    if (!this.hasTooltipTarget) return
    const index = Number(event.currentTarget.dataset.index)
    const point = this.coords?.[index]
    if (!point) return

    this.tooltipLabelTarget.textContent = point.full_label || point.label
    this.tooltipValueTarget.textContent = `${point.value}%`
    this.tooltipTarget.hidden = false
    this.tooltipTarget.style.left = `${point.x}px`
    this.tooltipTarget.style.top = `${Math.max(8, point.y - 18)}px`
  }

  hideTip() {
    if (!this.hasTooltipTarget) return
    this.tooltipTarget.hidden = true
  }
}
