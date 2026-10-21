import {
  ApiError,
  parseRequest,
  parseDiagnosticRequest,
  type Env,
} from "./contracts";
import { failure, json, readBytes } from "./http";
import { digest } from "./limits";
import { DEFAULT_MODEL } from "./services/gemini";
export { AnalysisCoordinator } from "./coordinator";

async function authorized(
  header: string | null,
  token: string,
): Promise<boolean> {
  if (!header || header.length > 2048) return false;
  // Fixed-length digests avoid a comparison that stops at the first mismatch.
  const [a, b] = await Promise.all([digest(header), digest(`Bearer ${token}`)]);
  let different = 0;
  for (let i = 0; i < a.length; i++)
    different |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return different === 0;
}

async function handle(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  if (
    !["/health", "/v1/analyze", "/v1/diagnostics/gemini"].includes(
      url.pathname,
    ) ||
    url.search
  )
    throw new ApiError(
      404,
      "not_found",
      "Use GET /health or POST /v1/analyze.",
    );
  if (request.method === "OPTIONS") return new Response(null, { status: 204 });
  const model = env.GEMINI_MODEL ?? DEFAULT_MODEL;
  const configured =
    !!env.ANALYSES &&
    (env.TEAM_ACCESS_TOKEN?.length ?? 0) >= 32 &&
    /^gemini-[a-z0-9.-]+$/.test(model);
  if (url.pathname === "/health" && request.method === "GET")
    return json(
      {
        status: configured ? "ok" : "not_configured",
        aiConfigured: !!env.GEMINI_API_KEY?.trim(),
      },
      configured ? 200 : 503,
    );
  if (!configured)
    throw new ApiError(
      503,
      "not_configured",
      "The analysis server is not configured. Contact the server owner.",
    );
  if (
    !(await authorized(
      request.headers.get("authorization"),
      env.TEAM_ACCESS_TOKEN!,
    ))
  )
    throw new ApiError(
      401,
      "unauthorized",
      "Enter the team access code in Server settings.",
    );
  if (request.method !== "POST" || url.pathname === "/health")
    throw new ApiError(
      405,
      "method_not_allowed",
      "Use POST for analysis or diagnostics.",
    );
  if (
    request.headers.get("content-type")?.split(";")[0].trim().toLowerCase() !==
    "application/json"
  )
    throw new ApiError(415, "content_type", "Send application/json.");
  let input;
  try {
    const bytes = await readBytes(
      new Response(request.body, { headers: request.headers }),
      4096,
      10000,
    );
    input = (
      url.pathname === "/v1/diagnostics/gemini"
        ? parseDiagnosticRequest
        : parseRequest
    )(
      JSON.parse(
        new TextDecoder("utf-8", { fatal: true, ignoreBOM: false }).decode(
          bytes,
        ),
      ),
    );
  } catch (error) {
    if (error instanceof ApiError && error.status === 408) throw error;
    if (error instanceof ApiError && error.code === "response_too_large")
      throw new ApiError(
        413,
        "request_too_large",
        "Request body exceeds 4096 bytes.",
      );
    throw new ApiError(
      400,
      "invalid_request",
      url.pathname === "/v1/diagnostics/gemini"
        ? "Send schemaVersion: 1 and an optional ping/story mode."
        : "Send schemaVersion: 1, a public GitHub repository url, and optional boolean ai.",
    );
  }
  const id = env.ANALYSES.idFromName("gitlore-team-v1");
  return env.ANALYSES.get(id).fetch(
    new Request(`https://coordinator${url.pathname}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(input),
    }),
  );
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const origin = request.headers.get("origin"),
      allowed = (env.ALLOWED_ORIGINS ?? "")
        .split(",")
        .map((s) => s.trim())
        .filter(Boolean);
    // CORS supplements authentication; non-browser callers still need a token.
    if (origin !== null && !allowed.includes(origin))
      return failure(
        new ApiError(
          403,
          "forbidden_origin",
          "This browser origin is not allowed.",
        ),
      );
    let response: Response;
    try {
      response = await handle(request, env);
    } catch (error) {
      response = failure(error);
    }
    const headers = new Headers(response.headers);
    if (origin !== null) {
      headers.set("Access-Control-Allow-Origin", origin);
      headers.set("Vary", "Origin");
      headers.set("Access-Control-Allow-Methods", "POST, GET, OPTIONS");
      headers.set(
        "Access-Control-Allow-Headers",
        "Content-Type, Authorization",
      );
    }
    return new Response(response.body, { status: response.status, headers });
  },
};
