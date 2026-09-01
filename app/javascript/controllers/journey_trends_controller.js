import { Controller } from "@hotwired/stimulus"
import "chart.js"

// Journey Progress trends: camp folders + journey battles line.
export default class extends Controller {
  static targets = ["battles", "camp"]
  static values = {
    battles: Array,
    camps: Array,
    timeframe: { type: String, default: "daily" }
  }

  get Chart() {
    return window.Chart
  }

  connect() {
    this.campCharts = new Map()
    this.battlesChart = null
    if (!this.Chart) return
    this.renderBattles()
    this.renderOpenCampCharts()
  }

  disconnect() {
    this.destroyCampCharts()
    if (this.battlesChart) {
      this.battlesChart.destroy()
      this.battlesChart = null
    }
  }

  selectTimeframe(event) {
    const timeframe = event.currentTarget.dataset.timeframe
    if (!timeframe || timeframe === this.timeframeValue) return

    this.timeframeValue = timeframe
    this.element.querySelectorAll(".lp-camp-toggle__btn").forEach((button) => {
      const active = button.dataset.timeframe === timeframe
      button.classList.toggle("is-active", active)
      button.setAttribute("aria-selected", active ? "true" : "false")
    })
    this.renderOpenCampCharts()
  }

  folderToggled(event) {
    const folder = event.currentTarget
    if (!(folder instanceof HTMLDetailsElement)) return

    if (folder.open) {
      const canvas = folder.querySelector("[data-journey-trends-target='camp']")
      if (canvas) this.renderCampChart(canvas)
    } else {
      const projectId = folder.dataset.projectId
      if (projectId) this.destroyCampChart(projectId)
    }
  }

  renderBattles() {
    if (!this.hasBattlesTarget) return
    const points = this.battlesValue || []
    if (!points.length) return

    const up = "#22C55E"
    const down = "#E07A5F"

    this.battlesChart = new this.Chart(this.battlesTarget, {
      type: "line",
      data: {
        labels: points.map((p) => p.label),
        datasets: [{
          label: "Battles",
          data: points.map((p) => p.value),
          borderColor: up,
          backgroundColor: "rgba(34, 197, 94, 0.12)",
          fill: true,
          tension: 0.35,
          borderWidth: 2.5,
          pointRadius: 3,
          pointHoverRadius: 5,
          pointBackgroundColor: points.map((p) => (p.down ? down : up)),
          pointBorderColor: points.map((p) => (p.down ? down : up)),
          segment: {
            borderColor: (ctx) => {
              const next = points[ctx.p1DataIndex]
              return next?.down ? down : up
            }
          }
        }]
      },
      options: this.lineOptions({
        tooltipLabel: (value) => `${value}`
      })
    })
  }

  renderOpenCampCharts() {
    if (!this.hasCampTarget) return

    this.campTargets.forEach((canvas) => {
      const folder = canvas.closest("details.lp-camp-folder")
      if (folder?.open) this.renderCampChart(canvas)
    })
  }

  renderCampChart(canvas) {
    const projectId = String(canvas.dataset.projectId)
    const camp = this.campFor(projectId)
    if (!camp) return

    this.destroyCampChart(projectId)

    const points = camp.series?.[this.timeframeValue] || []
    const accent = camp.accent_hex || "#3dbd48"
    const up = accent
    const targetColor = "rgba(143, 163, 153, 0.85)"
    const datasets = [{
      label: camp.title,
      data: points.map((p) => p.value),
      borderColor: up,
      backgroundColor: "rgba(34, 197, 94, 0.10)",
      fill: true,
      tension: 0.35,
      borderWidth: 2.5,
      pointRadius: 3,
      pointHoverRadius: 5,
      pointBackgroundColor: up
    }]

    if (camp.kind === "quantified") {
      const target = Number(camp.target) || 0
      const unit = camp.unit || ""
      datasets.push({
        label: "Target",
        data: points.map(() => target),
        borderColor: targetColor,
        backgroundColor: "transparent",
        fill: false,
        borderDash: [6, 4],
        borderWidth: 1.5,
        pointRadius: 0,
        pointHoverRadius: 0,
        tension: 0
      })

      const chart = new this.Chart(canvas, {
        type: "line",
        data: { labels: points.map((p) => p.label), datasets },
        options: this.lineOptions({
          showLegend: false,
          tooltipLabel: (value, datasetIndex) => {
            if (datasetIndex === 1) return `Target ${target}${unit ? ` ${unit}` : ""}`
            return `${value}${unit ? ` ${unit}` : ""}`
          }
        })
      })
      this.campCharts.set(projectId, chart)
      return
    }

    const chart = new this.Chart(canvas, {
      type: "line",
      data: { labels: points.map((p) => p.label), datasets },
      options: this.lineOptions({
        tooltipLabel: (value) => `${value}`
      })
    })
    this.campCharts.set(projectId, chart)
  }

  campFor(projectId) {
    return (this.campsValue || []).find((camp) => String(camp.project_id) === projectId)
  }

  destroyCampChart(projectId) {
    const chart = this.campCharts.get(String(projectId))
    if (!chart) return

    chart.destroy()
    this.campCharts.delete(String(projectId))
  }

  destroyCampCharts() {
    this.campCharts.forEach((chart) => chart.destroy())
    this.campCharts.clear()
  }

  lineOptions({ tooltipLabel, showLegend = false } = {}) {
    return {
      responsive: true,
      maintainAspectRatio: false,
      animation: { duration: 800, easing: "easeOutQuart" },
      plugins: {
        legend: { display: showLegend },
        tooltip: {
          backgroundColor: "rgba(7, 11, 9, 0.92)",
          borderColor: "rgba(34, 197, 94, 0.35)",
          borderWidth: 1,
          titleColor: "#f8fafc",
          bodyColor: "#22C55E",
          padding: 10,
          displayColors: false,
          callbacks: {
            label: (ctx) => tooltipLabel(ctx.parsed.y, ctx.datasetIndex)
          }
        }
      },
      scales: {
        x: {
          grid: { display: false },
          ticks: {
            color: "#8fa399",
            maxRotation: 0,
            autoSkip: true,
            maxTicksLimit: 8,
            font: { size: 11 }
          },
          border: { display: false }
        },
        y: {
          beginAtZero: true,
          grid: { color: "rgba(255,255,255,0.06)" },
          ticks: {
            color: "#8fa399",
            font: { size: 11 },
            precision: 0
          },
          border: { display: false }
        }
      }
    }
  }
}
