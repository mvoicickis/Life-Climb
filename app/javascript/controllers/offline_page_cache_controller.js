import { Controller } from "@hotwired/stimulus"
import {
  clearOfflinePageCache,
  clearOfflinePageCacheUserBinding,
  bindOfflinePageCacheForUser,
  withOfflinePageCacheClearTimeout
} from "offline_page_cache"

export default class extends Controller {
  static targets = ["banner", "message"]

  static values = {
    snapshotBanner: String,
    snapshotBannerYesterday: String,
    snapshotBannerDated: String
  }

  connect() {
    const userMeta = document.querySelector('meta[name="lp-user-id"]')
    if (userMeta?.content) bindOfflinePageCacheForUser(userMeta.content)

    this.showSnapshotBannerIfNeeded()
    this.onlineHandler = () => {
      if (document.querySelector('meta[name="lp-offline-snapshot-at"]')) {
        window.location.reload()
      }
    }
    window.addEventListener("online", this.onlineHandler)
  }

  disconnect() {
    window.removeEventListener("online", this.onlineHandler)
  }

  async clearBeforeSignOut(event) {
    const form = event.currentTarget
    if (form.dataset.cacheCleared === "1") {
      delete form.dataset.cacheCleared
      return
    }

    event.preventDefault()

    try {
      await withOfflinePageCacheClearTimeout(clearOfflinePageCache())
      clearOfflinePageCacheUserBinding()
    } catch (_error) {
      /* still sign out */
    }

    form.dataset.cacheCleared = "1"
    try {
      this.submitForm(form)
    } catch (_error) {
      delete form.dataset.cacheCleared
      form.submit()
    }
  }

  async clearBeforeRestart(event) {
    await this.clearBeforeSignOut(event)
  }

  showSnapshotBannerIfNeeded() {
    if (!this.hasBannerTarget || !this.hasMessageTarget) return

    const meta = document.querySelector('meta[name="lp-offline-snapshot-at"]')
    if (!meta?.content) return

    const snapshotAt = new Date(meta.content)
    if (Number.isNaN(snapshotAt.getTime())) return

    this.messageTarget.textContent = this.formatBannerMessage(snapshotAt)
    this.bannerTarget.hidden = false
    this.bannerTarget.removeAttribute("hidden")
  }

  formatBannerMessage(snapshotAt) {
    const now = new Date()
    const time = new Intl.DateTimeFormat(undefined, {
      hour: "numeric",
      minute: "2-digit"
    }).format(snapshotAt)

    const startOfDay = (date) => new Date(date.getFullYear(), date.getMonth(), date.getDate())
    const dayDiff = Math.round((startOfDay(now) - startOfDay(snapshotAt)) / 86400000)

    if (dayDiff === 0) {
      return this.interpolate(this.snapshotBannerValue, { time })
    }
    if (dayDiff === 1) {
      return this.interpolate(this.snapshotBannerYesterdayValue, { time })
    }

    const date = new Intl.DateTimeFormat(undefined, {
      day: "numeric",
      month: "short"
    }).format(snapshotAt)
    return this.interpolate(this.snapshotBannerDatedValue, { date, time })
  }

  interpolate(template, vars) {
    return template.replace(/%\{(\w+)\}/g, (_match, key) => vars[key] ?? "")
  }

  submitForm(form) {
    if (typeof form.requestSubmit === "function") {
      form.requestSubmit()
    } else {
      form.submit()
    }
  }
}
