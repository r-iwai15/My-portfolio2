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
});
