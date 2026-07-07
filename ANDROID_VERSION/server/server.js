// BOOKWAR multiplayer server — minimal WebSocket relay (production-hardened).
// Run: node server/server.js   (or via systemd: bookwar-server.service)
// Default port: 4567 (PORT env override)
//
// Protocol: one JSON object per WebSocket message.
//   Client -> Server:
//     {"t":"hello","name":"Player1"}                 set display name
//     {"t":"pos","x":120.5,"y":340.0}                position update (broadcast to others)
//     {"t":"chat","text":"hi"}                       chat message (broadcast to ALL)
//     {"t":"letters","letters":["А","О","М"]}        inventory snapshot
//     {"t":"trade_req","to":"Player2"}               trade request
//     {"t":"trade_accept","from":"Player1"}          accept trade
//     {"t":"battle_invite","to":"Player2"}           PvP invite
//     {"t":"ping"}                                   app-level ping (returns pong)
//   Server -> Client:
//     {"t":"welcome","id":..,"name":..}
//     {"t":"player_join","id":..,"name":..,"x":..,"y":..}
//     {"t":"player_leave","id":..}
//     {"t":"player_name","id":..,"name":..}
//     {"t":"pos","id":..,"x":..,"y":..}
//     {"t":"chat","id":..,"name":..,"text":..}
//     {"t":"letters","id":..,"letters":[..]}
//     {"t":"trade_req","from":..}  {"t":"trade_accept","from":..}  {"t":"battle_invite","from":..}
//     {"t":"pong","ts":..}

'use strict';

const WebSocket = require('ws');

const PORT = parseInt(process.env.PORT || '4567', 10);
const MAX_CLIENTS = parseInt(process.env.MAX_CLIENTS || '64', 10);
const MAX_PAYLOAD = parseInt(process.env.MAX_PAYLOAD || '16384', 10); // 16 KiB
const HEARTBEAT_MS = parseInt(process.env.HEARTBEAT_MS || '30000', 10); // 30s

const wss = new WebSocket.Server({
	port: PORT,
	maxPayload: MAX_PAYLOAD,
	// Masked frames from clients are required by RFC; ws enforces. No permessage-deflate (keep RAM low).
});

const players = new Map(); // ws -> {id, name, x, y, isAlive}

function ts() {
	return new Date().toISOString();
}
function log(...a) {
	console.log(`[${ts()}]`, ...a);
}
function logErr(...a) {
	console.error(`[${ts()}]`, ...a);
}

log(`[bookwar-server] listening on ws://0.0.0.0:${PORT}  (max_clients=${MAX_CLIENTS} max_payload=${MAX_PAYLOAD} heartbeat=${HEARTBEAT_MS}ms)`);

function broadcast(ws, msg, exceptSelf) {
	const data = JSON.stringify(msg);
	for (const [client] of players) {
		if (exceptSelf && client === ws) continue;
		if (client.readyState !== WebSocket.OPEN) continue;
		client.send(data);
	}
}

function sendTo(ws, msg) {
	if (ws.readyState === WebSocket.OPEN) {
		ws.send(JSON.stringify(msg));
	}
}

function clientIp(ws) {
	try {
		return ws._socket ? ws._socket.remoteAddress : '?';
	} catch (_) {
		return '?';
	}
}

// Heartbeat: ping every client, terminate those that didn't pong since last cycle.
// Detects half-open / dead connections (e.g. closed browser tabs, dropped wifi).
const heartbeat = setInterval(() => {
	for (const [client, info] of players) {
		if (info.isAlive === false) {
			client.terminate();
			continue;
		}
		info.isAlive = false;
		try {
			client.ping();
		} catch (_) { /* ignore */ }
	}
}, HEARTBEAT_MS);
heartbeat.unref();

function genId() {
	return Date.now().toString(36) + Math.random().toString(36).slice(2, 8);
}

wss.on('connection', (ws, req) => {
	if (players.size >= MAX_CLIENTS) {
		// 1013 = Try Again Later
		ws.close(1013, 'server full');
		log(`[server] rejected connection from ${clientIp(ws)}: server full (${players.size})`);
		return;
	}

	const id = genId();
	const player = { id, name: 'Hero_' + id.slice(-4), x: 0, y: 0, isAlive: true };
	players.set(ws, player);
	ws.isAlive = true;

	ws.on('pong', () => {
		const p = players.get(ws);
		if (p) p.isAlive = true;
	});

	log(`[connect] id=${id} ip=${clientIp(ws)} total=${players.size}`);

	// Welcome + roster sync
	sendTo(ws, { t: 'welcome', id, name: player.name });
	for (const [c, p] of players) {
		if (c === ws) continue;
		sendTo(ws, { t: 'player_join', id: p.id, name: p.name, x: p.x, y: p.y });
	}
	broadcast(ws, { t: 'player_join', id, name: player.name, x: 0, y: 0 });

	ws.on('message', (raw, isBinary) => {
		if (isBinary) return; // protocol is text JSON only
		let msg;
		try {
			msg = JSON.parse(raw.toString('utf8'));
		} catch (e) {
			return; // ignore malformed
		}
		if (!msg || typeof msg !== 'object') return;
		const sender = players.get(ws);
		if (!sender) return;

		switch (msg.t) {
			case 'hello': {
				const name = String(msg.name || sender.name).slice(0, 32);
				sender.name = name;
				broadcast(ws, { t: 'player_name', id: sender.id, name });
				break;
			}
			case 'pos': {
				sender.x = Number(msg.x) || 0;
				sender.y = Number(msg.y) || 0;
				broadcast(ws, { t: 'pos', id: sender.id, x: sender.x, y: sender.y });
				break;
			}
			case 'chat': {
				const text = String(msg.text || '').slice(0, 256);
				if (!text) break;
				// Store in HTTP poll log so HTTP-fallback clients see it too
				addChatMsg(sender.id, sender.name, text);
				// broadcast to ALL including sender (sender's client echoes locally, harmless)
				broadcast(ws, { t: 'chat', id: sender.id, name: sender.name, text }, false);
				break;
			}
			case 'letters': {
				const letters = Array.isArray(msg.letters) ? msg.letters.slice(0, 33) : [];
				broadcast(ws, { t: 'letters', id: sender.id, letters });
				break;
			}
			case 'trade_req':
			case 'trade_accept':
			case 'battle_invite': {
				const key = msg.t === 'trade_accept' ? 'from' : 'to';
				const target = String(msg[key] || '');
				for (const [c, p] of players) {
					if (c === ws) continue;
					if (p.name === target) {
						sendTo(c, { t: msg.t, from: sender.name });
						break;
					}
				}
				break;
			}
			case 'ping':
				sendTo(ws, { t: 'pong', ts: Date.now() });
				break;
			default:
				// unknown message type — ignore
				break;
		}
	});

	const cleanup = () => {
		const p = players.get(ws);
		if (p) {
			log(`[disconnect] id=${p.id} total=${Math.max(0, players.size - 1)}`);
			broadcast(ws, { t: 'player_leave', id: p.id });
		}
		players.delete(ws);
	};
	ws.on('close', cleanup);
	ws.on('error', (e) => {
		logErr('[ws error]', id, e.message);
		cleanup();
	});
});

wss.on('error', (e) => logErr('[server error]', e.message));

// Graceful shutdown
function shutdown(sig) {
	log(`[server] ${sig} received, shutting down`);
	clearInterval(heartbeat);
	for (const [c] of players) {
		try { c.close(1001, 'server shutdown'); } catch (_) { /* */ }
	}
	wss.close(() => process.exit(0));
	setTimeout(() => process.exit(0), 2000).unref();
}
process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('uncaughtException', (e) => logErr('[uncaughtException]', e.stack || e.message));
process.on('unhandledRejection', (r) => logErr('[unhandledRejection]', r));

// === HTTP fallback for chat (БАГ-008 workaround) ===
// Godot 4.6 HTML5 WebSocketPeer silently drops outgoing messages. HTTP polling
// is 100% reliable — we use it as a backup channel for chat send/receive.
const http = require('http');
const httpPort = parseInt(process.env.HTTP_PORT || '4568', 10);
const chatLog = []; // [{ts, id, name, text}, ...] — last 200 messages
const MAX_CHAT_LOG = 200;

function addChatMsg(id, name, text) {
	const entry = { ts: Date.now(), id: id, name: name, text: text };
	chatLog.push(entry);
	if (chatLog.length > MAX_CHAT_LOG) chatLog.shift();
	return entry;
}

// Intercept WebSocket 'chat' to also store in HTTP log (for pollers)
const _origHandleMessage = null; // We'll hook via wrapper below

const httpServer = http.createServer((req, res) => {
	res.setHeader('Access-Control-Allow-Origin', '*');
	res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
	res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
	if (req.method === 'OPTIONS') { res.writeHead(204); res.end(); return; }

	const url = new URL(req.url, 'http://localhost');

	if (url.pathname === '/api/chat/poll' && req.method === 'GET') {
		const since = parseInt(url.searchParams.get('since') || '0', 10);
		const msgs = chatLog.filter(m => m.ts > since);
		res.writeHead(200, { 'Content-Type': 'application/json' });
		res.end(JSON.stringify(msgs));
		return;
	}

	if (url.pathname === '/api/chat/send' && req.method === 'POST') {
		let body = '';
		req.on('data', chunk => { body += chunk; if (body.length > 4096) req.destroy(); });
		req.on('end', () => {
			try {
				const data = JSON.parse(body);
				const name = String(data.name || 'Anon').slice(0, 32);
				const text = String(data.text || '').slice(0, 256);
				if (text.length > 0) {
					const id = 'http_' + Date.now().toString(36) + Math.random().toString(36).slice(2, 6);
					addChatMsg(id, name, text);
					// Also broadcast to WebSocket clients
					const msg = { t: 'chat', id: id, name: name, text: text };
					for (const [client] of players) {
						if (client.readyState === WebSocket.OPEN) {
							client.send(JSON.stringify(msg));
						}
					}
				}
				res.writeHead(200, { 'Content-Type': 'application/json' });
				res.end('{"ok":true}');
			} catch(e) {
				res.writeHead(400); res.end('{"error":"bad json"}');
			}
		});
		return;
	}

	res.writeHead(404); res.end('{"error":"not found"}');
});
httpServer.listen(httpPort, () => log(`[http] listening on :${httpPort} for /api/chat/*`));
