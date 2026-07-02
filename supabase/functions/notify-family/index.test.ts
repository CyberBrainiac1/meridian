import { buildSendResult } from "./index.ts";

function assertEquals(actual: unknown, expected: unknown, msg?: string) {
  if (actual !== expected) {
    throw new Error(msg ?? `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
  }
}

Deno.test("buildSendResult marks a pending notification sent with a timestamp", () => {
  const result = buildSendResult({
    id: "11111111-1111-1111-1111-111111111111",
    facility_id: "fac-poc-001",
    resident_id: "res-1",
    incident_id: "inc-1",
    channel: "sms",
    body: "Staff resolved the alert for your family member.",
  });

  assertEquals(result.id, "11111111-1111-1111-1111-111111111111");
  assertEquals(result.status, "sent");
  assertEquals(typeof result.sent_at, "string");
  assertEquals(Number.isNaN(Date.parse(result.sent_at)), false);
});

Deno.test("buildSendResult logs the channel and body for the stub provider", () => {
  const logs: string[] = [];
  const originalLog = console.log;
  console.log = (msg: string) => logs.push(msg);
  try {
    buildSendResult({
      id: "22222222-2222-2222-2222-222222222222",
      facility_id: "fac-poc-001",
      resident_id: "res-2",
      incident_id: "inc-2",
      channel: "sms",
      body: "Staff is responding to an alert for your family member.",
    });
  } finally {
    console.log = originalLog;
  }
  assertEquals(logs.length, 1);
  assertEquals(logs[0].includes("res-2"), true);
});
