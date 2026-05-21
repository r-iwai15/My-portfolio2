import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, GetCommand, QueryCommand } from "@aws-sdk/lib-dynamodb";

const client = new DynamoDBClient({ region: process.env.AWS_REGION });
const dynamo = DynamoDBDocumentClient.from(client);
const TABLE_NAME = process.env.TABLE_NAME || "hotel-agile-ai-reservations";

export const handler = async (event) => {
  console.log("Received Agent Event:", JSON.stringify(event, null, 2));

  const parameters = event.parameters || [];
  const getParam = (name) => parameters.find((p) => p.name === name)?.value;
  const reservationId = getParam("reservationId");
  const guestName = getParam("guestName");
  let responseBody = {};

  try {
    if (reservationId) {
      const command = new GetCommand({ Key: { PK: `RESERVATION#${reservationId}`, SK: "META" }, TableName: TABLE_NAME });
      const result = await dynamo.send(command);
      responseBody = result.Item ? { found: true, reservation: result.Item } : { found: false, message: "Not found" };
    } else if (guestName) {
      const command = new QueryCommand({
        TableName: TABLE_NAME, IndexName: "GuestNameIndex",
        KeyConditionExpression: "guestName = :gn", ExpressionAttributeValues: { ":gn": guestName }
      });
      const result = await dynamo.send(command);
      responseBody = result.Items?.length > 0 ? { found: true, count: result.Count, reservations: result.Items } : { found: false, count: 0 };
    } else {
      responseBody = { error: "Parameters missing" };
    }
  } catch (error) {
    responseBody = { error: "DB Error" };
  }

  return {
    messageVersion: "1.0",
    response: {
      actionGroup: event.actionGroup, apiPath: event.apiPath, httpMethod: event.httpMethod,
      httpStatusCode: responseBody.error ? 500 : 200,
      responseBody: { "application/json": { body: JSON.stringify(responseBody) } }
    }
  };
};