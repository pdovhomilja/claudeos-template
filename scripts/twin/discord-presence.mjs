// Keeps the assistant's bot "online" in Discord: one gateway connection, heartbeat only, no events read
// (replies come from scripts/twin/discord-watch.sh). Systemd user service claudeos-discord-presence restarts it on exit.
import { readFileSync } from "node:fs";

const env = Object.fromEntries(readFileSync(new URL("../../.env", import.meta.url), "utf8")
  .split("\n").map(l => l.match(/^([A-Za-z_]\w*)=(.*)$/)).filter(Boolean)
  .map(m => [m[1], m[2].trim().replace(/^["']|["']$/g, "")]));

const ws = new WebSocket("wss://gateway.discord.gg/?v=10&encoding=json");
let seq = null;

ws.onmessage = ({ data }) => {
  const { op, d, s } = JSON.parse(data);
  if (s) seq = s;
  if (op === 10) {  // hello: heartbeat, then identify with the presence
    setInterval(() => ws.send(JSON.stringify({ op: 1, d: seq })), d.heartbeat_interval);
    ws.send(JSON.stringify({ op: 2, d: {
      token: env.DISCORD_BOT_TOKEN, intents: 0,
      properties: { os: "linux", browser: "claudeos", device: "claudeos" },
      presence: { status: "online", afk: false, activities: [] },
    } }));
  }
  if (op === 1) ws.send(JSON.stringify({ op: 1, d: seq }));
  if (op === 7 || op === 9) ws.close();  // reconnect / invalid session: systemd starts a fresh one
};
ws.onclose = (e) => { console.error(new Date().toISOString(), "gateway closed", e.code, e.reason); process.exit(1); };
