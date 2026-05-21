/** 決定論的料金（packages/pricing-engine と同一ロジック） */
const RATES_JPY_PER_NIGHT = {
  SINGLE: 12_000,
  SUITE: 28_000,
  OCEAN_VIEW: 35_000,
  STANDARD: 10_000,
};

export function nightsBetween(checkIn, checkOut) {
  const start = new Date(`${checkIn}T00:00:00Z`);
  const end = new Date(`${checkOut}T00:00:00Z`);
  const nights = Math.round((end - start) / 86_400_000);
  return nights > 0 ? nights : 0;
}

export function calculateStayPrice(roomType, nights) {
  const key = String(roomType ?? "STANDARD").toUpperCase().replace(/\s+/g, "_");
  const rate = RATES_JPY_PER_NIGHT[key] ?? RATES_JPY_PER_NIGHT.STANDARD;
  return rate * nights;
}
