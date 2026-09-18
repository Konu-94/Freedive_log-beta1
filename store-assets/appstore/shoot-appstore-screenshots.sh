#!/bin/bash
# App Store 6.9" (1320x2868) 스크린샷 촬영.
# index.html 사본에 부트스트랩 스크립트를 주입해 게스트 로그인 후 특정 화면을 띄우고,
# Chrome 헤드리스로 440x956 @3x 로 캡처한다. 원본 index.html 은 건드리지 않는다.
set -e
SP="$(cd "$(dirname "$0")" && pwd)"
REPO=/Users/parksungrae/Study2/Freedive_log-beta1
SHOT="$SP/shot"
OUT="$REPO/store-assets/appstore"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

rm -rf "$SHOT"; mkdir -p "$SHOT" "$OUT"
cp "$REPO"/*.html "$REPO"/*.json "$REPO"/*.png "$SHOT"/ 2>/dev/null || true

python3 - "$SHOT/index.html" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
boot = """
<script>
// 스크린샷 촬영용 부트스트랩 (저장소의 index.html 에는 들어가지 않는다)
window.__shotReady = false;
window.addEventListener('load', async () => {
  const q = new URLSearchParams(location.search);
  const screen = q.get('screen') || 'screen-student-home';
  try {
    await handleGuestLogin();
    // 게스트 배너와 토스트는 스토어 스크린샷에 불필요하므로 제거
    document.querySelectorAll('.guest-banner').forEach(el => el.remove());
    const toast = document.getElementById('toast');
    if (toast) { toast.className = 'toast'; toast.style.display = 'none'; }
    showScreen(screen);
    const extra = q.get('call');
    if (extra && typeof window[extra] === 'function') await window[extra]();
    const js = q.get('js');
    if (js) { await eval(js); }   // 촬영용 사본에서만 동작
    await new Promise(r => setTimeout(r, 2500));
    document.querySelectorAll('.guest-banner').forEach(el => el.remove());
  } catch (e) {
    console.error('shot bootstrap error', e);
  }
  window.__shotReady = true;
  document.title = 'SHOT_READY';
});
</script>
"""
assert '</body>' in s
open(p, 'w', encoding='utf-8').write(s.replace('</body>', boot + '</body>'))
print('부트스트랩 주입 완료')
PY

( cd "$SHOT" && python3 -m http.server 8099 >/dev/null 2>&1 & echo $! > "$SP/shot_server.pid" )
sleep 2

shoot () { # $1=파일명 $2=화면id $3=화면 진입 후 호출할 함수(선택)
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars \
    --window-size=500,1087 --force-device-scale-factor=2.64 \
    --virtual-time-budget=12000 \
    --screenshot="$OUT/$1" "http://localhost:8099/index.html?screen=$2&call=$3&js=$4" >/dev/null 2>&1
  # Chrome 은 CSS 뷰포트를 500px 미만으로 줄이지 못한다. 500x1087 @2.64x 로 찍어
  # 6.9인치 규격(1320x2868)에 맞게 1~2px 만 잘라낸다.
  sips -c 2868 1320 "$OUT/$1" >/dev/null
  sips -g pixelWidth -g pixelHeight "$OUT/$1" | tr '\n' ' '; echo
}

shoot appstore-1-home.png            screen-student-home
shoot appstore-2-schedule.png        screen-student-schedule
shoot appstore-3-dry-training.png    screen-dry-training
shoot appstore-4-records.png         screen-my-records
shoot appstore-5-image-training.png  screen-dry-training    ''  "openImageTrainingDetail('duck_dive')"

kill "$(cat "$SP/shot_server.pid")" 2>/dev/null || true
echo "저장 위치: $OUT"
