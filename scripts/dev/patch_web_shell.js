// Post-build patcher: replace the default Godot HTML5 shell with a branded, informative
// loading screen so users never see a "black screen" during the ~112MB download.
// Reads the Godot-generated builds/html5/index.html, extracts GODOT_CONFIG + threads flag,
// and writes a custom shell with: BOOKWAR title, % progress, and a stall watchdog.
//
// Usage: node scripts/dev/patch_web_shell.js [path/to/index.html]
'use strict';
const fs = require('fs');
const path = require('path');

const file = process.argv[2] || path.join(__dirname, '..', '..', 'builds', 'html5', 'index.html');
if (!fs.existsSync(file)) {
	console.error('[shell] index.html not found:', file);
	process.exit(1);
}
const html = fs.readFileSync(file, 'utf8');

// Extract build-specific values injected by Godot.
const cfgMatch = html.match(/const GODOT_CONFIG = (\{[\s\S]*?\});/);
const threadsMatch = html.match(/const GODOT_THREADS_ENABLED = (true|false);/);
if (!cfgMatch || !threadsMatch) {
	console.error('[shell] Could not extract GODOT_CONFIG / THREADS from generated shell.');
	process.exit(1);
}
const GODOT_CONFIG = cfgMatch[1];
const THREADS = threadsMatch[1];
console.log('[shell] extracted config (fileSizes present:', GODOT_CONFIG.includes('fileSizes'), ') threads=' + THREADS);

const shell = `<!DOCTYPE html>
<html lang="ru">
	<head>
		<meta charset="utf-8">
		<meta name="viewport" content="width=device-width, user-scalable=no, initial-scale=1.0">
		<title>BOOKWAR</title>
		<style>
html, body, #canvas { margin: 0; padding: 0; border: 0; }
body { color: #fff; background-color: #120608; overflow: hidden; touch-action: none; font-family: 'Segoe UI', Tahoma, Arial, sans-serif; }
#canvas { display: block; }
#canvas:focus { outline: none; }
#status { position: absolute; left: 0; right: 0; top: 0; bottom: 0; z-index: 10;
	background: radial-gradient(circle at 50% 32%, #3a1018 0%, #170709 72%);
	display: flex; flex-direction: column; justify-content: center; align-items: center;
	visibility: hidden; text-align: center; }
#bw-title { font-size: clamp(40px, 8vw, 76px); font-weight: 800; letter-spacing: 6px;
	color: #e8c46a; text-shadow: 0 0 22px rgba(232,196,106,.45); margin: 0; }
#bw-sub { color: #c98a9a; letter-spacing: 4px; margin: 6px 0 30px; font-size: clamp(13px, 2.4vw, 20px); }
#status-progress { width: min(50vw, 460px); height: 16px; -webkit-appearance: none; appearance: none;
	border: 1px solid #5a3030; border-radius: 9px; overflow: hidden; background: #2a1216; }
#status-progress::-webkit-progress-bar { background: #2a1216; }
#status-progress::-webkit-progress-value { background: linear-gradient(90deg, #b8860b, #e8c46a); transition: width .2s; }
#status-progress::-moz-progress-bar { background: linear-gradient(90deg, #b8860b, #e8c46a); }
#bw-pct { color: #e8c46a; font-size: 19px; margin-top: 16px; min-height: 24px; letter-spacing: 1px; }
#status-notice { display: none; background: #3a0a14; border: 1px solid #9b3943; color: #ffe9d0;
	border-radius: 10px; padding: 16px 20px; max-width: min(80vw, 560px); margin-top: 20px;
	line-height: 1.45; white-space: pre-line; }
#bw-hint { color: #8a6a6a; font-size: 13px; margin-top: 26px; }
/* Rotation overlay: shown in portrait only — bookwar is a landscape game.
   Implemented in pure CSS so it works even before JS / canvas boots. */
#rotate-overlay { display: none; position: fixed; inset: 0; z-index: 100;
	background: radial-gradient(circle at 50% 40%, #2a0e14 0%, #0a0306 80%);
	flex-direction: column; align-items: center; justify-content: center; text-align: center;
	gap: 22px; padding: 40px; box-sizing: border-box; }
#rotate-overlay .icon { font-size: 84px; animation: rotate-hint 1.8s ease-in-out infinite; }
@keyframes rotate-hint { 0%,100% { transform: rotate(0deg); } 50% { transform: rotate(-90deg); } }
#rotate-overlay h2 { font-size: clamp(22px, 6vw, 36px); color: #e8c46a; margin: 0; letter-spacing: 1px; }
#rotate-overlay p { font-size: clamp(13px, 3.6vw, 18px); color: #c98a9a; max-width: 460px; margin: 0; line-height: 1.45; }
@media (orientation: portrait) {
	#rotate-overlay { display: flex; }
	#canvas, #status { display: none !important; }
}
		</style>
		<link id="-gd-engine-icon" rel="icon" type="image/png" href="index.icon.png" />
		<link rel="apple-touch-icon" href="index.apple-touch-icon.png" />
		<style>
#sound-toggle { position: fixed; top: 8px; left: 8px; z-index: 200; width: 44px; height: 44px;
	border: none; border-radius: 50%; background: rgba(40, 18, 22, 0.85); color: #e8c46a;
	font-size: 22px; cursor: pointer; opacity: 0.85; }
#sound-toggle:hover { opacity: 1; }
#gyro-toggle { position: fixed; top: 8px; right: 8px; z-index: 200; height: 44px; padding: 0 14px;
	border: none; border-radius: 22px; background: rgba(40, 18, 22, 0.85); color: #e8c46a;
	font-size: 16px; cursor: pointer; opacity: 0.85; display: none; font-family: inherit; }
#gyro-toggle:hover { opacity: 1; }
#gyro-toggle.active { background: rgba(70, 130, 60, 0.9); color: #fff; }
		</style>
	</head>
	<body>
	<div id="rotate-overlay">
		<div class="icon">📱</div>
		<h2>Поверните устройство</h2>
		<p>BOOKWAR — горизонтальная игра. Поверните телефон горизонтально, чтобы продолжить.</p>
	</div>
	<button id="sound-toggle" title="Звук">🔊</button>
	<button id="gyro-toggle" title="Управление наклоном">📡 Наклон</button>
	<canvas id="canvas">Ваш браузер не поддерживает canvas.</canvas>
	<noscript>Для запуска BOOKWAR необходим JavaScript.</noscript>
	<div id="status">
		<h1 id="bw-title">BOOKWAR</h1>
		<div id="bw-sub">ВОЙНА ЗА АЛФАВИТ</div>
		<progress id="status-progress"></progress>
		<div id="bw-pct">ЗАГРУЗКА…</div>
		<div id="status-notice"></div>
		<div id="bw-hint">Игра весит ~112 МБ. Подождите окончания загрузки.</div>
	</div>
	<script>
// Ensure the canvas keeps keyboard/touch focus — Godot HTML5 loses it after
// reloads and on some mobile browsers, which breaks InputEvent delivery.
// Also unlock the Web Audio context on first user gesture (HTML5 browsers
// suspend audio until a touch/click happens — without this, music stays silent).
(function(){
	var c = document.getElementById('canvas');
	if (!c) return;
	c.setAttribute('tabindex', '0');
	function refocus() { try { c.focus(); } catch(e) {} }
	function unlockAudio() {
		try {
			var ac = (window.engine && window.engine.audioContext)
			      || (window.Engine && Engine.audioContext);
			if (ac && ac.state === 'suspended') ac.resume();
		} catch(e) {}
		// Also retry the HTML5 streaming <audio> that Music.gd creates —
		// browsers block autoplay until first user gesture.
		try {
			if (window._bookwarMusic && window._bookwarMusic.paused && window._bookwarMusic.src) {
				var p = window._bookwarMusic.play();
				if (p && p.catch) p.catch(function(){});
			}
		} catch(e) {}
	}
	document.addEventListener('touchstart', function(e){ refocus(); unlockAudio(); }, { passive: true });
	document.addEventListener('mousedown', function(e){ refocus(); unlockAudio(); });
	document.addEventListener('keydown', function(e){ refocus(); unlockAudio(); }, { passive: true });
	window.addEventListener('load', refocus);
	// Sound toggle button — ALWAYS visible (so the user can mute OR unmute).
	// Icon flips between 🔊 (playing) and 🔇 (muted). Clicking never hides it.
	window.addEventListener('load', function() {
		var btn = document.getElementById('sound-toggle');
		if (!btn) return;
		btn.style.display = 'block';
		function refresh() {
			try {
				var playing = window._bookwarMusic && !window._bookwarMusic.paused;
				btn.textContent = playing ? '🔊' : '🔇';
				btn.title = playing ? 'Выключить звук' : 'Включить звук';
			} catch(e) {}
		}
		setInterval(refresh, 1000);
		refresh();
		btn.addEventListener('click', function() {
			try {
				if (window._bookwarMusic) {
					if (window._bookwarMusic.paused) {
						var p = window._bookwarMusic.play();
						if (p && p.catch) p.catch(function(e){ alert('Не удалось включить звук: ' + e.message); });
					} else {
						window._bookwarMusic.pause();
					}
				}
			} catch(e) {}
			setTimeout(refresh, 100);
		});
	});

	// === Gyroscope (deviceorientation) -> bridge for Godot player movement ===
	// Browsers expose tilt via the deviceorientation event: beta = front/back, gamma = left/right.
	// We rotate raw beta/gamma into (x=right, y=down) based on screen.orientation.angle so
	// the same player.gd code works in portrait AND landscape. iOS 13+ requires explicit
	// permission via requestPermission().
	(function(){
		window.gameGyro = null;
		window.gameGyroEnabled = false;
		function onOrientation(e) {
			var angle = (screen.orientation && typeof screen.orientation.angle === 'number') ? screen.orientation.angle : (window.orientation || 0);
			var beta = e.beta || 0;
			var gamma = e.gamma || 0;
			var x = 0, y = 0;
			// Convert raw device tilt into screen-space direction (x=right, y=down).
			// This is what player.gd adds to direction.x/y.
			angle = ((angle % 360) + 360) % 360;
			if (angle === 0) { x = gamma; y = beta; }
			else if (angle === 90) { x = beta; y = -gamma; }
			else if (angle === 180) { x = -gamma; y = -beta; }
			else if (angle === 270) { x = -beta; y = gamma; }
			window.gameGyro = { x: x, y: y, beta: beta, gamma: gamma, angle: angle, ts: Date.now() };
		}
		function showToggle() {
			var gb = document.getElementById('gyro-toggle');
			if (gb) gb.style.display = 'block';
		}
		function requestGyroPermission() {
			try {
				if (typeof DeviceOrientationEvent !== 'undefined' &&
					typeof DeviceOrientationEvent.requestPermission === 'function') {
					DeviceOrientationEvent.requestPermission().then(function(state) {
						if (state === 'granted') {
							window.addEventListener('deviceorientation', onOrientation);
							window.gameGyroAvailable = true;
							showToggle();
						}
					}).catch(function(e){ console.warn('gyro permission denied:', e); });
				} else {
					// Android / desktop Chrome — no permission needed.
					window.addEventListener('deviceorientation', onOrientation);
					window.gameGyroAvailable = true;
					// On devices without sensors (desktop), deviceorientation never fires.
					// Show toggle only if we actually receive an event.
					var firstEvtTimer = setTimeout(function() {
						if (!window.gameGyro) showToggle();  // give user a chance to try anyway
					}, 2500);
					window.addEventListener('deviceorientation', function once() {
						clearTimeout(firstEvtTimer);
						showToggle();
						window.removeEventListener('deviceorientation', once);
					}, { once: true });
				}
			} catch(e) { console.warn('gyro setup failed:', e); }
		}
		function tryEnable() { requestGyroPermission(); }
		document.addEventListener('touchstart', tryEnable, { once: true, passive: true });
		document.addEventListener('mousedown', tryEnable, { once: true });
		window.addEventListener('load', function() {
			var gb = document.getElementById('gyro-toggle');
			if (!gb) return;
			gb.addEventListener('click', function() {
				// (Re-)request permission on every click — iOS requires a user gesture
				// for requestPermission() and the first touchstart might have been
				// consumed elsewhere (e.g. canvas focus).
				requestGyroPermission();
				window.gameGyroEnabled = !window.gameGyroEnabled;
				gb.classList.toggle('active', window.gameGyroEnabled);
				gb.textContent = window.gameGyroEnabled ? '📡 Наклон: ВКЛ' : '📡 Наклон';
				// Debug beacon so the user / Puppeteer can see the gyro state.
				window.gameGyroStatus = {
					enabled: window.gameGyroEnabled,
					available: !!window.gameGyroAvailable,
					hasReading: !!window.gameGyro,
					lastReading: window.gameGyro || null
				};
				console.log('[gyro-toggle] clicked →', JSON.stringify(window.gameGyroStatus));
			});
		});
	})();

	// === Music preload + audio element bootstrap ===
	// Create the shared <audio> element early and call load() so the first track is
	// preloaded by the time Music.gd calls _bookwarMusic.play(). Without this, the
	// browser starts fetching the mp3 only on play() and music is delayed by several
	// seconds (reported as "music starts only on slide 3 of the legend").
	window.addEventListener('load', function() {
		if (!window._bookwarMusic) {
			try {
				window._bookwarMusic = document.createElement('audio');
				window._bookwarMusic.preload = 'auto';
				window._bookwarMusic.loop = false;
				window._bookwarMusic.style.display = 'none';
				document.body.appendChild(window._bookwarMusic);
				window._bookwarMusic.addEventListener('ended', function() {
					window._bookwarMusicEnded = true;
				});
			} catch(e) { console.warn('audio bootstrap failed:', e); }
		}
	});

	// === Multiplayer WebSocket bridge ===
	// Godot 4.6 HTML5 WebSocketPeer silently drops outgoing messages in some
	// conditions (БАГ-008 in errors.md). Workaround: do all MP I/O through a
	// plain JS WebSocket that Godot controls via polling-based bridge.
	//
	// Godot side (NetworkManager):
	//   • sets window._mpWantConnect = 'url'  -> requests a connect
	//   • pushes into window._mpOut (array of strings) -> outgoing messages
	//   • reads window._mpIn (array of strings) -> incoming messages
	//   • reads window._mpState -> 'idle'|'connecting'|'open'|'closed'
	// JS side (this setInterval loop):
	//   • honors _mpWantConnect, opens WebSocket
	//   • drains _mpOut and sends each
	//   • on WS message, pushes into _mpIn
	window._mpState = 'idle';
	window._mpIn = [];
	window._mpOut = [];
	window._mpWantConnect = null;
	window._mpWantDisconnect = false;
	window._mpSocket = null;
	window._mpLastError = '';
	function mpOpenSocket(url) {
		try {
			if (window._mpSocket) {
				try { window._mpSocket.close(); } catch(e){}
				window._mpSocket = null;
			}
			window._mpState = 'connecting';
			window._mpLastError = '';
			var s = new WebSocket(url);
			window._mpSocket = s;
		s.binaryType = 'arraybuffer';
		s.addEventListener('open', function() { window._mpState = 'open'; });
		s.addEventListener('message', function(ev) {
			try {
				var data = (typeof ev.data === 'string') ? ev.data : new TextDecoder().decode(ev.data);
				window._mpIn.push(data);
				if (window._mpIn.length > 200) window._mpIn.shift();
			} catch(e) { window._mpLastError = 'recv:' + e.message; }
		});
		s.addEventListener('error', function() { window._mpLastError = 'ws_error'; });
		s.addEventListener('close', function(ev) {
			window._mpState = 'closed';
			window._mpLastError = ev && ev.reason ? ev.reason : ('code ' + (ev && ev.code || '?'));
		});
		} catch(e) {
			window._mpState = 'closed';
			window._mpLastError = 'open:' + e.message;
		}
	}
	setInterval(function() {
		// 1) Honor connect request
		if (window._mpWantConnect) {
			var u = window._mpWantConnect;
			window._mpWantConnect = null;
			mpOpenSocket(u);
		}
		// 2) Honor disconnect request
		if (window._mpWantDisconnect) {
			window._mpWantDisconnect = false;
			if (window._mpSocket) {
				try { window._mpSocket.close(); } catch(e){}
				window._mpSocket = null;
			}
			window._mpState = 'idle';
			window._mpIn = [];
		}
		// 3) Drain outgoing queue
		if (window._mpSocket && window._mpSocket.readyState === 1 && window._mpOut.length > 0) {
			var batch = window._mpOut.splice(0, 50);
			for (var i = 0; i < batch.length; i++) {
				try { window._mpSocket.send(batch[i]); }
				catch(e) { window._mpLastError = 'send:' + e.message; }
			}
		}
	}, 50);
	// === HTTP chat fallback (БАГ-008 workaround) ===
	// WebSocket chat may not deliver between clients on some browsers. HTTP polling
	// is 100% reliable. Poll /api/chat/poll every 500ms, push results into _mpIn.
	window._mpLastChatTs = 0;
	setInterval(function() {
		try {
			fetch('/api/chat/poll?since=' + window._mpLastChatTs)
				.then(function(r) { return r.json(); })
				.then(function(msgs) {
					if (!msgs || msgs.length === 0) return;
					for (var i = 0; i < msgs.length; i++) {
						var m = msgs[i];
						if (m.ts > window._mpLastChatTs) window._mpLastChatTs = m.ts;
						window._mpIn.push(JSON.stringify({ t: 'chat', id: m.id, name: m.name, text: m.text }));
					}
				})
				.catch(function() {});  // silent fail (server might be down)
		} catch(e) {}
	}, 500);
	// Direct chat send — bypass Godot entirely. The user clicks Send in the
	// multiplayer UI; multiplayer_ui._on_send() calls NetworkManager.send_chat
	// which pushes to _mpOut; but for reliability we also expose a direct JS
	// shortcut that the UI can fall back to. This is the path used when testing
	// via window.gameMPSendChat from outside Godot.
	window.gameMPSendChat = function(text) {
		// Try WebSocket first (fast path)
		if (window._mpSocket && window._mpSocket.readyState === 1) {
			try {
				window._mpSocket.send(JSON.stringify({ t: 'chat', text: String(text) }));
			} catch(e) {}
		}
		// Always also POST to HTTP endpoint (reliable fallback)
		try {
			fetch('/api/chat/send', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ name: window._mpMyName || 'Hero', text: String(text) })
			}).catch(function(){});
		} catch(e) {}
		return true;
	};
})();
	</script>
	<script src="index.js"></script>
		<script>
const GODOT_CONFIG = ${GODOT_CONFIG};
const GODOT_THREADS_ENABLED = ${THREADS};
const engine = new Engine(GODOT_CONFIG);

(function () {
	const statusOverlay = document.getElementById('status');
	const statusProgress = document.getElementById('status-progress');
	const statusNotice = document.getElementById('status-notice');
	const pctLabel = document.getElementById('bw-pct');
	let initializing = true;
	let statusMode = '';
	let lastProgressTs = Date.now();

	function setStatusMode(mode) {
		if (statusMode === mode || !initializing) return;
		if (mode === 'hidden') { statusOverlay.remove(); initializing = false; return; }
		statusOverlay.style.visibility = 'visible';
		statusProgress.style.display = mode === 'progress' ? 'block' : 'none';
		statusNotice.style.display = mode === 'notice' ? 'block' : 'none';
		statusMode = mode;
	}
	function setStatusNotice(text) {
		while (statusNotice.lastChild) statusNotice.removeChild(statusNotice.lastChild);
		statusNotice.appendChild(document.createTextNode(text));
	}
	function displayFailureNotice(err) {
		console.error(err);
		let msg = (err instanceof Error) ? err.message : (typeof err === 'string' ? err : 'An unknown error occurred.');
		setStatusNotice('Ошибка запуска:\\n' + msg);
		setStatusMode('notice');
		initializing = false;
	}

	const missing = Engine.getMissingFeatures({ threads: GODOT_THREADS_ENABLED });

	if (missing.length !== 0) {
		if (GODOT_CONFIG['serviceWorker'] && GODOT_CONFIG['ensureCrossOriginIsolationHeaders'] && 'serviceWorker' in navigator) {
			let swPromise;
			try { swPromise = navigator.serviceWorker.getRegistration(); }
			catch (e) { swPromise = Promise.reject(new Error('Service worker registration failed.')); }
			Promise.race([
				swPromise.then((reg) => reg != null ? Promise.reject(new Error('Service worker already exists.')) : reg)
					.then(() => engine.installServiceWorker()),
				new Promise((r) => setTimeout(r, 2000)),
			]).then(() => window.location.reload())
			  .catch((e) => console.error('Error while registering service worker:', e));
		} else {
			displayFailureNotice('Недостаточно функций браузера:\\n' + missing.join('\\n'));
		}
	} else {
		setStatusMode('progress');
		lastProgressTs = Date.now();
		engine.startGame({
			'onProgress': function (current, total) {
				if (current > 0 && total > 0) {
					statusProgress.value = current;
					statusProgress.max = total;
					pctLabel.textContent = 'ЗАГРУЗКА… ' + Math.round(current / total * 100) + '%';
				} else {
					statusProgress.removeAttribute('value');
					statusProgress.removeAttribute('max');
					pctLabel.textContent = 'ЗАГРУЗКА…';
				}
				lastProgressTs = Date.now();
			},
		}).then(() => setStatusMode('hidden'), displayFailureNotice);
	}

	// Watchdog: if the download stalls (no progress for 45s) show a clear message
	// instead of leaving the user staring at a dark screen.
	setInterval(function () {
		if (!initializing || statusMode !== 'progress') return;
		if (Date.now() - lastProgressTs > 45000) {
			setStatusNotice('Загрузка прервалась — похоже, проблема с интернетом.\\nПроверьте соединение и обновите страницу (F5).');
			setStatusMode('notice');
		}
	}, 5000);
}());
		</script>
	</body>
</html>
`;

fs.writeFileSync(file, shell);
console.log('[shell] patched OK ->', file, '(' + Math.round(shell.length / 1024) + ' KB)');
