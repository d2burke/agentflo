function formatUuid(bytes: Uint8Array) {
  const normalized = new Uint8Array(bytes)
  normalized[6] = (normalized[6] & 0x0f) | 0x40
  normalized[8] = (normalized[8] & 0x3f) | 0x80

  const hex = Array.from(normalized, (byte) => byte.toString(16).padStart(2, '0'))

  return [
    hex.slice(0, 4).join(''),
    hex.slice(4, 6).join(''),
    hex.slice(6, 8).join(''),
    hex.slice(8, 10).join(''),
    hex.slice(10, 16).join(''),
  ].join('-')
}

export function createClientMessageId() {
  if (typeof crypto !== 'undefined') {
    if (typeof crypto.randomUUID === 'function') {
      return crypto.randomUUID()
    }

    if (typeof crypto.getRandomValues === 'function') {
      const bytes = new Uint8Array(16)
      crypto.getRandomValues(bytes)
      return formatUuid(bytes)
    }
  }

  const bytes = new Uint8Array(16)
  for (let index = 0; index < bytes.length; index += 1) {
    bytes[index] = Math.floor(Math.random() * 256)
  }

  return formatUuid(bytes)
}
