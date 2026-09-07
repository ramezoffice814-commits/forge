// The shape any AI Coach provider must implement — mock or real. Pulled
// out of mock_provider.ts (which previously declared ProviderResponse
// itself) so index.ts can select between providers without either one
// importing the other for its own type.

import { AiCoachContext } from "./context.ts";
import { PromptTemplate } from "./prompt_templates.ts";

export interface ProviderResponse {
  message: string;
  reasoningSummary?: string;
  suggestedActions?: string[];
}

export interface Provider {
  generate(
    task: string,
    context: AiCoachContext,
    template: PromptTemplate,
  ): Promise<ProviderResponse>;
}
