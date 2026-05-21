/**
 * Type-A internal RAG query stub.
 * In production: call Bedrock Knowledge Base RetrieveAndGenerate or Agents.
 */
export async function handler(event) {
  const q =
    event?.query ||
    event?.body?.query ||
    (typeof event?.body === "string" ? JSON.parse(event.body || "{}").query : "") ||
    "";

  if (!q.trim()) {
    return {
      statusCode: 400,
      body: JSON.stringify({ error: "query is required" }),
    };
  }

  return {
    statusCode: 200,
    body: JSON.stringify({
      answer: `[stub] Processed query: ${q.slice(0, 200)}`,
      source: "knowledge-base-placeholder",
    }),
  };
}
