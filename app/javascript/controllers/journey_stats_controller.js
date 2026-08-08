import { Controller } from "@hotwired/stimulus"
import "chart.js"

// Journey “Your stats”: Add-Tracker dialog + labeled Chart.js line charts
// (same visual pattern as journey_trends_controller Battles / Project totals).
export default class extends Controller {
  static targets = ["dialog", "chart"]
  static values = {
    series: Array
  }

  get Chart() {
    return window.Chart
  }

  connect() {
    this.charts = []
    if (!this.Chart) return
    this.renderCharts()
  }

  disconnect() {
    this.charts?.forEach((chart) => chart.destroy())
    this.charts = []
  }

  open(event) {
    event?.preventDefault?.()
    if (!this.hasDialogTarget) return
    if (typeof this.dialogTarget.showModal === "function") {
      this.dialogTarget.showModal()
    } else {
      this.dialogTarget.setAttribute("open", "open")
    }
  }

  close(event) {
    event?.preventDefault?.()
    if (!this.hasDialogTarget) return
    if (typeof this.dialogTarget.close === "function") {
      this.dialogTarget.close()
    } else {
      this.dialogTarget.removeAttribute("open")
    }
  }

  renderCharts() {
    if (!this.hasChartTarget) return
    const seriesList = this.seriesValue || []
    if (!seriesList.length) return

    const byId = new Map(seriesList.map((s) => [String(s.habit_id), s]))
    const up = "#22C55E"

    this.chartTargets.forEach((canvas) => {
      const series = byId.get(String(canvas.dataset.habitId))
      if (!series) return

      const points = series.days || []
      const unit = series.unit || ""

      const chart = new this.Chart(canvas, {
        type: "line",
        data: {
          labels: points.map((p) => p.label),
          datasets: [{
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
          }]
        },
        options: this.lineOptions({
          tooltipLabel: (value) => `${value}${unit ? ` ${unit}` : ""}`
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
            maxTicksLimit: 7,
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
