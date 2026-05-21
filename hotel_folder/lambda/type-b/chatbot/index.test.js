/**
 * Type-B: Chatbot Lambda テスト
 * VPC内vLLMサーバー（Qwen2.5-7B）を呼ぶ実装に合わせたテスト
 */
import { describe, it, expect, vi, beforeEach } from "vitest";

const mockS3Send = vi.fn();
const mockFetch  = vi.fn();

vi.mock("@aws-sdk/client-s3", () => ({
  S3Client:        vi.fn(() => ({ send: mockS3Send })),
  PutObjectCommand: vi.fn((input) => input),
}));
vi.stubGlobal("fetch", mockFetch);

process.env.LLM_ENDPOINT       = "http://10.0.41.10:8000/v1";
process.env.LLM_MODEL_ID       = "Qwen/Qwen2.5-7B-Instruct";
process.env.CHATBOT_LOG_BUCKET = "test-bucket";
process.env.SYSTEM_PROMPT      = "あなたはホテルの予約アシスタントです。";
process.env.AWS_REGION         = "ap-northeast-1";

const { handler } = await import("./index.js");

function makeEvent(message, { userId = "user-123", sourceIp = "1.2.3.4" } = {}) {
  return {
    body: JSON.stringify({ message }),
    requestContext: {
      authorizer: { claims: { sub: userId } },
      identity:   { sourceIp },
    },
  };
}

function mockVllmSuccess(content = "ご予約を承ります。") {
  mockFetch.mockResolvedValue({
    ok:   true,
    json: async () => ({ choices: [{ message: { content } }] }),
  });
}

describe("handler", () => {
  beforeEach(() => vi.clearAllMocks());

  it("正常なメッセージに対してAIの返答を返す", async () => {
    mockVllmSuccess("チェックインは15時からです。");
    mockS3Send.mockResolvedValue({});

    const res  = await handler(makeEvent("チェックイン時間は？"));
    const body = JSON.parse(res.body);

    expect(res.statusCode).toBe(200);
    expect(body.reply).toBe("チェックインは15時からです。");
  });

  it("messageが未指定の場合は400を返す", async () => {
    const res = await handler({ body: "{}" });
    expect(res.statusCode).toBe(400);
    expect(mockFetch).not.toHaveBeenCalled();
  });

  it("vLLMサーバーがエラーを返した場合は502を返す", async () => {
    mockFetch.mockResolvedValue({ ok: false, status: 503, text: async () => "Service Unavailable" });
    const res = await handler(makeEvent("hello"));
    expect(res.statusCode).toBe(502);
  });

  it("vLLMへのリクエストにsystemプロンプトとuserMessageが含まれる", async () => {
    mockVllmSuccess();
    mockS3Send.mockResolvedValue({});
    await handler(makeEvent("空室はありますか？"));

    const payload = JSON.parse(mockFetch.mock.calls[0][1].body);
    expect(payload.messages[0]).toEqual({ role: "system", content: process.env.SYSTEM_PROMPT });
    expect(payload.messages[1]).toEqual({ role: "user",   content: "空室はありますか？" });
  });

  it("CloudWatch Logsにsourceip・userId・メッセージが出力される", async () => {
    const consoleSpy = vi.spyOn(console, "log");
    mockVllmSuccess("はい、空室があります。");
    mockS3Send.mockResolvedValue({});

    await handler(makeEvent("空室はありますか？", { userId: "user-456", sourceIp: "5.6.7.8" }));

    const logged = JSON.parse(consoleSpy.mock.calls[0][0]);
    expect(logged.sourceIp).toBe("5.6.7.8");
    expect(logged.userId).toBe("user-456");
    expect(logged.userMessage).toBe("空室はありますか？");
  });
});
