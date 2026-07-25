/* Jimothy service worker — offline shell + care notification clicks */
const CACHE = "jimothy-v19";
const ASSETS = [
  "./",
  "./index.html",
  "./styles.css",
  "./favicon.svg",
  "./manifest.webmanifest",
  "./js/game.js",
  "./js/minigame.js",
  "./js/dicegame.js",
  "./js/raccoon.js",
  "./js/sound.js",
  "./js/notify.js",
  "./audio/night_ambience.wav",
  "./audio/chitter.wav",
  "./audio/chirp.wav",
  "./audio/grumble.wav",
  "./audio/rustle.wav",
  "./audio/crunch.wav",
  "./audio/ascend.wav",
  "./audio/hoot.wav",
  "./icons/icon-192.png",
  "./icons/icon-512.png",
];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE).then((cache) => cache.addAll(ASSETS)).then(() => self.skipWaiting())
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)))
    ).then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", (event) => {
  const { request } = event;
  if (request.method !== "GET") return;

  const url = new URL(request.url);
  const isScript =
    url.pathname.endsWith(".js") ||
    url.pathname.endsWith(".css") ||
    url.pathname.endsWith(".html") ||
    url.pathname.endsWith("/");

  // Network-first for app shell/scripts so High or Low fixes aren't stuck behind old cache.
  if (isScript) {
    event.respondWith(
      fetch(request)
        .then((response) => {
          if (response && response.ok && response.type === "basic") {
            const copy = response.clone();
            caches.open(CACHE).then((cache) => cache.put(request, copy));
          }
          return response;
        })
        .catch(() => caches.match(request))
    );
    return;
  }

  event.respondWith(
    caches.match(request).then((cached) => {
      const network = fetch(request)
        .then((response) => {
          if (response && response.ok && response.type === "basic") {
            const copy = response.clone();
            caches.open(CACHE).then((cache) => cache.put(request, copy));
          }
          return response;
        })
        .catch(() => cached);
      return cached || network;
    })
  );
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  const target = (event.notification.data && event.notification.data.url) || "./";
  event.waitUntil(
    clients.matchAll({ type: "window", includeUncontrolled: true }).then((list) => {
      for (const client of list) {
        if ("focus" in client) return client.focus();
      }
      if (clients.openWindow) return clients.openWindow(target);
      return undefined;
    })
  );
});
