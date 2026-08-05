// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

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
