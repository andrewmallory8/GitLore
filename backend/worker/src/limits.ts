/** Persistent, transactional team-wide budgets. Retries consume real attempts. */
export interface Budget {
  day: string;
  calls: number;
  attempts: number;
  lastAiStart: number;
  minute: number;
  minuteCalls: number;
}
export const REQUESTS_PER_DAY = 100,
  REQUESTS_PER_MINUTE = 10,
  GEMINI_ATTEMPTS_PER_DAY = 20;
export async function reserve(
  storage: DurableObjectStorage,
  kind: "request" | "ai" | "retry",
  now = Date.now(),
): Promise<boolean> {
  return storage.transaction(async (tx) => {
    const day = new Date(now).toISOString().slice(0, 10),
      minute = Math.floor(now / 60000);
    let b = await tx.get<Budget>("budget");
    if (!b || b.day !== day)
      b = {
        day,
        calls: 0,
        attempts: 0,
        lastAiStart: 0,
        minute,
        minuteCalls: 0,
      };
    if (b.minute !== minute) {
      b.minute = minute;
      b.minuteCalls = 0;
    }
    if (kind === "request") {
      if (b.calls >= REQUESTS_PER_DAY || b.minuteCalls >= REQUESTS_PER_MINUTE)
        return false;
      b.calls++;
      b.minuteCalls++;
    } else {
      if (
        b.attempts >= GEMINI_ATTEMPTS_PER_DAY ||
        (kind === "ai" && b.lastAiStart !== 0 && now - b.lastAiStart < 15000)
      )
        return false;
      b.attempts++;
      if (kind === "ai") b.lastAiStart = now;
    }
    await tx.put("budget", b);
    return true;
  });
}

interface CacheRecord {
  value: string;
  expires: number;
  used: number;
}
export class SnapshotCache {
  constructor(private storage: DurableObjectStorage) {}
  async get(key: string, now = Date.now()): Promise<string | undefined> {
    return this.storage.transaction(async (tx) => {
      const entry = await tx.get<CacheRecord>(`cache:${key}`);
      if (!entry) return;
      if (entry.expires <= now) {
        await tx.delete(`cache:${key}`);
        return;
      }
      entry.used = now;
      await tx.put(`cache:${key}`, entry);
      return entry.value;
    });
  }
  async put(key: string, value: string, now = Date.now()): Promise<void> {
    // SQLite-backed Durable Object keys/values allow up to 2 MB combined.
    if (new TextEncoder().encode(value).length > 1500000) return;
    await this.storage.transaction(async (tx) => {
      const entries = await tx.list<CacheRecord>({ prefix: "cache:" });
      for (const [k, v] of entries)
        if (v.expires <= now) {
          await tx.delete(k);
          entries.delete(k);
        }
      entries.delete(`cache:${key}`);
      while (entries.size >= 10) {
        const oldest = [...entries].sort((a, b) => a[1].used - b[1].used)[0][0];
        await tx.delete(oldest);
        entries.delete(oldest);
      }
      await tx.put(`cache:${key}`, { value, expires: now + 600000, used: now });
    });
  }
}
export async function digest(value: string): Promise<string> {
  return [
    ...new Uint8Array(
      await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value)),
    ),
  ]
    .map((v) => v.toString(16).padStart(2, "0"))
    .join("");
}
