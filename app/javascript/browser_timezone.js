// Shared IANA timezone detection for signup and notification settings.
export function detectedBrowserTimeZone() {
  try {
    return Intl.DateTimeFormat().resolvedOptions().timeZone || ""
  } catch (_) {
    return ""
  }
}
