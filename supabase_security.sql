-- =====================================================================
-- DiveLog 보안 조치 SQL
--
-- ⚠️ 한 번에 전부 실행하지 마세요. 아래 STAGE 순서대로,
--    각 단계마다 앱이 정상 동작하는지 확인한 뒤 다음으로 넘어가세요.
--    순서를 어기면 실사용자 152명의 로그인이 즉시 끊깁니다.
--
-- 실행 위치: Supabase 대시보드 → SQL Editor
-- =====================================================================


-- ─────────────────────────────────────────────────────────────────────
-- STAGE 1. 로그인을 RPC 함수로 옮긴다  (앱 동작에 영향 없음, 먼저 실행)
--
--   지금은 앱이 users 테이블을 직접 SELECT 해서 로그인합니다.
--   그래서 users 에 RLS 를 걸면 로그인이 깨집니다.
--   먼저 "검증은 서버가 하고 결과만 돌려주는" 함수를 만들어 둡니다.
-- ─────────────────────────────────────────────────────────────────────

create extension if not exists pgcrypto;

-- 비밀번호 컬럼 (기존 사용자는 null → 아직 비밀번호 없음)
alter table public.users
  add column if not exists password_hash text;

-- 로그인: 전화번호 + 아이디 (+ 비밀번호가 설정돼 있으면 비밀번호까지)
create or replace function public.login_user(
  p_phone    text,
  p_user_id  text,
  p_password text default null
)
returns setof public.users
language plpgsql
security definer            -- 호출자 권한이 아닌 소유자 권한으로 실행
set search_path = public
as $$
declare
  v_user public.users%rowtype;
begin
  select * into v_user
  from public.users
  where phone = p_phone and user_id = p_user_id;

  if not found then
    raise exception '연락처 또는 아이디가 일치하지 않습니다.';
  end if;

  -- 비밀번호가 설정된 계정이면 반드시 검증
  if v_user.password_hash is not null then
    if p_password is null or v_user.password_hash <> crypt(p_password, v_user.password_hash) then
      raise exception '비밀번호가 일치하지 않습니다.';
    end if;
  end if;

  return next v_user;
end;
$$;

-- 비밀번호 설정/변경
create or replace function public.set_password(
  p_phone    text,
  p_user_id  text,
  p_password text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if length(p_password) < 8 then
    raise exception '비밀번호는 8자 이상이어야 합니다.';
  end if;

  update public.users
     set password_hash = crypt(p_password, gen_salt('bf'))
   where phone = p_phone and user_id = p_user_id;

  if not found then
    raise exception '계정을 찾을 수 없습니다.';
  end if;
end;
$$;

-- 게스트(둘러보기) 계정 조회 전용
create or replace function public.get_guest_user()
returns setof public.users
language sql
security definer
set search_path = public
as $$
  select * from public.users where user_id = 'dodo' limit 1;
$$;

revoke all on function public.login_user(text, text, text)   from public, anon;
revoke all on function public.set_password(text, text, text)  from public, anon;
revoke all on function public.get_guest_user()                from public, anon;
grant execute on function public.login_user(text, text, text) to anon;
grant execute on function public.set_password(text, text, text) to anon;
grant execute on function public.get_guest_user()             to anon;


-- ─────────────────────────────────────────────────────────────────────
-- STAGE 2.  ⛔ 앱 코드를 먼저 바꾼 뒤에 실행하세요.
--
--   index.html 의 로그인이 db.rpc('login_user', ...) 를 쓰도록
--   수정·배포하고, 로그인이 정상 동작하는 것을 확인한 다음 실행합니다.
--   이 단계가 "전화번호 152건 전부 유출" 구멍을 막습니다.
-- ─────────────────────────────────────────────────────────────────────

alter table public.users enable row level security;

-- anon 은 users 를 직접 읽을 수 없다. 오직 위 RPC 를 통해서만 접근.
-- (정책을 하나도 만들지 않으면 = 전면 차단)


-- ─────────────────────────────────────────────────────────────────────
-- STAGE 3. 나머지 테이블 RLS
--
--   ⚠️ 지금 구조로는 이 단계를 그냥 켜면 앱이 통째로 멈춥니다.
--      익명 키에는 "내가 누구인지" 알려주는 정보가 없어서
--      RLS 가 사용자를 구분할 수 없기 때문입니다.
--      → Supabase Auth 도입이 선행되어야 합니다. 아래 주석 참고.
-- ─────────────────────────────────────────────────────────────────────

-- 임시방편: 읽기는 열어두되 삭제만 막는다 (완전한 해결책 아님)
--
-- do $$
-- declare t text;
-- begin
--   foreach t in array array[
--     'dive_records','personal_dive_records','skill_records',
--     'dry_training_records','dry_training_steps','dry_trainings',
--     'schedules','personal_schedules','registrations',
--     'equipment','certifications',
--     'image_training_categories','image_training_steps'
--   ] loop
--     execute format('alter table public.%I enable row level security', t);
--     execute format('create policy %I on public.%I for select to anon using (true)',  t||'_sel', t);
--     execute format('create policy %I on public.%I for insert to anon with check (true)', t||'_ins', t);
--     execute format('create policy %I on public.%I for update to anon using (true)',  t||'_upd', t);
--     -- delete 정책은 만들지 않는다 → 익명 삭제 차단
--   end loop;
-- end $$;


-- ─────────────────────────────────────────────────────────────────────
-- STAGE 4. Storage 버킷 비공개 전환
--
--   자격증 이미지가 지금 공개 버킷에 있습니다. 파일명이
--   "아이디_타임스탬프.확장자" 라 URL 추측이 어렵지 않습니다.
--   자격증 사진에는 보통 실명과 생년월일이 있습니다.
--
--   대시보드 → Storage → certifications → Settings 에서
--   Public bucket 을 끄고, 앱 코드의 getPublicUrl() 을
--   createSignedUrl() 로 바꿔야 합니다.
-- ─────────────────────────────────────────────────────────────────────
