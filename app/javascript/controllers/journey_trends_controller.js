import { Controller } from "@hotwired/stimulus"
import "chart.js"

// Journey Progress trends: battles line + per-Project quantified lines.
export default class extends Controller {
  static targets = ["battles", "quantified"]
  static values = {
    battles: Array,
    quantified: Array
  }

  get Chart() {
    return window.Chart
  }

  connect() {
    this.charts = []
    if (!this.Chart) return
    this.renderBattles()
    this.renderQuantified()
  }

  disconnect() {
    this.charts.forEach((chart) => chart.destroy())
    this.charts = []
  }

  renderBattles() {
    if (!this.hasBattlesTarget) return
    const points = this.battlesValue || []
    if (!points.length) return

    const up = "#22C55E"
    const down = "#E07A5F"

    const chart = new this.Chart(this.battlesTarget, {
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
    this.charts.push(chart)
  }

  renderQuantified() {
    if (!this.hasQuantifiedTarget) return
    const seriesList = this.quantifiedValue || []
    if (!seriesList.length) return

    const byId = new Map(seriesList.map((s) => [String(s.project_id), s]))
    const up = "#22C55E"
    const targetColor = "rgba(143, 163, 153, 0.85)"

    this.quantifiedTargets.forEach((canvas) => {
      const series = byId.get(String(canvas.dataset.projectId))
      if (!series) return

      const points = series.weeks || []
      const target = Number(series.target) || 0
      const unit = series.unit || ""

      const chart = new this.Chart(canvas, {
        type: "line",
        data: {
          labels: points.map((p) => p.label),
          datasets: [
            {
              label: series.title,
              data: points.map((p) => p.value),
              borderColor: up,
              backgroundColor: "rgba(34, 197, 94, 0.10)",
              fill: true,
              tension: 0.35,
              borderWidth: 2.5,
              pointRadius: 3,
              pointHoverRadius: 5,
              pointBackgroundColor: up
            },
            {
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
            }
          ]
        },
        options: this.lineOptions({
          showLegend: false,
          tooltipLabel: (value, datasetIndex) => {
            if (datasetIndex === 1) return `Target ${target}${unit ? ` ${unit}` : ""}`
            return `${value}${unit ? ` ${unit}` : ""}`
          }
        })
      })
      this.charts.push(chart)
    })
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
