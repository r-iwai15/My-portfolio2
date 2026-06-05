/**
 * Type-A: Reservation Execution Lambda (Black 手前 — 決定論的実行)
 */

import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import {
  DynamoDBDocumentClient,
  GetCommand,
  PutCommand,
  UpdateCommand,
  TransactWriteCommand,
} from "@aws-sdk/lib-dynamodb";
import { parametersToIntent, validateIntent } from "./validate.js";
import { calculateStayPrice, nightsBetween } from "./pricing.js";

const dynamo = DynamoDBDocumentClient.from(new DynamoDBClient({ region: process.env.AWS_REGION }));
const TABLE_NAME = process.env.TABLE_NAME ?? "hotel-agile-ai-reservations";

const getParam = (parameters, name) => parameters.find((p) => p.name === name)?.value;

function agentResponse(event, body) {
  return {
    messageVersion: "1.0",
    response: {
      actionGroup: event.actionGroup,
      apiPath: event.apiPath,
      httpMethod: event.httpMethod,
      httpStatusCode: body.error ? 400 : 200,
      responseBody: { "application/json": { body: JSON.stringify(body) } },
    },
  };
}

async function findIdempotentReservation(idempotencyKey) {
  const result = await dynamo.send(
    new GetCommand({
      TableName: TABLE_NAME,
      Key: { PK: `IDEMPOTENCY#${idempotencyKey}`, SK: "META" },
    })
  );
  return result.Item?.reservationId ?? null;
}

async function createReservation(event, intent) {
  const { guestName, checkIn, checkOut, roomType, idempotencyKey } = intent;

  if (idempotencyKey) {
    const existing = await findIdempotentReservation(idempotencyKey);
    if (existing) {
      return agentResponse(event, { success: true, reservationId: existing, deduplicated: true });
    }
  }

  const nights = nightsBetween(checkIn, checkOut);
  if (nights < 1) {
    return agentResponse(event, { error: "checkOut must be after checkIn" });
  }

  const totalPriceJpy = calculateStayPrice(roomType, nights);
  const reservationId = `RES-${Math.random().toString(36).substring(2, 8).toUpperCase()}`;
  const now = new Date().toISOString();
  const reservationItem = {
    PK: `RESERVATION#${reservationId}`,
    SK: "META",
    reservationId,
    guestName,
    checkIn,
    checkOut,
    roomType,
    nights,
    totalPriceJpy,
    status: "CONFIRMED",
    createdAt: now,
  };

  try {
    if (idempotencyKey) {
      // 予約本体とべき等性レコードを単一トランザクションで原子的に書き込む。
      // 片方だけ書き込まれる（= 予約が無いのにべき等キーだけ残る）状態を防ぐ。
      await dynamo.send(
        new TransactWriteCommand({
          TransactItems: [
            {
              Put: {
                TableName: TABLE_NAME,
                Item: { PK: `IDEMPOTENCY#${idempotencyKey}`, SK: "META", reservationId, createdAt: now },
                ConditionExpression: "attribute_not_exists(PK)",
              },
            },
            {
              Put: { TableName: TABLE_NAME, Item: reservationItem },
            },
          ],
        })
      );
    } else {
      await dynamo.send(new PutCommand({ TableName: TABLE_NAME, Item: reservationItem }));
    }
  } catch (err) {
    // 同一 idempotencyKey の競合（トランザクション条件失敗）→ 既存予約を返す
    if (
      (err.name === "TransactionCanceledException" || err.name === "ConditionalCheckFailedException") &&
      idempotencyKey
    ) {
      const existing = await findIdempotentReservation(idempotencyKey);
      if (existing) {
        return agentResponse(event, { success: true, reservationId: existing, deduplicated: true });
      }
    }
    throw err;
  }

  return agentResponse(event, { success: true, reservationId, totalPriceJpy, nights });
}

async function updateReservation(event, intent) {
  const { reservationId, checkIn, checkOut, roomType } = intent;

  const updates = {
    ...(checkIn && { checkIn }),
    ...(checkOut && { checkOut }),
    ...(roomType && { roomType }),
  };
  if (Object.keys(updates).length === 0) {
    return agentResponse(event, { error: "No fields to update" });
  }

  const expressions = Object.keys(updates).map((k) => `#${k} = :${k}`);
  const attrNames = Object.fromEntries(Object.keys(updates).map((k) => [`#${k}`, k]));
  const attrValues = Object.fromEntries(Object.keys(updates).map((k) => [`:${k}`, updates[k]]));

  try {
    await dynamo.send(
      new UpdateCommand({
        TableName: TABLE_NAME,
        Key: { PK: `RESERVATION#${reservationId}`, SK: "META" },
        UpdateExpression: `SET ${expressions.join(", ")}`,
        ExpressionAttributeNames: attrNames,
        ExpressionAttributeValues: attrValues,
        ConditionExpression: "attribute_exists(PK)",
      })
    );
    return agentResponse(event, { success: true, reservationId });
  } catch (err) {
    if (err.name === "ConditionalCheckFailedException") {
      return agentResponse(event, { error: `予約ID ${reservationId} が見つかりません。` });
    }
    throw err;
  }
}

async function cancelReservation(event, intent) {
  const { reservationId } = intent;

  try {
    await dynamo.send(
      new UpdateCommand({
        TableName: TABLE_NAME,
        Key: { PK: `RESERVATION#${reservationId}`, SK: "META" },
        UpdateExpression: "SET #status = :cancelled, #cancelledAt = :now",
        ExpressionAttributeNames: { "#status": "status", "#cancelledAt": "cancelledAt" },
        ExpressionAttributeValues: { ":cancelled": "CANCELLED", ":now": new Date().toISOString() },
        ConditionExpression: "attribute_exists(PK)",
      })
    );
    return agentResponse(event, { success: true, reservationId });
  } catch (err) {
    if (err.name === "ConditionalCheckFailedException") {
      return agentResponse(event, { error: `予約ID ${reservationId} が見つかりません。` });
    }
    throw err;
  }
}

export const handler = async (event) => {
  if (!event.actionGroup) {
    return { statusCode: 400, body: JSON.stringify({ error: "Bedrock Agent action group invocation only." }) };
  }

  const intent = parametersToIntent(event.parameters ?? []);
  const validation = validateIntent(intent);
  if (!validation.ok) {
    return agentResponse(event, {
      error: "Validation failed",
      details: validation.errors.map((e) => e.message ?? JSON.stringify(e)),
    });
  }

  const { action } = intent;
  console.log("Reservation execution:", JSON.stringify({ action, actionGroup: event.actionGroup }));

  try {
    if (action === "create") return await createReservation(event, intent);
    if (action === "update") return await updateReservation(event, intent);
    if (action === "cancel") return await cancelReservation(event, intent);
  } catch (err) {
    console.error("Reservation execution error:", err);
    return agentResponse(event, { error: "予約処理中にエラーが発生しました。" });
  }

  return agentResponse(event, { error: `Unhandled action: ${action}` });
};
