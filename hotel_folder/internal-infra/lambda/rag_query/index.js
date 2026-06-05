/**
 * Type-A internal RAG query stub.
 * In production: call Bedrock Knowledge Base RetrieveAndGenerate or Agents.
 */
function parseBodyQuery(body) {
  if (typeof body !== "string") return "";
  try {
    return JSON.parse(body || "{}").query || "";
  } catch {
    return "";
  }
}

export async function handler(event) {
  const raw = event?.query || event?.body?.query || parseBodyQuery(event?.body) || "";
  const q = typeof raw === "string" ? raw : String(raw);

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
