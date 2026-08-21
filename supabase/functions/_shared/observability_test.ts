import { assertEquals, assertExists } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { logOutcome, withOutcomeLogging } from "./observability.ts";

const FORBIDDEN_KEYS = [
  "jwt",
  "authorization",
  "password",
  "service_role",
  "serviceRoleKey",
  "cronSecret",
  "x-cron-secret",
  "reflection",
  "progress",
  "body",
  "headers",
];

async function captureConsoleLog(
  run: () => void | Promise<void>,
): Promise<string[]> {
  const lines: string[] = [];
  const original = console.log;
  console.log = (...args: unknown[]) => {
    lines.push(args.map(String).join(" "));
  };
  try {
    await run();
    return lines;
  } finally {
    console.log = original;
  }
}

Deno.test("logOutcome emits only the five documented fields, nothing else", async () => {
  const lines = await captureConsoleLog(() => {
    logOutcome({
      function: "accept-mission",
      commandId: "cmd-123",
      resultCode: "accepted",
      durationMs: 42,
      success: true,
    });
  });
  assertEquals(lines.length, 1);
  const parsed = JSON.parse(lines[0]);
  assertEquals(
    Object.keys(parsed).sort(),
    ["commandId", "durationMs", "event", "function", "resultCode", "success"].sort(),
  );
});

Deno.test("logOutcome never contains a forbidden key, even nested", async () => {
  const lines = await captureConsoleLog(() => {
    logOutcome({
      function: "submit-mission",
      commandId: "cmd-456",
      resultCode: "invalid_transition",
      durationMs: 7,
      success: false,
    });
  });
  const raw = lines[0].toLowerCase();
  for (const key of FORBIDDEN_KEYS) {
    if (raw.includes(key.toLowerCase())) {
      throw new Error(`Forbidden key/value fragment "${key}" found in log output: ${raw}`);
    }
  }
});

Deno.test("withOutcomeLogging logs success:true and the resolved result code on success", async () => {
  const lines = await captureConsoleLog(async () => {
    const result = await withOutcomeLogging(
      "start-mission",
      "cmd-789",
      () => Promise.resolve({ status: "accepted" }),
      (r) => r.status,
      (r) => r.status === "accepted",
    );
    assertEquals(result.status, "accepted");
  });
  const parsed = JSON.parse(lines[0]);
  assertEquals(parsed.success, true);
  assertEquals(parsed.resultCode, "accepted");
  assertExists(parsed.durationMs);
});

Deno.test("withOutcomeLogging logs success:false and the error's errorCode on failure, then rethrows", async () => {
  let threw = false;
  const lines = await captureConsoleLog(async () => {
    try {
      await withOutcomeLogging(
        "submit-mission",
        "cmd-fail",
        () => {
          const err = new Error("stale_sequence|stale") as Error & {
            errorCode?: string;
          };
          err.errorCode = "stale_sequence";
          throw err;
        },
        (r) => (r as { status: string }).status,
        () => false,
      );
    } catch {
      threw = true;
    }
  });
  assertEquals(threw, true);
  const parsed = JSON.parse(lines[0]);
  assertEquals(parsed.success, false);
  assertEquals(parsed.resultCode, "stale_sequence");
});
