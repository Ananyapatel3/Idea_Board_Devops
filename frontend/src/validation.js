export function normalizeIdeaContent(content) {
  const normalized = content.trim()
  return normalized.length > 0 && normalized.length <= 1000 ? normalized : null
}
