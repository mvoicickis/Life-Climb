export async function applyTurboStreamFromResponse(response) {
  if (!response.ok) return false

  const html = await response.text()
  const contentType = response.headers.get("content-type") || ""
  const looksLikeStream =
    contentType.includes("turbo-stream") || html.includes("<turbo-stream")

  if (window.Turbo?.renderStreamMessage && looksLikeStream) {
    window.Turbo.renderStreamMessage(html)
    return true
  }

  return false
}
