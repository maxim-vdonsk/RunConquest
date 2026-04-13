-- =============================================
-- RunConquest — Migration Phase 1
-- Запусти в Supabase: Dashboard → SQL Editor
-- =============================================

-- 1. Расширить таблицу runs (новые поля трекинга)
ALTER TABLE runs
  ADD COLUMN IF NOT EXISTS total_time_seconds int,
  ADD COLUMN IF NOT EXISTS avg_pace_seconds    int,
  ADD COLUMN IF NOT EXISTS avg_heart_rate      int,
  ADD COLUMN IF NOT EXISTS max_heart_rate      int,
  ADD COLUMN IF NOT EXISTS calories            int,
  ADD COLUMN IF NOT EXISTS points              int DEFAULT 0,
  ADD COLUMN IF NOT EXISTS city                text;

-- 2. Расширить таблицу players
ALTER TABLE players
  ADD COLUMN IF NOT EXISTS city          text,
  ADD COLUMN IF NOT EXISTS total_points  bigint DEFAULT 0,
  ADD COLUMN IF NOT EXISTS device_token  text,
  ADD COLUMN IF NOT EXISTS badge_ids     text DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS squad_name    text;

-- 3. Сплиты по километрам
CREATE TABLE IF NOT EXISTS run_splits (
  id             uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  run_id         text        NOT NULL,
  player_name    text        NOT NULL,
  km_index       int         NOT NULL,
  duration_sec   int         NOT NULL,
  pace_sec       int         NOT NULL,
  heart_rate     int,
  created_at     timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS run_splits_run_id_idx ON run_splits(run_id);

-- 4. Друзья (подписки)
CREATE TABLE IF NOT EXISTS friends (
  id             uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  follower_name  text        NOT NULL,
  following_name text        NOT NULL,
  created_at     timestamptz DEFAULT now(),
  UNIQUE(follower_name, following_name)
);
CREATE INDEX IF NOT EXISTS friends_follower_idx  ON friends(follower_name);
CREATE INDEX IF NOT EXISTS friends_following_idx ON friends(following_name);

-- 5. Лента активности
CREATE TABLE IF NOT EXISTS activity_feed (
  id           uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  player_name  text              NOT NULL,
  type         text              NOT NULL,  -- 'run_completed' | 'zone_captured' | 'challenge_done'
  run_id       text,
  distance     double precision  DEFAULT 0,
  area         double precision  DEFAULT 0,
  points       int               DEFAULT 0,
  likes_count  int               DEFAULT 0,
  color        text              DEFAULT 'orange',
  message      text,
  created_at   timestamptz       DEFAULT now()
);
CREATE INDEX IF NOT EXISTS activity_feed_player_idx ON activity_feed(player_name);
CREATE INDEX IF NOT EXISTS activity_feed_created_idx ON activity_feed(created_at DESC);

-- 6. Лайки на посты
CREATE TABLE IF NOT EXISTS activity_likes (
  id           uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  post_id      uuid REFERENCES activity_feed(id) ON DELETE CASCADE,
  player_name  text        NOT NULL,
  created_at   timestamptz DEFAULT now(),
  UNIQUE(post_id, player_name)
);

-- 7. Squads (команды)
CREATE TABLE IF NOT EXISTS squads (
  id            uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  name          text              NOT NULL,
  invite_code   text              NOT NULL UNIQUE,
  owner_name    text              NOT NULL,
  total_area    double precision  DEFAULT 0,
  total_runs    int               DEFAULT 0,
  member_count  int               DEFAULT 1,
  color         text              DEFAULT 'cyan',
  created_at    timestamptz       DEFAULT now()
);

-- 8. Участники squads
CREATE TABLE IF NOT EXISTS squad_members (
  id           uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  squad_id     uuid REFERENCES squads(id) ON DELETE CASCADE,
  squad_name   text        NOT NULL,
  player_name  text        NOT NULL UNIQUE,
  joined_at    timestamptz DEFAULT now()
);

-- 9. Челленджи
CREATE TABLE IF NOT EXISTS challenges (
  id              uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  title_en        text              NOT NULL,
  title_ru        text              NOT NULL,
  description_en  text,
  description_ru  text,
  type            text              NOT NULL,  -- 'distance'|'runs'|'territory'|'attacks'
  target_value    double precision  NOT NULL,
  month           int               NOT NULL,
  year            int               NOT NULL,
  reward_badge    text,
  created_at      timestamptz       DEFAULT now()
);

-- 10. Прогресс игроков в челленджах
CREATE TABLE IF NOT EXISTS challenge_progress (
  id            uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  challenge_id  uuid REFERENCES challenges(id) ON DELETE CASCADE,
  player_name   text              NOT NULL,
  current_value double precision  DEFAULT 0,
  completed     bool              DEFAULT false,
  completed_at  timestamptz,
  created_at    timestamptz       DEFAULT now(),
  UNIQUE(challenge_id, player_name)
);
CREATE INDEX IF NOT EXISTS challenge_progress_player_idx ON challenge_progress(player_name);

-- 11. Стартовые челленджи текущего месяца
INSERT INTO challenges (title_en, title_ru, description_en, description_ru, type, target_value, month, year, reward_badge)
SELECT * FROM (VALUES
  ('Run 50 km',         'Пробеги 50 км',         'Cover 50 km total this month',          'Набери 50 км суммарно за месяц',    'distance',  50000.0,  EXTRACT(MONTH FROM NOW())::int, EXTRACT(YEAR FROM NOW())::int, 'badge_50km'),
  ('Capture 10 zones',  'Захвати 10 зон',         'Attack and capture 10 enemy zones',     'Атакуй и захвати 10 чужих зон',     'attacks',   10.0,     EXTRACT(MONTH FROM NOW())::int, EXTRACT(YEAR FROM NOW())::int, 'badge_10attacks'),
  ('Complete 8 runs',   'Заверши 8 забегов',      'Complete 8 runs this month',            'Заверши 8 забегов за месяц',        'runs',      8.0,      EXTRACT(MONTH FROM NOW())::int, EXTRACT(YEAR FROM NOW())::int, 'badge_8runs'),
  ('Conquer 500k m²',   'Покрой 500 000 м²',      'Capture 500,000 m² of territory',      'Захвати 500 000 м² территории',     'territory', 500000.0, EXTRACT(MONTH FROM NOW())::int, EXTRACT(YEAR FROM NOW())::int, 'badge_territory')
) AS v(title_en, title_ru, description_en, description_ru, type, target_value, month, year, reward_badge)
WHERE NOT EXISTS (
  SELECT 1 FROM challenges
  WHERE month = EXTRACT(MONTH FROM NOW())::int
    AND year  = EXTRACT(YEAR  FROM NOW())::int
);

-- 12. Включить Realtime для новых таблиц
ALTER PUBLICATION supabase_realtime ADD TABLE activity_feed;
ALTER PUBLICATION supabase_realtime ADD TABLE activity_likes;
ALTER PUBLICATION supabase_realtime ADD TABLE squad_members;
