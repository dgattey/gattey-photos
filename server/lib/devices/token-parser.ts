const HEX = /^[0-9a-f]+$/i;

export function parseBloomin8Token(text: string): string | null {
  const trimmed = text.trim();
  if (!trimmed) return null;

  for (const line of trimmed.split(/\r?\n/)) {
    const value = valueAfterLabel("Token:", line.trim());
    if (value && looksLikeToken(value)) return value;
  }

  const collapsed = trimmed
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter((l) => l && !isSetupHeaderLine(l))
    .join("");

  if (looksLikeToken(collapsed)) return collapsed;
  if (looksLikeToken(trimmed)) return trimmed;
  return null;
}

export function parseDeviceName(text: string): string | null {
  for (const line of text.split(/\r?\n/)) {
    const raw = valueAfterLabel("Device:", line.trim());
    if (!raw) continue;
    const name = raw.split("|")[0]?.trim() ?? raw;
    return name || null;
  }
  return null;
}

function valueAfterLabel(label: string, line: string): string | null {
  const lower = line.toLowerCase();
  if (!lower.startsWith(label.toLowerCase())) return null;
  return line.slice(label.length).trim() || null;
}

function isSetupHeaderLine(line: string): boolean {
  const lower = line.toLowerCase();
  if (lower.startsWith("device:") || lower.startsWith("token:") || lower.startsWith("interval:")) {
    return true;
  }
  return lower.includes("bloomin8") && lower.includes("token");
}

function looksLikeToken(value: string): boolean {
  const s = value.trim();
  if (!s.includes(".")) return false;
  const parts = s.split(".");
  if (parts.length !== 2 || parts[0].length < 8 || parts[1].length < 32) return false;
  return HEX.test(parts[0]) && HEX.test(parts[1]);
}
