import { describe, it, expect } from "vitest";
import { handler } from "./index.js";

describe("rag_query stub", () => {
  it("returns 400 when query missing", async () => {
    const r = await handler({});
    expect(r.statusCode).toBe(400);
  });

  it("returns stub answer", async () => {
    const r = await handler({ query: "休暇申請の流れは？" });
    expect(r.statusCode).toBe(200);
    const b = JSON.parse(r.body);
    expect(b.answer).toContain("stub");
  });

  it("parses query from a JSON string body (API Gateway style)", async () => {
    const r = await handler({ body: JSON.stringify({ query: "経費精算は？" }) });
    expect(r.statusCode).toBe(200);
    expect(JSON.parse(r.body).answer).toContain("経費精算");
  });

  it("returns 400 on malformed JSON body instead of throwing", async () => {
    const r = await handler({ body: "{not valid json" });
    expect(r.statusCode).toBe(400);
  });

  it("handles a non-string query without throwing", async () => {
    const r = await handler({ query: 12345 });
    expect(r.statusCode).toBe(200);
    expect(JSON.parse(r.body).answer).toContain("12345");
  });
});
