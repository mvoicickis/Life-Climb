import { Controller } from "@hotwired/stimulus"
import "chart.js"

// Lightweight line charts for Admin dashboard / statistics.
// Chart.js is pinned as UMD (chart.umd.js) — side-effect import + window.Chart.
export default class extends Controller {
  static targets = ["users", "points", "battles"]
  static values = {
    users: Array,
    points: Array,
    battles: Array
  }

  get Chart() {
    return window.Chart
  }

  connect() {
    this.charts = []
    if (!this.Chart) return

    this.renderLine(this.hasUsersTarget && this.usersTarget, this.usersValue, "#166534")
    this.renderLine(this.hasPointsTarget && this.pointsTarget, this.pointsValue, "#0f766e")
    this.renderLine(this.hasBattlesTarget && this.battlesTarget, this.battlesValue, "#b45309")
  }

  disconnect() {
    this.charts.forEach((chart) => chart.destroy())
    this.charts = []
  }

  renderLine(canvas, rows, color) {
    if (!canvas || !rows?.length) return

    const chart = new this.Chart(canvas.getContext("2d"), {
      type: "line",
      data: {
        labels: rows.map((r) => r.label),
        datasets: [{
          data: rows.map((r) => r.value),
          borderColor: color,
          backgroundColor: `${color}22`,
          fill: true,
          tension: 0.35,
          pointRadius: 0,
          borderWidth: 2.5
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: { legend: { display: false } },
        scales: {
          x: {
            grid: { display: false },
            ticks: { maxTicksLimit: 6, color: "#64748b", font: { size: 11, weight: "600" } }
          },
          y: {
            beginAtZero: true,
            grid: { color: "rgba(15,23,42,0.06)" },
            ticks: { precision: 0, color: "#64748b", font: { size: 11, weight: "600" } }
          }
        }
      }
    })
    this.charts.push(chart)
  }
}
