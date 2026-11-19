// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "trail_turbo_streams"
import "controllers"
import { ensureCapture } from "pwa_install_prompt"
import { startNavTransition } from "nav_transition"
import "lib/lp_sound"

// Capture beforeinstallprompt early so Settings and Today share one deferred event.
ensureCapture()
startNavTransition()

// Cheap Android: skip ambient mountain motion when cores are scarce.
if ((navigator.hardwareConcurrency || 8) <= 4) {
  document.documentElement.classList.add("lp-low-power")
}

// PWA Phase B — register only on secure contexts (HTTPS or localhost).
if ("serviceWorker" in navigator) {
  const secure =
    window.isSecureContext ||
    location.protocol === "https:" ||
    location.hostname === "localhost" ||
    location.hostname === "127.0.0.1"

  if (secure) {
    window.addEventListener("load", () => {
      navigator.serviceWorker.register("/service-worker").catch(() => {
        /* Registration can fail offline or on unsupported browsers — ignore. */
      })
    })
  }
}
