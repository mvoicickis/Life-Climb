# Pin npm packages by running ./bin/importmap

pin "application"
pin "trail_turbo_streams"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin "chart.js", to: "chart.umd.js"
pin "pwa_install_prompt"
pin "browser_timezone"
pin "push_subscription"
pin "nav_transition"
pin_all_from "app/javascript/controllers", under: "controllers"
pin_all_from "app/javascript/lib", under: "lib"
