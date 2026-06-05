/**
 * Type-A: Interface Lambda テスト
 */
import { describe, it, expect, vi, beforeEach } from "vitest";

const mockAgentSend = vi.fn();

vi.mock("@aws-sdk/client-bedrock-agent-runtime", () => ({
  BedrockAgentRuntimeClient: vi.fn(() => ({ send: mockAgentSend })),
  InvokeAgentCommand: vi.fn((input) => input),
}));

process.env.BEDROCK_AGENT_ID = "test-agent-id";
process.env.BEDROCK_AGENT_ALIAS_ID = "test-alias-id";
process.env.AWS_REGION = "ap-northeast-1";

const { handler } = await import("./index.js");

function makeApiGwEvent(message, { userId = "user-123" } = {}) {
  return {
    body: JSON.stringify({ message }),
    requestContext: { apiId: "test-api-id", authorizer: { claims: { sub: userId } } },
  };
}

function mockAgentReply(text = "予約を承りました。") {
  const encoder = new TextEncoder();
  async function* generate() {
    yield { chunk: { bytes: encoder.encode(text) } };
  }
  mockAgentSend.mockResolvedValue({ completion: generate() });
}

describe("Interface Lambda (API Gateway → Bedrock Agent)", () => {
  beforeEach(() => vi.clearAllMocks());

  it("ユーザーメッセージをエージェントに渡して返答を返す", async () => {
    mockAgentReply("ご予約を承りました。");
    const res = await handler(makeApiGwEvent("8月1日から2泊お願いします"));
    const body = JSON.parse(res.body);
    expect(res.statusCode).toBe(200);
    expect(body.reply).toBe("ご予約を承りました。");
  });

  it("messageが未指定の場合は400を返す", async () => {
    const res = await handler({ body: "{}", requestContext: { apiId: "x" } });
    expect(res.statusCode).toBe(400);
    expect(mockAgentSend).not.toHaveBeenCalled();
  });

  it("不正なJSONボディの場合は500ではなく400を返す", async () => {
    const res = await handler({ body: "{not json", requestContext: { apiId: "x" } });
    expect(res.statusCode).toBe(400);
    expect(mockAgentSend).not.toHaveBeenCalled();
  });

  it("Bedrock Agentが失敗した場合は502を返す", async () => {
    mockAgentSend.mockRejectedValue(new Error("Agent timeout"));
    const res = await handler(makeApiGwEvent("予約したい"));
    expect(res.statusCode).toBe(502);
  });

  it("CognitoのuserIdをsessionIdとして使う", async () => {
    mockAgentReply();
    await handler(makeApiGwEvent("hello", { userId: "user-abc" }));
    expect(mockAgentSend.mock.calls[0][0].sessionId).toBe("user-abc");
  });
});
