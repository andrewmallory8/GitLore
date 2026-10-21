import { ApiError } from "./contracts";

export type Fetcher = typeof fetch;
/** Bound streaming memory and optionally the entire body-read duration. */
export async function readBytes(
  response: Response,
  max: number,
  timeoutMs?: number,
): Promise<Uint8Array> {
  if (Number(response.headers.get("content-length")) > max) {
    void response.body?.cancel().catch(() => {});
    throw new ApiError(
      502,
      "response_too_large",
      "An upstream response exceeded the safe size limit.",
    );
  }
  const reader = response.body?.getReader();
  if (!reader) return new Uint8Array();
  const chunks: Uint8Array[] = [];
  let size = 0;
  let timedOut = false;
  const timer =
    timeoutMs === undefined
      ? undefined
      : setTimeout(() => {
          timedOut = true;
          void reader.cancel().catch(() => {});
        }, timeoutMs);
  try {
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > max)
        throw new ApiError(
          502,
          "response_too_large",
          "An upstream response exceeded the safe size limit.",
        );
      chunks.push(value);
    }
    if (timedOut)
      throw new ApiError(
        408,
        "request_timeout",
        "Request body took too long to arrive.",
      );
  } catch (error) {
    void reader.cancel().catch(() => {});
    throw error;
  } finally {
    clearTimeout(timer);
    reader.releaseLock();
  }
  const result = new Uint8Array(size);
  let offset = 0;
  for (const c of chunks) {
    result.set(c, offset);
    offset += c.length;
  }
  return result;
}
export async function fetchJson(
  url: string,
  init: RequestInit,
  max: number,
  timeout: number,
  fetcher: Fetcher = fetch,
): Promise<{ status: number; headers: Headers; body: unknown }> {
  const abort = new AbortController();
  const timer = setTimeout(() => abort.abort(), Math.max(1, timeout));
  try {
    const response = await fetcher(url, {
      ...init,
      signal: abort.signal,
      // Workers does not implement redirect:"error". Manual returns 3xx to
      // callers, which reject it without forwarding credentials to Location.
      redirect: "manual",
    });
    // Never read, log, or echo provider diagnostic bodies on HTTP errors.
    if (!response.ok) {
      await response.body?.cancel();
      return { status: response.status, headers: response.headers, body: null };
    }
    const bytes = await readBytes(response, max);
    const body: unknown = JSON.parse(
      new TextDecoder("utf-8", { fatal: true, ignoreBOM: false }).decode(bytes),
    );
    return { status: response.status, headers: response.headers, body };
  } catch (error) {
    if (abort.signal.aborted)
      throw new ApiError(
        504,
        "upstream_timeout",
        "The upstream request timed out.",
      );
    throw error;
  } finally {
    clearTimeout(timer);
  }
}
export function json(
  data: unknown,
  status = 200,
  headers?: HeadersInit,
): Response {
  const h = new Headers(headers);
  h.set("Content-Type", "application/json; charset=utf-8");
  h.set("Cache-Control", "no-store");
  h.set("X-Content-Type-Options", "nosniff");
  return new Response(JSON.stringify(data), { status, headers: h });
}
export function failure(error: unknown): Response {
  const e =
    error instanceof ApiError
      ? error
      : new ApiError(
          500,
          "internal_error",
          "Analysis could not be completed. Try again.",
        );
  return json(
    { schemaVersion: 1, error: { code: e.code, message: e.message } },
    e.status,
    e.status === 429 ? { "Retry-After": "60" } : undefined,
  );
}
