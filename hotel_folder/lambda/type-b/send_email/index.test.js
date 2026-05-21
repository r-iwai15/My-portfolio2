import { describe, it, expect, vi } from "vitest";
const mockSend = vi.fn();
vi.mock("@aws-sdk/client-ses", () => ({
  SESClient: vi.fn(() => ({ send: mockSend })),
  SendEmailCommand: vi.fn((input) => input),
}));
const { handler } = await import("./index.js");

describe("send_email handler", () => {
  it("SNS/SQSからのイベントを受け取り、メールを送信する", async () => {
    mockSend.mockResolvedValue({});
    const event = { Records: [{ body: JSON.stringify({ email: "test@example.com" }) }] };
    await handler(event);
    expect(mockSend).toHaveBeenCalled();
  });
});