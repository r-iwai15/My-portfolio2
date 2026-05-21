import { SESClient, SendEmailCommand } from "@aws-sdk/client-ses";

const ses = new SESClient();
const FROM_EMAIL = process.env.FROM_EMAIL;

export const handler = async (event) => {
  for (const record of event.Records) {
    const payload = JSON.parse(record.body);
    const email = payload.email || payload.guestEmail;
    if (!email) continue;

    const params = {
      Source: FROM_EMAIL,
      Destination: { ToAddresses: [email] },
      Message: {
        Subject: { Data: `予約完了のお知らせ` },
        Body: { Text: { Data: `ご予約ありがとうございました。` } }
      }
    };
    await ses.send(new SendEmailCommand(params));
  }
  return { statusCode: 200, body: 'Success' };
};