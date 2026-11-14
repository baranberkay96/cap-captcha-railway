// Waits until Valkey answers PING, then seeds Cap's client-IP header setting
// once (Settings > Visitor location), so rate limits see the visitor's IP
// instead of Railway's edge. Exit 0 when Valkey answered, 1 otherwise.
import { RedisClient } from "bun";

const log = (msg) => console.error(`[railway-start] ${msg}`);

const url = process.env.VALKEY_URL || process.env.REDIS_URL || "redis://localhost:6379";
const shownUrl = url.replace(/\/\/[^@/]*@/, "//");
const prefix = process.env.REDIS_PREFIX || "";
const waitSeconds = (() => {
  const n = Math.trunc(Number(process.env.CAP_VALKEY_WAIT_SECONDS));
  return Number.isFinite(n) && n >= 0 && n <= 3600 ? n : 240;
})();
const header = (process.env.CAP_CLIENT_IP_HEADER ?? "x-forwarded-for").trim().toLowerCase();

async function seedHeader(client) {
  if (!header) return;
  if (!/^[a-z0-9-]{1,64}$/.test(header)) {
    log(`CAP_CLIENT_IP_HEADER='${header}' is not a header name; leaving the setting alone.`);
    return;
  }
  const value = JSON.stringify({ ipHeader: header, countryHeader: "", asnHeader: "" });
  const reply = await client.send("SET", [`${prefix}settings:headers`, value, "NX"]);
  if (reply === "OK") log(`Client IP header set to ${header} (change it in Instance settings > Visitor location).`);
}

async function main() {
  const deadline = Date.now() + waitSeconds * 1000;
  let lastLog = 0;
  for (;;) {
    let client;
    try {
      client = new RedisClient(url, { connectionTimeout: 3000, autoReconnect: false });
      const pong = await client.send("PING", []);
      if (pong !== "PONG") throw new Error(`unexpected PING reply ${pong}`);
      try {
        await seedHeader(client);
      } catch (e) {
        log(`Could not seed the client IP header setting: ${e.message}`);
      }
      log(`Valkey at ${shownUrl} is ready.`);
      return 0;
    } catch (e) {
      const msg = String(e?.message ?? e);
      if (Date.now() - lastLog > 15_000) {
        lastLog = Date.now();
        if (/WRONGPASS|NOAUTH|invalid username-password|AUTH/i.test(msg)) {
          log(`Valkey rejected the password in VALKEY_URL. Make VALKEY_URL use the Valkey service's VALKEY_PASSWORD (${msg}).`);
        } else {
          log(`Waiting for Valkey at ${shownUrl} (${msg})`);
        }
      }
      if (Date.now() >= deadline) {
        log(`Valkey did not answer within ${waitSeconds} s.`);
        return 1;
      }
      await Bun.sleep(2000);
    } finally {
      try {
        client?.close();
      } catch {}
    }
  }
}

process.exit(await main());
