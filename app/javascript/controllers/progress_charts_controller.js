import { Controller } from "@hotwired/stimulus"
import "chart.js"

// Progress charts: growth line + category donut.
export default class extends Controller {
  static targets = ["growth", "donut", "growthEmpty", "donutEmpty"]
  static values = {
    growth: Array,
    categories: Array
  }

  get Chart() {
    return window.Chart
  }

  connect() {
    this.charts = []
    if (!this.Chart) return
    this.renderGrowth()
    this.renderDonut()
  }

  disconnect() {
    this.charts.forEach((chart) => chart.destroy())
    this.charts = []
  }

  renderGrowth() {
    if (!this.hasGrowthTarget) return
    const points = this.growthValue || []
    if (!points.length) {
      this.growthTarget.classList.add("is-empty")
      if (this.hasGrowthEmptyTarget) this.growthEmptyTarget.hidden = false
      return
    }

    if (this.hasGrowthEmptyTarget) this.growthEmptyTarget.hidden = true

    const labels = points.map((p) => p.label)
    const data = points.map((p) => p.lp)
    const neon = "#84F23A"

    const chart = new this.Chart(this.growthTarget, {
      type: "line",
      data: {
        labels,
        datasets: [{
          label: "LP",
          data,
          borderColor: neon,
          backgroundColor: (ctx) => {
            const { chart } = ctx
            const { ctx: c, chartArea } = chart
            if (!chartArea) return "rgba(132, 242, 58, 0.12)"
            const gradient = c.createLinearGradient(0, chartArea.top, 0, chartArea.bottom)
            gradient.addColorStop(0, "rgba(132, 242, 58, 0.35)")
            gradient.addColorStop(1, "rgba(132, 242, 58, 0)")
            return gradient
          },
          fill: true,
          tension: 0.35,
          pointRadius: points.length > 60 ? 0 : 3,
          pointHoverRadius: 5,
          pointBackgroundColor: neon,
          borderWidth: 2.5
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        animation: { duration: 900, easing: "easeOutQuart" },
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: "rgba(7, 11, 9, 0.92)",
            borderColor: "rgba(132, 242, 58, 0.35)",
            borderWidth: 1,
            titleColor: "#f3f7f4",
            bodyColor: "#84F23A",
            padding: 10,
            displayColors: false,
            callbacks: {
              label: (ctx) => `+${ctx.parsed.y} LP`
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
              font: { family: "Inter", size: 11 }
            },
            border: { display: false }
          },
          y: {
            beginAtZero: true,
            grid: { color: "rgba(255,255,255,0.06)" },
            ticks: {
              color: "#8fa399",
              font: { family: "Inter", size: 11 },
              precision: 0
            },
            border: { display: false }
          }
        }
      }
    })
    this.charts.push(chart)
  }

  renderDonut() {
    if (!this.hasDonutTarget) return
    const cats = this.categoriesValue || []
    if (!cats.length) {
      if (this.hasDonutEmptyTarget) this.donutEmptyTarget.hidden = false
      return
    }
    if (this.hasDonutEmptyTarget) this.donutEmptyTarget.hidden = true

    const chart = new this.Chart(this.donutTarget, {
      type: "doughnut",
      data: {
        labels: cats.map((c) => c.label),
        datasets: [{
          data: cats.map((c) => c.amount),
          backgroundColor: cats.map((c) => c.color),
          borderWidth: 0,
          hoverOffset: 6
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        cutout: "72%",
        animation: { animateRotate: true, duration: 1000 },
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: "rgba(7, 11, 9, 0.92)",
            borderColor: "rgba(132, 242, 58, 0.35)",
            borderWidth: 1,
            callbacks: {
              label: (ctx) => {
                const cat = cats[ctx.dataIndex]
                return `${cat.label}: ${cat.percent}% · ${cat.amount} LP`
              }
            }
          }
        }
      }
    })
    this.charts.push(chart)
  }
}
