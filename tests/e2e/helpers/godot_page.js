const puppeteer = require('puppeteer');
const fs = require('fs');
const path = require('path');

const GODOT_URL = process.env.GODOT_URL || 'http://localhost:3000';
const CANVAS_SELECTOR = 'canvas';
const SCREENSHOT_DIR = path.join(__dirname, '..', '..', 'screenshots');

let browser = null;
let page = null;

if (!fs.existsSync(SCREENSHOT_DIR)) {
  fs.mkdirSync(SCREENSHOT_DIR, { recursive: true });
}

async function initBrowser() {
  browser = await puppeteer.launch({
    headless: 'new',
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-web-security',
      '--disable-features=ntlm-auth',
      '--disable-features=TranslateUI',
      '--disable-extensions',
      '--disable-background-networking',
      '--disable-sync',
      '--metrics-recording-only',
      '--no-first-run',
      '--safebrowsing-disable-auto-update'
    ]
  });
  page = await browser.newPage();
  await page.setViewport({ width: 1280, height: 720 });
  page.on('console', msg => {
    const type = msg.type();
    const text = msg.text();
    if (type === 'error') {
      fs.appendFileSync(
        path.join(SCREENSHOT_DIR, 'console.log'),
        `[ERROR] ${new Date().toISOString()} ${text}\n`
      );
    } else if (type === 'warning') {
      fs.appendFileSync(
        path.join(SCREENSHOT_DIR, 'console.log'),
        `[WARN] ${new Date().toISOString()} ${text}\n`
      );
    }
  });
  page.on('pageerror', err => {
    fs.appendFileSync(
      path.join(SCREENSHOT_DIR, 'console.log'),
      `[PAGE_ERROR] ${new Date().toISOString()} ${err.message}\n`
    );
  });
  return page;
}

async function loadGame() {
  if (!page) await initBrowser();
  // Mark the intro as "seen" so the first-launch auto-legend doesn't fire and
  // steal the menu — tests need the menu visible. Tests that exercise the intro
  // itself can clear this explicitly.
  await page.evaluateOnNewDocument(() => {
    try { localStorage.setItem('bookwar_intro_seen', '1'); } catch (e) {}
  });
  // NOTE: do NOT use waitUntil:'networkidle0' — the multiplayer chat poller
  // hits /api/chat/poll every 500ms (404 with no server), so the network is
  // never idle and goto would always time out. domcontentloaded + an explicit
  // wait for the engine's gameLoaded flag is reliable.
  await page.goto(GODOT_URL, { waitUntil: 'domcontentloaded', timeout: 30000 });
  await waitForCondition(() => page.evaluate(() => !!window.gameLoaded), 40000, 400);
  await page.waitForSelector(CANVAS_SELECTOR, { timeout: 15000 });
  const canvas = await page.$(CANVAS_SELECTOR);
  if (canvas) {
    // Click the TOP-LEFT corner for focus — never the center (buttons live there).
    const box = await canvas.boundingBox();
    if (box) {
      await page.mouse.click(box.x + 5, box.y + 5);
    }
  }
  await waitFrames(60);
  return page;
}

async function closeBrowser() {
  if (browser) {
    await browser.close();
    browser = null;
    page = null;
  }
}

function getPage() {
  return page;
}

async function waitFrames(count = 1) {
  for (let i = 0; i < count; i++) {
    await page.evaluate(() => new Promise(resolve => requestAnimationFrame(resolve)));
  }
}

async function waitMs(ms) {
  await new Promise(resolve => setTimeout(resolve, ms));
}

async function pressKey(key, duration = 100) {
  const canvas = await page.$(CANVAS_SELECTOR);
  if (canvas) {
    const box = await canvas.boundingBox();
    if (box) {
      await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2);
    }
  }
  await waitMs(50);
  await page.keyboard.down(key);
  await waitMs(duration);
  await page.keyboard.up(key);
  await waitFrames(5);
}

async function holdKey(key, durationMs) {
  const canvas = await page.$(CANVAS_SELECTOR);
  if (canvas) {
    const box = await canvas.boundingBox();
    if (box) {
      await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2);
    }
  }
  await waitMs(50);
  await page.keyboard.down(key);
  await waitMs(durationMs);
  await page.keyboard.up(key);
  await waitFrames(10);
}

async function clickAt(x, y) {
  await page.mouse.click(x, y);
  await waitFrames(10);
}

async function clickButton(buttonText) {
  if (buttonText.includes('Новая игра') || buttonText.includes('New Game')) {
    await page.evaluate(() => {
      if (typeof window.gameClickNewGame === 'function') {
        window.gameClickNewGame();
      }
    });
    await waitFrames(10);
    return true;
  }
  const button = await page.evaluateHandle((text) => {
    const buttons = Array.from(document.querySelectorAll('button'));
    return buttons.find(b => b.textContent.includes(text));
  }, buttonText);
  if (button && button.asElement()) {
    await button.asElement().click();
    await waitFrames(10);
    return true;
  }
  return false;
}

async function takeScreenshot(name) {
  const filename = `${name}_${Date.now()}.png`;
  const filepath = path.join(SCREENSHOT_DIR, filename);
  await page.screenshot({ path: filepath, fullPage: false });
  return filepath;
}

async function takeCanvasScreenshot(name) {
  const canvas = await page.$(CANVAS_SELECTOR);
  if (!canvas) return null;
  const filename = `canvas_${name}_${Date.now()}.png`;
  const filepath = path.join(SCREENSHOT_DIR, filename);
  await canvas.screenshot({ path: filepath });
  return filepath;
}

async function getConsoleLog() {
  const logPath = path.join(SCREENSHOT_DIR, 'console.log');
  if (fs.existsSync(logPath)) {
    return fs.readFileSync(logPath, 'utf-8');
  }
  return '';
}

async function clearConsoleLog() {
  const logPath = path.join(SCREENSHOT_DIR, 'console.log');
  if (fs.existsSync(logPath)) {
    fs.writeFileSync(logPath, '');
  }
}

async function evaluateInPage(fn, ...args) {
  return await page.evaluate(fn, ...args);
}

async function waitForCondition(fn, timeout = 10000, interval = 500) {
  const start = Date.now();
  while (Date.now() - start < timeout) {
    const result = await fn();
    if (result) return result;
    await waitMs(interval);
  }
  throw new Error('waitForCondition timed out');
}

async function getGameState() {
  return await page.evaluate(() => ({
    loaded: window.gameLoaded || false,
    menuVisible: window.gameMenuVisible || false,
    playerPos: window.gamePlayerPos || { x: 0, y: 0 },
    inventory: window.gameInventory || { letters: {}, dots: 0, punctuation: {} },
    hud: window.gameHUD || { hp: '', dots: '', region: '' },
    dialogueActive: window.gameDialogueActive || false,
    dialogueText: window.gameDialogueText || '',
    inCombat: window.gameInCombat || false,
    inventoryVisible: window.gameInventoryVisible || false
  }));
}

async function debugCapture(label) {
  const state = await getGameState();
  const screenshotPath = await takeScreenshot(`debug_${label}`);
  const canvasPath = await takeCanvasScreenshot(`debug_${label}`);
  const consoleLog = await getConsoleLog();
  return {
    state,
    screenshot: screenshotPath,
    canvas: canvasPath,
    consoleLog
  };
}

module.exports = {
  initBrowser,
  loadGame,
  closeBrowser,
  getPage,
  waitFrames,
  waitMs,
  pressKey,
  holdKey,
  clickAt,
  clickButton,
  takeScreenshot,
  takeCanvasScreenshot,
  getConsoleLog,
  clearConsoleLog,
  evaluateInPage,
  waitForCondition,
  getGameState,
  debugCapture,
  GODOT_URL,
  SCREENSHOT_DIR
};
