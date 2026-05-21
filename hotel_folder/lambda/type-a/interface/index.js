/**
 * Type-A: Interface Lambda (White / Gray — 対話のみ)
 *
 * API Gateway から Bedrock Agent を起動し、自然言語を委譲する。
 * DB 書き込み・決済は execution 層が担当（本 Lambda には副作用なし）。
 *
 * Env:
 *   BEDROCK_AGENT_ID       - Bedrock Agent ID
 *   BEDROCK_AGENT_ALIAS_ID - Bedrock Agent エイリアス ID
 */

import { BedrockAgentRuntimeClient, InvokeAgentCommand } from "@aws-sdk/client-bedrock-agent-runtime";

const agentClient = new BedrockAgentRuntimeClient({ region: process.env.AWS_REGION });
const AGENT_ID = process.env.BEDROCK_AGENT_ID;
const AGENT_ALIAS_ID = process.env.BEDROCK_AGENT_ALIAS_ID ?? "TSTALIASID";

export const handler = async (event) => {
  const body = JSON.parse(event.body ?? "{}");
  const message = body.message;
  const sessionId = event.requestContext?.authorizer?.claims?.sub ?? `session-${Date.now()}`;

  if (!message) {
    return { statusCode: 400, body: JSON.stringify({ error: "message フィールドが必要です。" }) };
  }

  try {
    const response = await agentClient.send(
      new InvokeAgentCommand({
        agentId: AGENT_ID,
        agentAliasId: AGENT_ALIAS_ID,
        sessionId,
        inputText: message,
      })
    );

    let fullResponse = "";
    for await (const chunk of response.completion) {
      if (chunk.chunk?.bytes) {
        fullResponse += new TextDecoder().decode(chunk.chunk.bytes);
      }
    }

    return {
      statusCode: 200,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ reply: fullResponse }),
    };
  } catch (err) {
    console.error("Bedrock Agent invocation failed:", err);
    return { statusCode: 502, body: JSON.stringify({ error: "AIコンシェルジュに接続できませんでした。" }) };
  }
};
