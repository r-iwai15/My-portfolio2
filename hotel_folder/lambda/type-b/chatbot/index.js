/**
 * Type-B: Hotel Chatbot Lambda
 *
 * VPC内のvLLMサーバー（Qwen2.5-7B）をOpenAI互換APIで呼び出し、
 * チャット応答を返す。
 * 会話ログをCloudWatch Logsに出力し、Sentinelのサブスクリプション
 * フィルターによるプロンプトインジェクション監視を可能にする。
 *
 * Env:
 *   LLM_ENDPOINT       - vLLMサーバーのエンドポイント (例: http://10.0.41.x:8000/v1)
 *   LLM_MODEL_ID       - モデル名 (例: Qwen/Qwen2.5-7B-Instruct)
 *   CHATBOT_LOG_BUCKET - 会話ログ保存先S3バケット名
 *   SYSTEM_PROMPT      - システムプロンプト
 */

import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";

const s3 = new S3Client({ region: process.env.AWS_REGION });

const LLM_ENDPOINT  = process.env.LLM_ENDPOINT;
const LLM_MODEL_ID  = process.env.LLM_MODEL_ID;
const LOG_BUCKET    = process.env.CHATBOT_LOG_BUCKET;
const SYSTEM_PROMPT = process.env.SYSTEM_PROMPT ?? "あなたはホテルの予約アシスタントです。丁寧な日本語でお答えください。";

export const handler = async (event) => {
  const body     = JSON.parse(event.body ?? "{}");
  const message  = body.message;
  const userId   = event.requestContext?.authorizer?.claims?.sub ?? "anonymous";
  const sourceIp = event.requestContext?.identity?.sourceIp ?? "unknown";

  if (!message) {
    return { statusCode: 400, body: JSON.stringify({ error: "Message is required." }) };
  }

  // vLLM (OpenAI互換API) を呼び出す
  let aiText;
  try {
    const res = await fetch(`${LLM_ENDPOINT}/chat/completions`, {
      method:  "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        model:    LLM_MODEL_ID,
        messages: [
          { role: "system",  content: SYSTEM_PROMPT },
          { role: "user",    content: message },
        ],
        max_tokens:  512,
        temperature: 0.7,
      }),
    });

    if (!res.ok) {
      throw new Error(`vLLM error: ${res.status} ${await res.text()}`);
    }

    const data = await res.json();
    aiText = data.choices[0].message.content;
  } catch (err) {
    console.error("LLM call failed:", err);
    return {
      statusCode: 502,
      body: JSON.stringify({ error: "AIサービスに一時的な問題が発生しました。しばらくお待ちください。" }),
    };
  }

  // CloudWatch Logsに出力（Sentinelのサブスクリプションフィルターの監視対象）
  const logEntry = JSON.stringify({ sourceIp, userId, userMessage: message, assistantMessage: aiText });
  console.log(logEntry);

  // S3に長期保存
  const key = `logs/${new Date().toISOString().slice(0, 10)}/${userId}/${Date.now()}.json`;
  await s3.send(new PutObjectCommand({
    Bucket: LOG_BUCKET, Key: key, Body: logEntry, ContentType: "application/json",
  })).catch((err) => console.error("S3 log write failed (non-fatal):", err));

  return {
    statusCode: 200,
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ reply: aiText }),
  };
};
