// Keep in sync with ApplicationHelper#in_app_browser?
export const IN_APP_BROWSER_TOKENS = [
  "FBAN",
  "FBAV",
  "FB_IAB",
  "FBIOS",
  "Instagram",
  "Messenger",
  "WhatsApp"
]

export function isInAppBrowser(userAgent) {
  const ua = String(
    userAgent ??
      (typeof navigator === "undefined" ? "" : navigator.userAgent || "")
  )
  return IN_APP_BROWSER_TOKENS.some((token) => ua.includes(token))
}
