import Ajv from "ajv";
import addFormats from "ajv-formats";
import schema from "./intent.schema.json" with { type: "json" };

const ajv = addFormats(new Ajv({ allErrors: true }));
const validateIntentSchema = ajv.compile(schema);

export function parametersToIntent(parameters) {
  const intent = {};
  for (const { name, value } of parameters ?? []) {
    if (value !== undefined && value !== null && value !== "") {
      intent[name] = value;
    }
  }
  return intent;
}

export function validateIntent(intent) {
  if (!validateIntentSchema(intent)) {
    return { ok: false, errors: validateIntentSchema.errors ?? [] };
  }
  if (intent.action === "create") {
    const required = ["guestName", "checkIn", "checkOut", "roomType"];
    const missing = required.filter((k) => !intent[k]);
    if (missing.length) {
      return { ok: false, errors: [{ message: `Missing: ${missing.join(", ")}` }] };
    }
  }
  if (intent.action === "update" && !intent.reservationId) {
    return { ok: false, errors: [{ message: "reservationId is required for update" }] };
  }
  if (intent.action === "cancel" && !intent.reservationId) {
    return { ok: false, errors: [{ message: "reservationId is required for cancel" }] };
  }
  return { ok: true };
}
