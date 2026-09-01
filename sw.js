// DiveLog Service Worker
// ⚠️ index.html 등 앱 파일을 수정해 배포할 때마다 아래 CACHE_VERSION 숫자를 올려주세요.
//    올리지 않으면 낡은 캐시가 정리되지 않습니다.
const CACHE_VERSION = 'v1';
const CACHE_NAME = `divelog-${CACHE_VERSION}`;
const OFFLINE_URL = './offline.html';

// 앱 껍데기 — 설치 시 미리 저장
const PRECACHE = [
  './',
  './index.html',
  './offline.html',
  './manifest.json',
  './icon-32.png',
  './icon-192.png',
  './icon-512.png',
  './icon-maskable-512.png',
  './apple-touch-icon.png',
];

// 캐시해도 되는 외부 CDN (버전이 고정돼 있음)
const CDN_HOSTS = [
  'cdnjs.cloudflare.com',
  'cdn.jsdelivr.net',
  'fonts.googleapis.com',
  'fonts.gstatic.com',
];

self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE_NAME);
    // 하나가 실패해도 나머지는 저장되도록 개별 처리
    await Promise.all(PRECACHE.map(async (url) => {
      try {
        await cache.add(new Request(url, { cache: 'reload' }));
      } catch (err) {
        console.warn('[sw] precache 실패:', url, err);
      }
    }));
    await self.skipWaiting();
  })());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(
      keys.filter((k) => k.startsWith('divelog-') && k !== CACHE_NAME)
          .map((k) => caches.delete(k))
    );
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (event) => {
  const req = event.request;

  // GET 이외(POST/PATCH 등)는 건드리지 않음
  if (req.method !== 'GET') return;

  const url = new URL(req.url);

  // ❗ Supabase(DB·인증·스토리지)는 절대 캐시하지 않는다.
  //    캐시하면 기록을 추가해도 목록에 안 뜨는 문제가 생김.
  if (url.hostname.endsWith('supabase.co')) return;

  // 페이지 이동 요청: 네트워크 우선 → 실패 시 캐시 → 그래도 없으면 오프라인 안내
  if (req.mode === 'navigate') {
    event.respondWith((async () => {
      try {
        const fresh = await fetch(req);
        const cache = await caches.open(CACHE_NAME);
        cache.put(req, fresh.clone());
        return fresh;
      } catch (err) {
        const cache = await caches.open(CACHE_NAME);
        return (await cache.match(req))
            || (await cache.match('./index.html'))
            || (await cache.match(OFFLINE_URL))
            || Response.error();
      }
    })());
    return;
  }

  const isSameOrigin = url.origin === self.location.origin;
  const isCdn = CDN_HOSTS.includes(url.hostname);
  if (!isSameOrigin && !isCdn) return;

  // 정적 리소스: 캐시 우선 + 백그라운드 갱신
  event.respondWith((async () => {
    const cache = await caches.open(CACHE_NAME);
    const cached = await cache.match(req);

    const network = fetch(req).then((res) => {
      // 정상 응답만 저장 (opaque/에러 응답 제외)
      if (res && res.ok && res.type !== 'opaque') cache.put(req, res.clone());
      return res;
    }).catch(() => null);

    return cached || (await network) || Response.error();
  })());
});
