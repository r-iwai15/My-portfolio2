import { describe, it, expect, vi, beforeEach } from "vitest";

const mockSend = vi.fn();
vi.mock("@aws-sdk/client-dynamodb", () => ({
  DynamoDBClient: vi.fn(() => ({})),
}));
vi.mock("@aws-sdk/lib-dynamodb", () => ({
  DynamoDBDocumentClient: { from: vi.fn(() => ({ send: mockSend })) },
  GetCommand: vi.fn((input) => input),
  QueryCommand: vi.fn((input) => input),
}));

process.env.TABLE_NAME = "hotel-agile-ai-reservations";
process.env.AWS_REGION = "ap-northeast-1";

const { handler } = await import("./index.js");

describe("reader handler", () => {
  beforeEach(() => vi.clearAllMocks());

  describe("正常系: 予約の照会", () => {
    it("reservationIdが指定された場合、GetCommandで予約を1件取得する", async () => {
      mockSend.mockResolvedValue({ Item: { reservationId: "RES-123", guestName: "山田" } });
      const event = { parameters: [{ name: "reservationId", value: "RES-123" }] };
      
      const res = await handler(event);
      expect(res.response.httpStatusCode).toBe(200);
      expect(JSON.parse(res.response.responseBody["application/json"].body).found).toBe(true);
      expect(mockSend).toHaveBeenCalledTimes(1);
    });

    it("guestNameが指定された場合、QueryCommandで予約一覧を取得する", async () => {
      mockSend.mockResolvedValue({ Items: [{ reservationId: "RES-456" }], Count: 1 });
      const event = { parameters: [{ name: "guestName", value: "佐藤" }] };
      
      const res = await handler(event);
      expect(res.response.httpStatusCode).toBe(200);
      expect(JSON.parse(res.response.responseBody["application/json"].body).count).toBe(1);
    });
  });

  describe("異常系: エラーハンドリング", () => {
    it("検索パラメータが全くない場合はエラーレスポンスを返す", async () => {
      const event = { parameters: [] }; // カラっぽ
      
      const res = await handler(event);
      expect(res.response.httpStatusCode).toBe(500); 
      expect(JSON.parse(res.response.responseBody["application/json"].body).error).toBeDefined();
      expect(mockSend).not.toHaveBeenCalled();
    });

    it("DynamoDBの通信に失敗した場合はエラーレスポンスを返す", async () => {
      mockSend.mockRejectedValue(new Error("DB Timeout"));
      const event = { parameters: [{ name: "reservationId", value: "RES-999" }] };
      
      const res = await handler(event);
      expect(res.response.httpStatusCode).toBe(500);
    });
  });
});