// Handler-level tests (Roadmap Item 14 section 22) — `authenticateFn` is
// injected so these run without a live Supabase project; see
// index.ts's doc comment on `handleRequest`. Task-level validation,
// rate limiting, and provider-response shape are already covered at the
// unit level (context_test.ts, mock_provider_test.ts, rate_limiter_test.ts)
// — this file exists specifically for what only the full handler proves:
// auth gating, authority-field rejection, and end-to-end observability
// redaction over a real Response object.

import { assertEquals, assertExists } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { ErrorCode, ForgeError } from "../_shared/errors.ts";
import { handleRequest } from "./index.ts";

const FAKE_USER_ID = "11111111-1111-1111-1111-111111111111";

function fakeAuthOk() {
  return () => Promise.resolve({ client: {} as never, userId: FAKE_USER_ID });
}

function fakeAuthFails() {
  return () => Promise.reject(new ForgeError(ErrorCode.Unauthenticated, "no token"));
}

function postRequest(body: unknown, headers: Record<string, string> = {}): Request {
  return new Request("https://example.test/functions/v1/ai-coach", {
    method: "POST",
    headers: { "Content-Type": "application/json", ...headers },
    body: JSON.stringify(body),
  });
}

async function captureConsoleLog(run: () => Promise<Response>): Promise<{ response: Response; logs: string[] }> {
  const logs: string[] = [];
  const original = console.log;
  console.log = (...args: unknown[]) => logs.push(args.map(String).join(" "));
  try {
    const response = await run();
    return { response, logs };
  } finally {
    console.log = original;
  }
}

Deno.test("rejects a request with no Authorization header (real authenticate, no injection needed)", async () => {
  const response = await handleRequest(postRequest({ task: "coachChat", requestId: "r1" }));
  assertEquals(response.status, 401);
  const data = await response.json();
  assertEquals(data.errorCode, "unauthenticated");
});

Deno.test("rejects when the injected authenticator itself fails", async () => {
  const response = await handleRequest(
    postRequest({ task: "coachChat", requestId: "r1" }, { Authorization: "Bearer x" }),
    fakeAuthFails(),
  );
  assertEquals(response.status, 401);
});

Deno.test("rejects an unknown task", async () => {
  const response = await handleRequest(
    postRequest({ task: "doSomethingElse", requestId: "r1" }, { Authorization: "Bearer x" }),
    fakeAuthOk(),
  );
  assertEquals(response.status, 400);
  const data = await response.json();
  assertEquals(data.errorCode, "invalid_payload");
});

Deno.test("rejects a body carrying a reward-authority field, even nested in context", async () => {
  const response = await handleRequest(
    postRequest(
      { task: "coachChat", requestId: "r1", context: { xp: 999999 } },
      { Authorization: "Bearer x" },
    ),
    fakeAuthOk(),
  );
  assertEquals(response.status, 400);
  const data = await response.json();
  assertEquals(data.errorCode, "forbidden_authority_field");
});

Deno.test("returns a structured, validated success response for a known task", async () => {
  const response = await handleRequest(
    postRequest(
      { task: "weeklyRecap", requestId: "r1", context: { displayName: "Alex" } },
      { Authorization: "Bearer x" },
    ),
    fakeAuthOk(),
  );
  assertEquals(response.status, 200);
  const data = await response.json();
  assertEquals(typeof data.message, "string");
  assertEquals(data.message.length > 0, true);
  assertEquals(data.promptVersion, "weekly_recap_v1");
  assertEquals(Array.isArray(data.suggestedActions), true);
});

Deno.test("enforces the rate limit per user/task at the handler level", async () => {
  const auth = fakeAuthOk();
  const userReq = () =>
    postRequest(
      { task: "postMissionCoaching", requestId: crypto.randomUUID() },
      { Authorization: "Bearer x" },
    );
  let last: Response | null = null;
  for (let i = 0; i < 11; i++) {
    last = await handleRequest(userReq(), auth);
  }
  assertEquals(last!.status, 429);
  const data = await last!.json();
  assertEquals(data.errorCode, "rate_limited");
});

Deno.test("observability log for a success never contains the auth header or request body content", async () => {
  const { logs } = await captureConsoleLog(() =>
    handleRequest(
      postRequest(
        { task: "coachChat", requestId: "obs-1", context: { userMessage: "secret question" } },
        { Authorization: "Bearer super-secret-jwt-value" },
      ),
      fakeAuthOk(),
    )
  );
  assertEquals(logs.length, 1);
  const raw = logs[0].toLowerCase();
  assertEquals(raw.includes("super-secret-jwt-value"), false);
  assertEquals(raw.includes("secret question"), false);
  const parsed = JSON.parse(logs[0]);
  assertEquals(
    Object.keys(parsed).sort(),
    ["commandId", "durationMs", "event", "function", "resultCode", "success"].sort(),
  );
});

Deno.test("observability log for a failure carries a stable error code, not a raw message", async () => {
  const { logs } = await captureConsoleLog(() =>
    handleRequest(postRequest({ task: "coachChat", requestId: "obs-2" })),
  );
  assertEquals(logs.length, 1);
  const parsed = JSON.parse(logs[0]);
  assertEquals(parsed.success, false);
  assertEquals(parsed.resultCode, "unauthenticated");
  assertExists(parsed.durationMs);
});

Deno.test("CORS preflight is handled before authentication ever runs", async () => {
  const response = await handleRequest(
    new Request("https://example.test/functions/v1/ai-coach", { method: "OPTIONS" }),
  );
  assertEquals(response.status, 200);
});
