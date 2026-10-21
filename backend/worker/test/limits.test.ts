import { expect, it } from "vitest";
import { MemoryStorage } from "./helpers";
import { reserve, SnapshotCache } from "../src/limits";

it("atomically enforces team-wide admission under concurrent requests", async () => {
  const storage = new MemoryStorage();
  const admitted = await Promise.all(
    Array.from({ length: 30 }, () =>
      reserve(storage.asStorage(), "request", Date.UTC(2026, 9, 21)),
    ),
  );
  expect(admitted.filter(Boolean)).toHaveLength(10);
  // Recreating the caller does not clear persisted counters.
  expect(
    await reserve(storage.asStorage(), "request", Date.UTC(2026, 9, 21)),
  ).toBe(false);
});
it("counts retries, enforces cooldown, and resets the daily budget in UTC", async () => {
  const storage = new MemoryStorage(),
    now = Date.UTC(2026, 9, 21);
  expect(await reserve(storage.asStorage(), "ai", now)).toBe(true);
  expect(await reserve(storage.asStorage(), "ai", now + 1)).toBe(false);
  for (let i = 1; i < 20; i++)
    expect(await reserve(storage.asStorage(), "retry", now)).toBe(true);
  expect(await reserve(storage.asStorage(), "retry", now)).toBe(false);
  expect(await reserve(storage.asStorage(), "ai", now + 86400000)).toBe(true);
});
it("bounds persisted snapshots to ten entries with expiry and LRU eviction", async () => {
  const storage = new MemoryStorage(),
    cache = new SnapshotCache(storage.asStorage());
  for (let i = 0; i < 10; i++) await cache.put(`${i}`, `${i}`, i);
  expect(await cache.get("0", 20)).toBe("0");
  await cache.put("10", "10", 21);
  expect(await cache.get("1", 22)).toBeUndefined();
  expect(await new SnapshotCache(storage.asStorage()).get("0", 22)).toBe("0");
  expect(await cache.get("0", 600000)).toBeUndefined();
  expect(
    [...storage.data.keys()].filter((k) => k.startsWith("cache:")),
  ).toHaveLength(9);
});

it("enforces the daily API budget across minute windows and resets on the next UTC day", async () => {
  const storage = new MemoryStorage(),
    start = Date.UTC(2026, 9, 21);
  for (let i = 0; i < 100; i++) {
    expect(
      await reserve(
        storage.asStorage(),
        "request",
        start + Math.floor(i / 10) * 60000,
      ),
    ).toBe(true);
  }
  expect(
    await reserve(storage.asStorage(), "request", start + 10 * 60000),
  ).toBe(false);
  expect(await reserve(storage.asStorage(), "request", start + 86400000)).toBe(
    true,
  );
});
