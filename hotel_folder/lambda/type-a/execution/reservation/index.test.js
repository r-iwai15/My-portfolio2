/**
 * Type-A: Reservation Execution Lambda テスト
 */
import { describe, it, expect, vi, beforeEach } from "vitest";

const mockDdbSend = vi.fn();

vi.mock("@aws-sdk/client-dynamodb", () => ({
  DynamoDBClient: vi.fn(() => ({})),
}));
vi.mock("@aws-sdk/lib-dynamodb", () => ({
  DynamoDBDocumentClient: { from: vi.fn(() => ({ send: mockDdbSend })) },
  GetCommand: vi.fn((input) => input),
  PutCommand: vi.fn((input) => input),
  UpdateCommand: vi.fn((input) => input),
}));

process.env.TABLE_NAME = "hotel-agile-ai-reservations";
process.env.AWS_REGION = "ap-northeast-1";

const { handler } = await import("./index.js");

function makeAgentEvent(params = {}) {
  return {
    actionGroup: "ReservationWriter",
    apiPath: "/reservation",
    httpMethod: "POST",
    parameters: Object.entries(params).map(([name, value]) => ({ name, value })),
  };
}

const CREATE_PARAMS = {
  action: "create",
  guestName: "田中花子",
  checkIn: "2025-09-01",
  checkOut: "2025-09-03",
  roomType: "SUITE",
};

describe("Reservation Execution (Bedrock Agent → DynamoDB)", () => {
  beforeEach(() => vi.clearAllMocks());

  describe("予約作成 (action: create)", () => {
    it("全パラメータ揃っていれば予約を作成し料金を含めて返す", async () => {
      mockDdbSend.mockResolvedValue({});
      const res = await handler(makeAgentEvent(CREATE_PARAMS));
      const body = JSON.parse(res.response.responseBody["application/json"].body);
      expect(res.response.httpStatusCode).toBe(200);
      expect(body.success).toBe(true);
      expect(body.reservationId).toMatch(/^RES-/);
      expect(body.totalPriceJpy).toBe(56_000);
      expect(body.nights).toBe(2);
    });

    it("必須パラメータ不足の場合はエラーを返す", async () => {
      const res = await handler(makeAgentEvent({ action: "create", guestName: "田中" }));
      const body = JSON.parse(res.response.responseBody["application/json"].body);
      expect(res.response.httpStatusCode).toBe(400);
      expect(body.error).toBeDefined();
      expect(mockDdbSend).not.toHaveBeenCalled();
    });

    it("idempotencyKey が既存なら再実行せず同じ reservationId を返す", async () => {
      mockDdbSend.mockImplementation((cmd) => {
        if (cmd.Key?.PK?.startsWith("IDEMPOTENCY#")) {
          return { Item: { reservationId: "RES-EXIST1" } };
        }
        return {};
      });
      const res = await handler(
        makeAgentEvent({ ...CREATE_PARAMS, idempotencyKey: "idem-key-12345678" })
      );
      const body = JSON.parse(res.response.responseBody["application/json"].body);
      expect(body.deduplicated).toBe(true);
      expect(body.reservationId).toBe("RES-EXIST1");
    });
  });

  describe("予約更新 (action: update)", () => {
    it("reservationIdと更新フィールドで成功する", async () => {
      mockDdbSend.mockResolvedValue({});
      const res = await handler(
        makeAgentEvent({ action: "update", reservationId: "RES-001", checkOut: "2025-09-05" })
      );
      const body = JSON.parse(res.response.responseBody["application/json"].body);
      expect(body.success).toBe(true);
    });
  });

  describe("予約キャンセル (action: cancel)", () => {
    it("予約をキャンセルしsuccessを返す", async () => {
      mockDdbSend.mockResolvedValue({});
      const res = await handler(makeAgentEvent({ action: "cancel", reservationId: "RES-001" }));
      const body = JSON.parse(res.response.responseBody["application/json"].body);
      expect(body.success).toBe(true);
    });
  });

  describe("不明なアクション", () => {
    it("未定義のactionはエラーを返す", async () => {
      const res = await handler(makeAgentEvent({ action: "delete_all" }));
      const body = JSON.parse(res.response.responseBody["application/json"].body);
      expect(res.response.httpStatusCode).toBe(400);
      expect(body.error).toBeDefined();
    });
  });

  it("actionGroup がない呼び出しは拒否する", async () => {
    const res = await handler({});
    expect(res.statusCode).toBe(400);
  });
});
