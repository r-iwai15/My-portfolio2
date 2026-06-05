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
  GetCommand: vi.fn((input) => ({ ...input, __type: "Get" })),
  PutCommand: vi.fn((input) => ({ ...input, __type: "Put" })),
  UpdateCommand: vi.fn((input) => ({ ...input, __type: "Update" })),
  TransactWriteCommand: vi.fn((input) => ({ ...input, __type: "Transact" })),
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

    it("新規 idempotencyKey は予約とべき等レコードをトランザクションで原子的に書き込む", async () => {
      mockDdbSend.mockImplementation((cmd) => {
        if (cmd.__type === "Get") return {}; // 既存なし
        return {}; // Transact 成功
      });
      const res = await handler(
        makeAgentEvent({ ...CREATE_PARAMS, idempotencyKey: "new-idem-key-123" })
      );
      const body = JSON.parse(res.response.responseBody["application/json"].body);
      expect(body.success).toBe(true);
      expect(body.reservationId).toMatch(/^RES-/);

      const transactCall = mockDdbSend.mock.calls.find((c) => c[0].__type === "Transact");
      expect(transactCall).toBeDefined();
      expect(transactCall[0].TransactItems).toHaveLength(2);
      // 1件目はべき等性レコード、ConditionExpression で二重実行を防ぐ
      expect(transactCall[0].TransactItems[0].Put.Item.PK).toMatch(/^IDEMPOTENCY#/);
      expect(transactCall[0].TransactItems[0].Put.ConditionExpression).toContain("attribute_not_exists");
    });

    it("トランザクション競合時は既存予約を返す（レース）", async () => {
      mockDdbSend.mockImplementation((cmd) => {
        if (cmd.__type === "Get") {
          // 1回目は存在なし、競合後の再読込で既存を返す
          return mockDdbSend.mock.calls.filter((c) => c[0].__type === "Get").length > 1
            ? { Item: { reservationId: "RES-RACE99" } }
            : {};
        }
        if (cmd.__type === "Transact") {
          const e = new Error("conflict");
          e.name = "TransactionCanceledException";
          throw e;
        }
        return {};
      });
      const res = await handler(
        makeAgentEvent({ ...CREATE_PARAMS, idempotencyKey: "race-idem-key-1" })
      );
      const body = JSON.parse(res.response.responseBody["application/json"].body);
      expect(body.deduplicated).toBe(true);
      expect(body.reservationId).toBe("RES-RACE99");
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
