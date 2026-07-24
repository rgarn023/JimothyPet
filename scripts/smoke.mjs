import { chromium } from "playwright-core";

const base = process.env.BASE_URL || "http://127.0.0.1:8080/";

const kitState = {
  bornAt: Date.now() - 60000,
  lastTick: Date.now(),
  ageSec: 60,
  stage: "kit",
  adultVariant: "noble",
  hunger: 50,
  happy: 50,
  health: 90,
  discipline: 40,
  weight: 5,
  careScore: 2,
  careMistakes: 0,
  stubborn: false,
  stubbornReason: "",
  hasMess: true,
  sick: false,
  alive: true,
  sleep: false,
  treatStreak: 0,
  healthyMeals: 1,
  playSessions: 0,
};

const browser = await chromium.launch({
  headless: true,
  executablePath: "/usr/bin/google-chrome-stable",
});
const page = await browser.newPage({ viewport: { width: 420, height: 900 } });

const errors = [];
page.on("pageerror", (err) => errors.push(String(err)));
page.on("console", (msg) => {
  if (msg.type() !== "error") return;
  const text = msg.text();
  if (/favicon/i.test(text)) return;
  errors.push(text);
});
page.on("response", (res) => {
  if (res.status() === 404 && res.url().includes("favicon.ico")) return;
  if (res.status() >= 400) errors.push(`${res.status()} ${res.url()}`);
});

await page.addInitScript((state) => {
  localStorage.setItem("jimothy-pet-v1", JSON.stringify(state));
}, kitState);

await page.goto(base, { waitUntil: "networkidle" });
await page.waitForSelector("#raccoon svg");
await page.waitForFunction(() => window.JimothyDebug);

const brand = await page.locator(".brand").textContent();
const stage = await page.locator("#stageChip").textContent();
const stageName = await page.locator("#stageName").textContent();
const feedDisabled = await page.locator("#btnFeed").isDisabled();
const cleanDisabled = await page.locator("#btnClean").isDisabled();

await page.screenshot({
  path: "/opt/cursor/artifacts/screenshots/jimothy-kit.png",
  fullPage: true,
});

await page.click("#btnFeed", { force: true });
await page.waitForSelector("#feedModal:not([hidden])");
await page.click('[data-food="pizza"]', { force: true });
await page.waitForFunction(() => document.getElementById("feedModal").hidden);

await page.click("#btnPlay", { force: true });
await page.waitForSelector("#gameModal:not([hidden])");
await page.waitForTimeout(400);
await page.screenshot({
  path: "/opt/cursor/artifacts/screenshots/jimothy-minigame.png",
});
await page.click("#gameClose", { force: true });
await page.waitForFunction(() => document.getElementById("gameModal").hidden);

await page.click("#btnClean", { force: true });
const cleanDisabledAfter = await page.locator("#btnClean").isDisabled();

await page.evaluate(() => {
  window.JimothyDebug.setState({
    stubborn: true,
    stubbornReason: "refuses healthy food",
  });
});
await page.click("#btnDiscipline", { force: true });
const scoldDisabledAfter = await page.locator("#btnDiscipline").isDisabled();

// Real-time catch-up should apply more than 1 hour (old 3600s cap removed).
const realtime = await page.evaluate(() => {
  const before = window.JimothyDebug.getState();
  window.JimothyDebug.setState({
    lastTick: Date.now() - 2 * 60 * 60 * 1000,
    hunger: 100,
    happy: 100,
    health: 100,
    alive: true,
    hasMess: false,
    stubborn: false,
    ageSec: before.ageSec,
  });
  const elapsed = window.JimothyDebug.syncRealtime();
  const after = window.JimothyDebug.getState();
  return {
    elapsed,
    ageBefore: before.ageSec,
    ageAfter: after.ageSec,
    hungerAfter: after.hunger,
    uncapped: elapsed >= 7200,
    hungerDropped: after.hunger < 100,
  };
});

const manifestOk = await page.evaluate(async () => {
  const res = await fetch("./manifest.webmanifest");
  if (!res.ok) return false;
  const data = await res.json();
  return data.short_name === "Jimothy" && Array.isArray(data.icons);
});

await page.screenshot({
  path: "/opt/cursor/artifacts/screenshots/jimothy-after-care.png",
  fullPage: true,
});

await browser.close();

const summary = {
  brand: brand?.trim(),
  stage: stage?.trim(),
  stageName: stageName?.trim(),
  feedEnabledOnKit: !feedDisabled,
  cleanEnabledWithMess: !cleanDisabled,
  cleanDisabledAfterClean: cleanDisabledAfter,
  scoldDisabledAfterDiscipline: scoldDisabledAfter,
  realtime,
  manifestOk,
  errors,
};
summary.ok =
  errors.length === 0 &&
  summary.brand === "Jimothy" &&
  summary.stage === "Kit" &&
  summary.feedEnabledOnKit &&
  summary.cleanEnabledWithMess &&
  summary.cleanDisabledAfterClean &&
  summary.scoldDisabledAfterDiscipline &&
  summary.realtime.uncapped &&
  summary.realtime.hungerDropped &&
  summary.manifestOk;

console.log(JSON.stringify(summary, null, 2));
if (!summary.ok) process.exit(1);
