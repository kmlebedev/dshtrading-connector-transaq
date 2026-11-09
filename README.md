# dshtrading-connector-transaq — коннектор TRANSAQ для DeepSeek Harness

Cordis-плагин, который подключает рынок MOEX (Finam/TRANSAQ) к хосту
[dsh-trading](https://github.com/zhu1090093659/dsh-trading) в DeepSeek Harness: регистрирует
рынок `ru` / провайдер `finam` в реестрах хоста и даёт агенту 6 read-only инструментов `ru_*`
(тикер, свечи, стакан, лента, инструменты, бумажный счёт). Заявки только dry-run, реальной
торговли нет.

Пакет подготовлен для публикации как `@dshtrading/ru`; после публикации он ставится штатно:
`dsh plugin --profile trading-web add @dshtrading/ru` (в профиле `trading-web` уже есть
`@dshtrading/base`). До публикации используйте локальный checkout:
`dsh plugin --profile desktop add "file:$PWD"`.

**Документация: [kmlebedev.github.io/dshtrading-connector-transaq](https://kmlebedev.github.io/dshtrading-connector-transaq/)** ·
**Быстрый старт: [QUICKSTART.md](QUICKSTART.md)**

## Что делает

- Регистрирует `MarketDataService` (тикер, свечи, стакан, сделки, список инструментов,
  `subscribeTicker` поллингом) и `TradeService`: read-only просмотр бумажного счёта (балансы,
  позиции, заявки, сделки) и dry-run проверка заявок (см. «Ограничения») в реестрах
  `tradingMarketDataRegistry` / `tradingTradeRegistry` под ключом `ru` / `finam`.
- Регистрирует агентские инструменты `ru_get_ticker`, `ru_get_klines`, `ru_get_orderbook`,
  `ru_get_trades`, `ru_list_instruments`, `ru_get_paper_account`.
- Символы: канонический `SECCODE.BOARD` (`SBER.TQBR`); шлюз использует `BOARD:SECCODE`
  (`TQBR:SBER`). Голый `SBER` разрешается в единственный такой `SECCODE`; при нескольких
  площадках предпочитается `TQBR`, иначе `TRADING_UNSUPPORTED_SYMBOL` со списком кандидатов.
- Объёмы: шлюз отдаёт лоты, коннектор переводит в штуки (10 лотов GAZP при лоте 10 =
  `amount: 100`; в демо-снимке SBER=1).
- Ответы несут `source: "live"` или `"seed"` (офлайн-снимок, не реальное время).

## Состав

| Путь | Что |
|---|---|
| `index.js`, `config.js`, `gateway-client.js`, `market-data.js`, `symbols.js`, `tools.js`, `trade.js` | пакет `@dshtrading/ru`: ESM без зависимостей |
| [`package.json`](package.json) | манифест пакета и DSH-bundle (`dsh.bundle.patch`) |
| [`cordis.patch.yml`](cordis.patch.yml) | bundle-патч: вставляет строку `dsh-trading-ru-connector-transaq` |
| [`test/`](test/) | тесты `node:test`, без сети и без Go |
| [`QUICKSTART.md`](QUICKSTART.md) | подключение к DeepSeek Harness Desktop за 5 шагов |
| [`tools/dsh-connector-enable.sh`](tools/dsh-connector-enable.sh) | обёртка над `dsh plugin add` / `remove` |
| [`docs/`](docs/) | исходники сайта GitHub Pages |
| [`docs/migration.md`](docs/migration.md) | происхождение репозитория и сохранённая история |
| [`mkdocs.yml`](mkdocs.yml), [`.github/workflows/pages.yml`](.github/workflows/pages.yml) | сборка и публикация сайта |
| [`.github/workflows/publish.yml`](.github/workflows/publish.yml) | ручная публикация `@dshtrading/ru` в npm |
| [`AGENTS.md`](AGENTS.md) | инструкция для агентов, работающих в репозитории |
| [`LICENSE`](LICENSE) | MIT |

## Где шлюз

Коннектор — только DSH-часть. Read-only шлюз `/api/gw/v1/*` (`bin/terminal`), клиент протокола
TRANSAQ без DLL и контракт шлюза живут в
[`kmlebedev/txmlconnector`](https://github.com/kmlebedev/txmlconnector):
[`docs/ai-terminal/gateway-v1.md`](https://github.com/kmlebedev/txmlconnector/blob/main/docs/ai-terminal/gateway-v1.md),
решение — [ADR](https://github.com/kmlebedev/txmlconnector/blob/main/docs/ai-terminal/adr-dsh-trading.md).
Связь — loopback HTTP + токен `X-Terminal-Token`.

## Требования

Запущенный `bin/terminal` из [txmlconnector](https://github.com/kmlebedev/txmlconnector)
(`make terminal` в его checkout), порт `127.0.0.1:18095` и токен API:

```bash
export TERMINAL_API_TOKEN="$(openssl rand -hex 16)"
bin/terminal -mode offline -addr 127.0.0.1:18095   # или -mode live (нужен доступ к TRANSAQ)
```

Токен на каждый запрос сначала запрашивается у сервиса `credentials` хоста, при его отсутствии
читается из переменной окружения с именем `tokenRef`. Токен не попадает в логи и тексты ошибок.
Переменные `TC_*` / `TRANSAQ_*` коннектор не читает. Порт 18095 выбран потому, что 18090
занят бэкендом плагина AI-терминала, если он включён.

## Установка в DSH

Пакет публикуется как `@dshtrading/ru` и является стандартным DSH-bundle: `package.json`
объявляет `dsh.bundle.patch: ./cordis.patch.yml`, а патч вставляет строку коннектора. Профиль
`trading-web` из dsh-trading уже содержит `@dshtrading/base`; для чистого профиля добавьте его
отдельно — DSH не раскрывает транзитивные bundle-зависимости.

### Из npm

```bash
dsh plugin --profile trading-web add @dshtrading/ru
```

Проверка: `dsh --profile trading-web --dump-config | grep -A6 dsh-trading-ru-connector-transaq`.

### Из локального checkout (Desktop / разработка)

```bash
git clone https://github.com/kmlebedev/dshtrading-connector-transaq.git
cd dshtrading-connector-transaq
dsh plugin --profile desktop add '@dshtrading/base@^0.7.0'   # если base ещё нет
dsh plugin --profile desktop add "file:$PWD"
```

В GUI то же самое делается через `plugin_manager` → `install_bundle` с target — абсолютным
путём к корню репозитория; `@dshtrading/base` установите заранее. Скрипт-обёртка для
автоматизации:

```bash
tools/dsh-connector-enable.sh
```

Он делает бэкап `package.json` и `cordis.patch.yml` профиля, выполняет те же команды
`dsh plugin add` и умеет `--remove`. Порт, имя токена и профиль меняются переменными
`GATEWAY_URL`, `TOKEN_REF`, `PROFILE`, `DSH_HOME` (см. `tools/dsh-connector-enable.sh --help`).
Для профиля dsh-trading используйте `PROFILE=trading-web`.

> **Переход со старой установки.** Прежняя версия ставилась как
> `@local/dshtrading-connector-transaq`, в том числе через `link:` на подкаталог
> `dshtrading-connector-transaq/`. Удалите старую зависимость и строку коннектора из профиля,
> затем установите `@dshtrading/ru`; скрипт-обёртка делает это автоматически, но ставит из
> локального checkout'а (`file:`). Для npm-версии используйте
> `dsh plugin --profile trading-web add @dshtrading/ru` после публикации.

Bundle-патч вставляет строку с настройками по умолчанию:

```yaml
- insert:
    - id: dsh-trading-ru-connector-transaq
      name: '@dshtrading/ru'
      config:
        enabled: true
        gatewayUrl: 'http://127.0.0.1:18095'
        tokenRef: TERMINAL_API_TOKEN
```

Для нестандартных `gatewayUrl` / `tokenRef` добавьте в
`~/.dsh/profiles/desktop/cordis.patch.yml` строку **без** `insert` — она заменит row из
bundle:

```yaml
- id: dsh-trading-ru-connector-transaq
  config:
    enabled: true
    gatewayUrl: 'http://127.0.0.1:18095'
    tokenRef: TERMINAL_API_TOKEN
```

## Публикация

Пакет уже без `private` и с `publishConfig.access: public`:

```bash
npm publish
```

Или вручную запустить workflow **Publish** (Actions → Publish → Run workflow); ему нужен
секрет `NPM_TOKEN` с доступом к scope `@dshtrading`. Scope принадлежит upstream dsh-trading;
без доступа к нему `npm publish` вернёт 403. Пока пакет не опубликован, команда
`dsh plugin --profile trading-web add @dshtrading/ru` даёт 404 — используйте локальный
checkout (`file:$PWD`). После публикации npm-команда работает без checkout'а.

## Конфигурация

| Параметр | По умолчанию | Описание |
|---|---|---|
| `enabled` | `true` | `false` — плагин ничего не регистрирует |
| `gatewayUrl` | `http://127.0.0.1:18095` | только `http://` и loopback (`127.0.0.1`, `localhost`, `[::1]`) |
| `tokenRef` | `TERMINAL_API_TOKEN` | имя переменной окружения или credential-сервиса с токеном шлюза |
| `timeoutMs` | `5000` | таймаут запроса к шлюзу; при превышении `TRADING_NETWORK` |
| `pollMs` | `2000` | период опроса для `subscribeTicker` |

Ошибки: `TRADING_AUTH_FAILED` (неверный токен), `TRADING_NETWORK` (шлюз недоступен),
`TRADING_UNSUPPORTED_SYMBOL`, `TRADING_UPSTREAM_ERROR` (шлюз вернул 5xx или non-JSON).
`subscribeTicker` продолжает опрос и восстанавливается после рестарта шлюза без перезапуска
хоста.

## Ограничения

- Вкладки `ru` в GUI dsh-trading нет, пока апстрим не откроет список рынков (ADR, «Что важно»,
  п. 3): сервис регистрируется, но доступен через агента и API, а не через вкладку.
- Реального размещения заявок нет ни live, ни paper: шлюз v1 только GET. `placeOrder` при
  `dryRun !== false` лишь локально проверяет заявку (кратность лоту, шаг цены, side/type) и
  возвращает синтетический ордер `dry-<uuid>` с `dryRun: true`; `cancelOrder` принимает только
  такие `dry-` id. Ничего не уходит в шлюз, на биржу или в бумажный счёт. `placeOrder` с
  `dryRun: false` всегда отклоняется с `TRADING_LIVE_TRADING_DISABLED`. Инструменты
  `ru_place_order` / `ru_cancel_order` не регистрируются намеренно (approval-gate dsh-trading
  не покрывает `ru`).
- К MOEX агент обращается только через `ru_*`.

## Тесты и приёмка

```bash
make test                  # node --test test/*.test.mjs
```

Офлайн-приёмка (выполнена 2026-11-06): `apply()` с фейковым ctx против `bin/terminal -mode offline`
вернул `SBER.TQBR`, `source: "seed"`, 5 часовых свечей и стакан.

Живая приёмка на демо-сервере TRANSAQ (2026-11-06, PR 67 + ветка `fix/pr-67-blockers`): gateway v1 —
**66/66 PASS**, коннектор против живого шлюза — **42/42 PASS**: `source: "live"`, канонические
символы, `volume = lots*lotSize` (GAZP ровно ×10), `dry-run`, `subscribeTicker`; `/orderbook` после
фикса `terminal/feed` — двусторонний стакан, bids по убыванию / asks по возрастанию.

Приёмка в реальном хосте dsh-trading (npm `@dshtrading/*` 0.6.3, `dsh` 0.2.2-rc.1, 2026-11-06):
**HOST-PASS** — плагин грузится как есть (сервисы `tools`/реестры опциональны и дожидаются
через `ctx.inject`, у 6 инструментов объявлен `output {schema, render}` для dsh-tools 0.2.x);
`ru/finam` регистрируется в обоих реестрах, 6 инструментов доступны, агентский вызов
`ru_get_ticker SBER` вернул `SBER.TQBR` (модель — mock). Вкладки/HTTP-моста `ru` нет: апстрим
отдаёт 400 `unknown market "ru"` (вне scope PR). Полный отчёт:
[`acceptance-pr67-2026-11-06.md`](https://github.com/kmlebedev/txmlconnector/blob/main/docs/ai-terminal/acceptance-pr67-2026-11-06.md).

Стандартная bundle-установка `@dshtrading/ru` проверена 2026-11-09 в изолированных `DSH_HOME`
с `@dshtrading/base@^0.6.3` и `@dshtrading/base@^0.7.0`: `dsh.profile.bundles` содержит
`@dshtrading/base` и `@dshtrading/ru`, `dsh --profile smoke --dump-config` показывает строку
`dsh-trading-ru-connector-transaq`.

## GitHub Pages

Сайт собирается из [`docs/`](docs/) через MkDocs Material:

```bash
make docs        # mkdocs build --strict (нужен mkdocs-material)
make docs-serve  # локальный предпросмотр
```

Workflow [`.github/workflows/pages.yml`](.github/workflows/pages.yml) публикует сайт на
`https://kmlebedev.github.io/dshtrading-connector-transaq/` при push в `main`.

## Лицензии

Код dsh-trading (PolyForm Noncommercial 1.0.0) здесь не копируется и не импортируется:
совместимость только структурная. Хост `@dshtrading/base` ставится пользователем из npm.
Этот репозиторий — [MIT](LICENSE), как и плагин
[dsh-trading-transaq](https://github.com/kmlebedev/dsh-trading-transaq).
