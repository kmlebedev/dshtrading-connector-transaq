# Происхождение репозитория

`dshtrading-connector-transaq` создан 2026-11-09 выносом пакета `dshtrading-connector-transaq/` и
помощника `tools/dsh-connector-enable.sh` из
[`kmlebedev/txmlconnector`](https://github.com/kmlebedev/txmlconnector) (`main`, merge PR #70
`f70b0f4`). Повторяет схему выноса AI-терминала в
[`kmlebedev/dsh-trading-transaq`](https://github.com/kmlebedev/dsh-trading-transaq).

## Что перенесено

- каталог `dshtrading-connector-transaq/` целиком (код, тесты, README, QUICKSTART) и
  `tools/dsh-connector-enable.sh`;
- история этих путей — **15 коммитов** (2026-11-06 … 2026-11-09) с сохранением автора, дат и
  сообщений; каждый коммит содержит только перенесённые пути. Merge-коммиты PR #67/#68/#70 в
  линейную историю не входят, их содержимое есть в коммитах файлов. Перенос — `git format-patch`
  по путям + `git am --committer-date-is-author-date`;
- состояние файлов после 15-го коммита побайтно совпадает с `txmlconnector` `f70b0f4`.

Поверх истории: scaffolding (README, AGENTS.md, Makefile, CI Node 24, `.gitignore`, этот
документ) и правка ссылок в документах коннектора: относительные `../docs/...` заменены
ссылками на txmlconnector, QUICKSTART собирает шлюз из соседнего checkout'а
(`make -C ../txmlconnector terminal`).

## Что осталось в txmlconnector

Go-шлюз `/api/gw/v1/*` (`terminal/api/gateway.go`), его контракт `docs/ai-terminal/gateway-v1.md`,
ADR, план и отчёты приёмки (`docs/ai-terminal/*`, `docs/superpowers/plans/*`).

## Решения

- Имя пакета менялось: `@local/dshtrading-connector-transaq` → `@dshtrading/ru`; row id
  `dsh-trading-ru-connector-transaq` сохранён. Профили со старой зависимостью требуют удалить
  `link:`-зависимость на подкаталог `dshtrading-connector-transaq/` и строку коннектора, затем
  установить `@dshtrading/ru`; скрипт-обёртка делает это автоматически.
- LICENSE — MIT (решение владельца, 2026-11-09), как в dsh-trading-transaq.

## Стандартизация 2026-11-09

- Пакет перенесён из подкаталога `dshtrading-connector-transaq/` в корень репозитория
  (`git mv`, история файлов сохранена). Корень теперь — самостоятельный пакет и DSH-bundle:
  `index.js`, `config.js`, `gateway-client.js`, `market-data.js`, `symbols.js`, `tools.js`,
  `trade.js`, `test/`, `package.json`, `cordis.patch.yml`.
- `package.json` объявляет `dsh.bundle.patch: ./cordis.patch.yml`; патч вставляет строку
  `dsh-trading-ru-connector-transaq`. Штатная установка из npm —
  `dsh plugin --profile trading-web add @dshtrading/ru`; из локального checkout'а —
  `dsh plugin --profile <name> add "file:$PWD"` (или `plugin_manager install_bundle` с target =
  корень репозитория). `@dshtrading/base` в профиле `trading-web` уже есть; для чистого профиля
  его ставят отдельно, потому что DSH не раскрывает транзитивные bundle-зависимости.
- `tools/dsh-connector-enable.sh` переписан как обёртка над `dsh plugin add` / `remove` с
  бэкапом профиля; для нестандартных `gatewayUrl`/`tokenRef` он пишет replace-строку без
  `insert`.
- Порт по умолчанию выровнен по QUICKSTART: `http://127.0.0.1:18095` (18090 занят бэкендом
  AI-терминала).
- Добавлен сайт GitHub Pages: `docs/index.md`, `docs/migration.md`, `mkdocs.yml`,
  `.github/workflows/pages.yml`; публикация — `https://kmlebedev.github.io/dshtrading-connector-transaq/`.
  Сайт собирается из `docs/` на `main`, отдельная ветка `pages` не используется.

## Пакет `@dshtrading/ru` (2026-11-09)

- Пакет переименован из `@local/dshtrading-connector-transaq` в `@dshtrading/ru`, чтобы его
  можно было публиковать и ставить штатно:
  `dsh plugin --profile trading-web add @dshtrading/ru`.
- Снят `private`, добавлен `publishConfig.access: public`. Публикация —
  `npm publish` или ручной workflow **Publish** с секретом `NPM_TOKEN`.
  Scope `@dshtrading` принадлежит upstream dsh-trading; без доступа к нему publish вернёт 403.
  В текущем окружении npm-аутентификация не настроена, поэтому публикация в PR не выполнялась.
- `cordis.patch.yml` ссылается на `@dshtrading/ru`; row id
  `dsh-trading-ru-connector-transaq` не менялся.
- `tools/dsh-connector-enable.sh` при enable удаляет legacy
  `@local/dshtrading-connector-transaq`, если он был установлен, и не трогает уже
  установленный `@dshtrading/base`.

## Проверки

- `make test` — все тесты `node:test`, включая структурный `test/bundle.test.mjs`;
- `bash -n tools/dsh-connector-enable.sh` — ok;
- `mkdocs build --strict` — ok (локально Material 9.7.7 на Python 3.9; CI — Python 3.12);
- smoke-установка в изолированном `DSH_HOME` (`@dshtrading/base@^0.6.3` и
  `@dshtrading/base@^0.7.0` + `file:$PWD`) — ok, `dsh --profile smoke --dump-config` показывает
  строку коннектора `@dshtrading/ru`.
