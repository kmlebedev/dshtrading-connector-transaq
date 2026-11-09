# AGENTS.md — dshtrading-connector-transaq

Репозиторий Cordis-коннектора TRANSAQ для хоста dsh-trading в DeepSeek Harness. Документация
и отчёты — русский, код и комментарии — английский (как в исходном `kmlebedev/txmlconnector`).
Этот файл — обязательная инструкция для агентов, работающих в этом репозитории.

## Что здесь

- Корень репозитория — единственный runtime-пакет: ESM `@dshtrading/ru` без зависимостей
  (`"dependencies": {}`), тесты `node:test` в `test/`. Пакет публикуемый: без `private`, с
  `publishConfig.access: public`; публикация — только по явной просьбе пользователя.
- `package.json` объявляет DSH-bundle (`dsh.bundle.patch: ./cordis.patch.yml`), а
  `cordis.patch.yml` вставляет строку `dsh-trading-ru-connector-transaq`. Штатная установка из
  npm после публикации: `dsh plugin --profile trading-web add @dshtrading/ru`; из локального
  checkout'а: `dsh plugin --profile <name> add "file:$PWD"`. `@dshtrading/base` в профиле
  `trading-web` уже есть; для чистого профиля его ставят отдельно.
- `tools/dsh-connector-enable.sh` — обёртка над этими командами с бэкапом, удалением legacy
  `@local/dshtrading-connector-transaq` и `--remove`; основной путь установки — bundle, а не
  ручная правка профиля.
- `docs/` и `mkdocs.yml` — сайт GitHub Pages (MkDocs Material), workflow
  `.github/workflows/pages.yml`. `_site/` и `.pages-site/` не коммитить.
- `.github/workflows/publish.yml` — ручная публикация `@dshtrading/ru` в npm с секретом
  `NPM_TOKEN`; запускать только по явной просьбе пользователя.
- Go-шлюз `/api/gw/v1/*` и его контракт живут в
  [`kmlebedev/txmlconnector`](https://github.com/kmlebedev/txmlconnector); меняя ожидания к
  полям/единицам, сверяйтесь с `docs/ai-terminal/gateway-v1.md` там.

## Проверки перед коммитом

```bash
make test                                  # node --test test/*.test.mjs
bash -n tools/dsh-connector-enable.sh
python3 -m mkdocs build --strict            # если установлен mkdocs-material; CI ставит его сам
git grep -nE 'TC_(PASSWORD|LOGIN)[[:space:]]*=' -- ':!*.md'   # значений секретов быть не должно
```

Изменения кода (JS, shell, bundle-манифесты, workflow) проходят ревью вторым субагентом на
модели `qwencloud/qwen3.8-flash` до коммита; блокеры исправляются, после правок тесты
повторяются.

## Жёсткие правила

- Код dsh-trading (PolyForm Noncommercial) не копировать и не импортировать — ни исходники, ни
  типы; совместимость только структурная.
- Никакой живой торговли: `placeOrder` только dry-run, `dryRun:false` →
  `TRADING_LIVE_TRADING_DISABLED`; не регистрировать `ru_place_order`/`ru_cancel_order`.
- Шлюз — только `http://` loopback; токен не логировать и не включать в тексты ошибок.
- `TC_LOGIN`, `TC_PASSWORD`, номера счетов/клиентов не попадают в репозиторий, тесты, логи и
  коммиты.
- Тесты не ходят в сеть (только loopback-фейки) и не требуют Go/DSH.
- Установка — только штатным bundle-путём. Не дублировать строку коннектора в профиле: для
  нестандартных `gatewayUrl`/`tokenRef` используйте replace-строку без `insert` с тем же id.
- Публикация в npm (`npm publish` или workflow Publish) — только по явной
  просьбе пользователя и только при наличии доступа к scope `@dshtrading` (scope принадлежит
  upstream dsh-trading).
- Профиль пользователя `~/.dsh` меняется только по явной просьбе пользователя.
