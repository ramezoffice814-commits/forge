import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { GeminiProvider } from "./gemini_provider.ts";
import { AiCoachContext } from "./context.ts";

const emptyContext = {} as AiCoachContext;
const template = {
  version: "coach_chat_v1",
  systemPrompt: "You are the Watcher.",
  userPrompt: "Reply briefly.",
};

function fakeFetch(
  impl: (url: string, init: RequestInit) => Promise<Response>,
): typeof fetch {
  return impl as unknown as typeof fetch;
}

Deno.test("GeminiProvider parses a well-formed response into ProviderResponse", async () => {
  const provider = new GeminiProvider({
    apiKey: "test-key",
    fetchFn: fakeFetch((url, init) => {
      assertEquals(url.includes("key=test-key"), true);
      const body = JSON.parse(init.body as string);
      assertEquals(body.systemInstruction.parts[0].text, template.systemPrompt);
      assertEquals(body.contents[0].parts[0].text, template.userPrompt);
      return Promise.resolve(
        new Response(
          JSON.stringify({
            candidates: [
              { content: { parts: [{ text: "  Steady now. Keep going.  " }] } },
            ],
          }),
          { status: 200 },
        ),
      );
    }),
  });

  const result = await provider.generate("coachChat", emptyContext, template);
  assertEquals(result.message, "Steady now. Keep going.");
});

Deno.test("GeminiProvider attaches the task's suggested actions", async () => {
  const provider = new GeminiProvider({
    apiKey: "test-key",
    fetchFn: fakeFetch(() =>
      Promise.resolve(
        new Response(
          JSON.stringify({
            candidates: [{ content: { parts: [{ text: "Nice work." }] } }],
          }),
          { status: 200 },
        ),
      )
    ),
  });

  const result = await provider.generate(
    "postMissionCoaching",
    emptyContext,
    template,
  );
  assertEquals(result.suggestedActions, ["openProgress"]);
});

Deno.test("GeminiProvider throws on a non-2xx response", async () => {
  const provider = new GeminiProvider({
    apiKey: "test-key",
    fetchFn: fakeFetch(() =>
      Promise.resolve(new Response("rate limited", { status: 429 }))
    ),
  });

  await assertRejects(() => provider.generate("coachChat", emptyContext, template));
});

Deno.test("GeminiProvider throws when the response has no usable text", async () => {
  const provider = new GeminiProvider({
    apiKey: "test-key",
    fetchFn: fakeFetch(() =>
      Promise.resolve(new Response(JSON.stringify({ candidates: [] }), { status: 200 }))
    ),
  });

  await assertRejects(() => provider.generate("coachChat", emptyContext, template));
});

Deno.test("GeminiProvider throws on unparseable JSON", async () => {
  const provider = new GeminiProvider({
    apiKey: "test-key",
    fetchFn: fakeFetch(() => Promise.resolve(new Response("not json", { status: 200 }))),
  });

  await assertRejects(() => provider.generate("coachChat", emptyContext, template));
});
