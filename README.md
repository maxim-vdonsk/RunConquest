# RunConquest

> **Проект находится в активной разработке. Функциональность и API могут меняться.**

Мобильная игра для iOS в жанре геолокационного завоевания территорий. Бегай по реальным улицам — захватывай территорию, атакуй зоны других игроков, соревнуйся в рейтинге.

---

## Концепция

Карта города разделена на зоны. Каждый забег оставляет след — выпуклый полигон территории, окрашенный в цвет твоей фракции. Пробеги через чужую зону — и она перейдёт к тебе. Защищай свои территории, объединяйся в отряды, выполняй ежемесячные вызовы.

---

## Функциональность

### Реализовано

- Трекинг маршрута в реальном времени с GPS-фильтрацией (точность, скорость, устаревшие точки)
- Захват территории — convex hull маршрута с расчётом площади (формула Шуэлейса)
- Интерактивная карта на Mapbox с зонами всех игроков в реальном времени
- Атаки на чужие зоны при пересечении маршрутов
- Пульс с Apple Watch через HealthKit (HKAnchoredObjectQuery + резервный поллинг)
- Интеграция с HealthKit: тренировки, калории, сплиты по километрам
- Регистрация и вход по email/паролю через Supabase Auth
- Выбор цвета фракции с синхронизацией в БД
- Лента активности с лайками
- Таблица лидеров (глобальная, по городу, среди друзей)
- Система отрядов (squads) с инвайт-кодами
- Ежемесячные вызовы (челленджи)
- Планы тренировок
- История забегов с детализацией и реплеем
- Push-уведомления
- Двуязычный интерфейс (русский / английский)
- Cyberpunk neon UI

### В разработке

- Уведомления о захвате твоей территории в реальном времени
- Рейтинг отрядов и командные вызовы
- Система значков и достижений
- Профили игроков с публичными страницами
- Тёмная/светлая тема

---

## Стек

| Компонент | Технология |
|---|---|
| Платформа | iOS 17+ / SwiftUI |
| Карты | Mapbox Maps SDK |
| Backend / БД | Supabase (PostgreSQL + Realtime) |
| Auth | Supabase Auth |
| Здоровье | HealthKit |
| Архитектура | @Observable, Swift Concurrency |

---

## Требования

- iOS 17.0+
- Xcode 15+
- Аккаунт Mapbox (токен + стиль карты)
- Проект Supabase

---

## Установка

**1. Клонировать репозиторий**

```bash
git clone https://github.com/maxim-vdonsk/RunConquest.git
cd RunConquest
```

**2. Настроить секреты**

Скопировать шаблон и вставить ключи:

```bash
cp Secrets.example.xcconfig Secrets.xcconfig
```

Открыть `Secrets.xcconfig` и заполнить:

```
SUPABASE_URL = https://your-project.supabase.co
SUPABASE_KEY = your-anon-key
MAPBOX_TOKEN = pk.your-mapbox-token
MAPBOX_STYLE = mapbox://styles/your-style
```

**3. Применить миграции БД**

В Supabase Dashboard → SQL Editor выполнить `supabase_migration_phase1.sql`, затем:

```sql
-- Таблицы аутентификации и профилей
ALTER TABLE players ADD COLUMN IF NOT EXISTS email text;
ALTER TABLE players ADD COLUMN IF NOT EXISTS color text DEFAULT 'orange';
CREATE UNIQUE INDEX IF NOT EXISTS players_email_idx ON players(email) WHERE email IS NOT NULL;
```

**4. Включить Background Modes в Xcode**

Target → Signing & Capabilities → + Capability:
- Location updates
- Background fetch

**5. Собрать и запустить**

Открыть `RunConquest.xcodeproj` в Xcode, выбрать реальное устройство (GPS и HealthKit не работают на симуляторе).

---

## Структура проекта

```
RunConquest/
├── RunConquestApp.swift      # Точка входа, навигация
├── Models.swift              # Модели данных
├── Theme.swift               # Дизайн-система (Neon, компоненты)
├── Localization.swift        # Двуязычность
├── LocationManager.swift     # GPS-трекинг, convex hull
├── HealthKitManager.swift    # HealthKit, пульс
├── SupabaseService.swift     # API-клиент Supabase
├── RealtimeManager.swift     # Realtime-подписки
├── MapViews.swift            # Mapbox, зоны, маршруты
├── ContentView.swift         # Основной экран бега
├── AuthView.swift            # Вход / регистрация
├── OnboardingView.swift      # Онбординг
├── MainTabView.swift         # Таб-навигация
├── ProfileView.swift         # Профиль игрока
├── FeedView.swift            # Лента активности
├── LeaderboardView.swift     # Рейтинги
├── ResultsView.swift         # Итоги забега
├── RunDetailView.swift       # Детали забега
├── ReplayView.swift          # Реплей маршрута
├── TrainingPlanView.swift    # Планы тренировок
├── ChallengesView.swift      # Вызовы
├── SquadsView.swift          # Отряды
└── FriendsView.swift         # Друзья
```

---

## Лицензия

Проект закрытый. Все права защищены.
