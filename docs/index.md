# Коннектор TRANSAQ для DeepSeek Harness

`dshtrading-connector-transaq` — Cordis-плагин, который подключает рынок MOEX
(Finam/TRANSAQ) к хосту [dsh-trading](https://github.com/zhu1090093659/dsh-trading)
в DeepSeek Harness Desktop. Плагин регистрирует рынок `ru` / провайдер `finam` в реестрах
хоста и даёт агенту шесть read-only инструментов `ru_*`: тикер, свечи, стакан, лента,
список инструментов и бумажный счёт.

!!! note "Только чтение"
    Коннектор не размещает заявки и не меняет бумажный счёт. `placeOrder` работает только
    в dry-run, `dryRun: false` отклоняется с `TRADING_LIVE_TRADING_DISABLED`. Инструменты
    `ru_place_order` / `ru_cancel_order` намеренно не регистрируются.

## Что подключается

```text
DeepSeek Harness Desktop
  → @dshtrading/ru (Cordis-плагин)
  → http://127.0.0.1:18095/api/gw/v1/* (loopback, X-Terminal-Token)
  → bin/terminal (Go-шлюз, TRANSAQ)
  → MOEX
```

Go-шлюз `bin/terminal` и контракт `/api/gw/v1/*` живут в
[`kmlebedev/txmlconnector`](https://github.com/kmlebedev/txmlconnector). Коннектор — только
DSH-часть: он не читает `TC_*` / `TRANSAQ_*` и не ходит в сеть, кроме loopback-шлюза.

Ответы инструментов несут поле `source`:

- `live` — живые данные шлюза;
- `seed` — встроенный офлайн-снимок демо-данных, не реальное время.

## Что умеет

| Инструмент | Что возвращает |
|---|---|
| `ru_get_ticker` | Последняя котировка MOEX: цена в RUB, объём в штуках |
| `ru_get_klines` | OHLCV-свечи: интервал (`1m`, `1d`, …), число последних баров |
| `ru_get_orderbook` | Стакан: bids и asks, цена в RUB, объём в штуках |
| `ru_get_trades` | Последние сделки MOEX |
| `ru_list_instruments` | Список инструментов, фильтр по символу или названию, до 200 строк |
| `ru_get_paper_account` | Бумажный счёт: балансы, позиции, открытые заявки, сделки |

Символы принимаются в каноническом виде `SECCODE.BOARD` (`SBER.TQBR`); голый `SBER`
разрешается в единственный инструмент, при нескольких площадках предпочитается `TQBR`.
Шлюз использует обратный порядок `BOARD:SECCODE` (`TQBR:SBER`) — это внутренняя деталь
коннектора.

## Требования

- macOS, DeepSeek Harness Desktop **0.2.2-rc.1** (`dsh --version`), Go 1.27+, `openssl`.
- Два checkout'а рядом: этот репозиторий и
  [`kmlebedev/txmlconnector`](https://github.com/kmlebedev/txmlconnector) (Go-шлюз
  `bin/terminal`).
- Доступ к npm: пакет `@dshtrading/ru` и, для чистого профиля, хост `@dshtrading/base`.
  В профиле `trading-web` `@dshtrading/base` уже установлен.
  Пакеты dsh-trading распространяются под PolyForm Noncommercial 1.0.0; код коннектора их
  не содержит и не импортирует.
- Порт **18095** свободен. Порт 18090 занят бэкендом плагина AI-терминала, если он включён;
  у того бэкенда свой токен, поэтому коннектору нужен отдельный `bin/terminal`.

## Быстрый старт

### 1. Токен шлюза

Один токен на шлюз и на приложение. Он хранится в файле с правами 600 и не попадает в чат
и логи:

```bash
mkdir -p ~/.config/txmlconnector
[ -s ~/.config/txmlconnector/gateway-token ] || (umask 077; openssl rand -hex 16 > ~/.config/txmlconnector/gateway-token)
```

### 2. Шлюз

```bash
make -C ../txmlconnector terminal
TERMINAL_API_TOKEN="$(cat ~/.config/txmlconnector/gateway-token)" \
  ../txmlconnector/bin/terminal -mode offline -addr 127.0.0.1:18095 -llm off
```

`-mode offline` — встроенный снимок демо-данных (`source: "seed"`). Для живых котировок
запустите `-mode live` с `TRANSAQ_*` / `TC_*` в окружении (см.
[документацию txmlconnector](https://github.com/kmlebedev/txmlconnector/blob/main/docs/ai-terminal/README.md)).
Коннектор эти переменные не читает. Окно терминала со шлюзом оставьте открытым.

Проверка в другом окне:

```bash
curl -s -H "X-Terminal-Token: $(cat ~/.config/txmlconnector/gateway-token)" \
  http://127.0.0.1:18095/api/gw/v1/info
```

Ожидается JSON с `"market": "ru"` и `"provider": "finam"`.

### 3. Установка в профиль

Коннектор подготовлен для публикации как `@dshtrading/ru` и является стандартным DSH-bundle:
корневой `package.json` объявляет `dsh.bundle.patch: ./cordis.patch.yml`, поэтому штатная
установка сама добавляет его в `dsh.profile.bundles` и вставляет строку в профиль. Пока пакет
не опубликован, используйте локальный checkout (`file:$PWD`).

#### Штатно в dsh-trading (trading-web)

Профиль `trading-web` уже содержит `@dshtrading/base`:

```bash
dsh plugin --profile trading-web add @dshtrading/ru
```

Проверка: `dsh --profile trading-web --dump-config | grep -A6 dsh-trading-ru-connector-transaq`.

!!! note "Публикация"
    Пакет уже без `private` и с `publishConfig.access: public`; публикация —
    `npm publish` или ручной workflow **Publish** с секретом `NPM_TOKEN`.
    Scope `@dshtrading` принадлежит upstream dsh-trading; без доступа к нему publish вернёт
    403, а пока пакет не опубликован, npm-команда даёт 404 — используйте `file:$PWD`.

#### Локальный checkout (DSH Desktop / разработка)

Закройте DSH Desktop. Сначала поставьте хост `@dshtrading/base`, если его ещё нет: DSH не
раскрывает транзитивные bundle-зависимости.

##### Вариант 1: CLI

```bash
dsh plugin --profile desktop add '@dshtrading/base@^0.7.0'
dsh plugin --profile desktop add "file:$PWD"
```

`$PWD` — корень этого репозитория. Вторая команда автоматически добавляет bundle в
`dsh.profile.bundles` и вставляет строку `dsh-trading-ru-connector-transaq` в профиль.
Отдельно править YAML не нужно.

##### Вариант 2: GUI

В DSH-сессии откройте `plugin_manager` → `install_bundle` и укажите target — абсолютный путь
к корню этого репозитория. `@dshtrading/base` установите тем же способом или командой CLI
из варианта 1.

##### Вариант 3: скрипт-обёртка

```bash
tools/dsh-connector-enable.sh
```

Скрипт делает бэкап `package.json` и `cordis.patch.yml` профиля, выполняет те же две команды
`dsh plugin add` (из локального checkout'а, `file:`) и умеет `--remove`. Он полезен для
автоматизации, но не заменяет штатный bundle-путь. Порт, имя токена и профиль меняются
переменными `GATEWAY_URL`, `TOKEN_REF`, `PROFILE`, `DSH_HOME`
(см. `tools/dsh-connector-enable.sh --help`). Для dsh-trading используйте
`PROFILE=trading-web`.

!!! note "Переход со старой установки"
    Прежняя версия ставилась как `@local/dshtrading-connector-transaq`, в том числе через
    `link:` на подкаталог `dshtrading-connector-transaq/`. Удалите старую зависимость и строку
    коннектора из профиля, затем установите `@dshtrading/ru`; скрипт-обёртка делает это
    автоматически, но ставит из локального checkout'а (`file:`). Для npm-версии используйте
    `dsh plugin --profile trading-web add @dshtrading/ru` после публикации.

#### Что попадает в профиль

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

Если нужны другой порт или имя токена, добавьте в
`~/.dsh/profiles/desktop/cordis.patch.yml` строку **без** `insert` — она заменит row из
bundle:

```yaml
- id: dsh-trading-ru-connector-transaq
  config:
    enabled: true
    gatewayUrl: 'http://127.0.0.1:18095'
    tokenRef: TERMINAL_API_TOKEN
```

Не добавляйте вторую `insert`-строку с тем же id: получится дубликат row id, и DSH не
запустится.

### 4. Токен для приложения

Desktop, запущенный из Dock или Finder, не видит переменных вашего shell. Коннектор на каждый
запрос сначала спрашивает сервис `credentials` хоста, а затем читает переменную окружения
`tokenRef`. Проще всего отдать токен через launchd:

```bash
launchctl setenv TERMINAL_API_TOKEN "$(cat ~/.config/txmlconnector/gateway-token)"
```

Значение живёт до перезагрузки macOS; после перезагрузки повторите команду до запуска DSH.

### 5. Перезапуск и проверка

```bash
osascript -e 'quit app "DeepSeek Harness"'; open -a "DeepSeek Harness"
```

В новом чате попросите агента: «Вызови `ru_get_ticker` для SBER». Ожидается ответ с
`"symbol": "SBER.TQBR"` и `"source": "seed"` (или `"live"` в живом режиме).

Другие инструменты: `ru_get_klines`, `ru_get_orderbook`, `ru_get_trades`,
`ru_list_instruments`, `ru_get_paper_account`.

## Конфигурация

| Параметр | По умолчанию | Описание |
|---|---|---|
| `enabled` | `true` | `false` — плагин ничего не регистрирует |
| `gatewayUrl` | `http://127.0.0.1:18095` | только `http://` и loopback (`127.0.0.1`, `localhost`, `[::1]`) |
| `tokenRef` | `TERMINAL_API_TOKEN` | имя переменной окружения или credential-сервиса с токеном шлюза |
| `timeoutMs` | `5000` | таймаут запроса к шлюзу; при превышении — `TRADING_NETWORK` |
| `pollMs` | `2000` | период опроса для `subscribeTicker` |

Токен не попадает в логи и тексты ошибок. Переменные `TC_*` / `TRANSAQ_*` коннектор не читает.

## Диагностика

| Симптом | Причина и что делать |
|---|---|
| Агент не видит `ru_*` | Проверьте `dsh plugin --profile desktop list` и `dsh --profile desktop --dump-config`; убедитесь, что установлены и `@dshtrading/base`, и коннектор, затем перезапустите DSH |
| `TRADING_AUTH_FAILED` | Токен приложения не совпадает с токеном шлюза: повторите шаг 4, перезапустите DSH; шлюз запускайте из того же файла токена |
| `TRADING_NETWORK` | Шлюз не запущен или слушает не 18095: шаг 2, проверка `curl` |
| `TRADING_SYMBOL_NOT_FOUND` | Инструмента нет в universe шлюза: `ru_list_instruments` покажет доступные |
| `TRADING_UNSUPPORTED_SYMBOL` | Символ неоднозначен или площадка не поддержана: используйте канонический `SECCODE.BOARD` |
| `TRADING_UPSTREAM_ERROR` | Шлюз вернул 5xx или non-JSON: проверьте `bin/terminal` и его лог |
| `TRADING_LIVE_TRADING_DISABLED` | Попытка `dryRun: false`; живая торговля отключена намеренно |
| DSH не стартует после установки | Удалите коннектор: `dsh plugin --profile desktop remove @dshtrading/ru`; при ручной правке восстановите `package.json` / `cordis.patch.yml` из бэкапа или выполните `tools/dsh-connector-enable.sh --remove` |
| Строка коннектора задвоилась | Не добавляйте `insert` с тем же id вручную; для нестандартных настроек используйте replace-строку без `insert` |

## Ограничения

- Вкладки MOEX в интерфейсе DSH нет: апстрим dsh-trading держит закрытый список рынков.
  Данные доступны агенту через `ru_*`.
- Реального размещения заявок нет ни в live, ни в paper: шлюз v1 только GET. `placeOrder`
  при `dryRun !== false` локально проверяет заявку и возвращает синтетический ордер
  `dry-<uuid>`; `cancelOrder` принимает только такие id. `dryRun: false` всегда отклоняется.
- `@dshtrading/base` добавляет в Desktop свои роли, пресеты и инструменты других рынков
  (крипто, US, CN, HK). Если это мешает основному профилю, подключите коннектор к отдельному
  профилю: `PROFILE=trading-web tools/dsh-connector-enable.sh` и запуск
  `dsh --profile trading-web` (web UI в браузере). Профиль `desktop` CLI запускать не даёт,
  он принадлежит приложению.
- Шлюз — только `http://` loopback. Токен не логируется и не включается в тексты ошибок.

## Что проверено

- **2026-11-09**: старая версия `tools/dsh-connector-enable.sh` (монтирование `link:` и ручная
  строка в профиле) на изолированной копии профиля (`DSH_HOME` во временном каталоге, пакеты
  dsh-trading 0.6.3, dsh 0.2.2-rc.1) — строка и `link:` добавлены, повторный запуск строку не
  дублирует. Хост, запущенный из этого профиля против `bin/terminal -mode offline` на 18095,
  зарегистрировал `ru/finam` в `tradingMarketDataRegistry` и `tradingTradeRegistry`, все 6
  инструментов `ru_*` доступны.
- **2026-11-09**: стандартная bundle-установка `@dshtrading/ru` в изолированных `DSH_HOME`
  (`@dshtrading/base@^0.6.3` и `@dshtrading/base@^0.7.0`, `file:$PWD`) — pnpm поставил оба
  пакета, `dsh.profile.bundles` содержит `@dshtrading/base` и `@dshtrading/ru`,
  `dsh --profile smoke --dump-config` показывает строку `dsh-trading-ru-connector-transaq`
  с `gatewayUrl: http://127.0.0.1:18095`.
- **2026-11-06**: агентский вызов `ru_get_ticker SBER` → `SBER.TQBR` в реальном хосте
  dsh-trading ([приёмка](https://github.com/kmlebedev/txmlconnector/blob/main/docs/ai-terminal/acceptance-pr67-2026-11-06.md)).
- **2026-11-06**: живая приёмка на демо-сервере TRANSAQ — gateway v1 66/66 PASS, коннектор
  42/42 PASS: `source: "live"`, канонические символы, `volume = lots * lotSize`, dry-run,
  `subscribeTicker`, двусторонний стакан.
- **Не проверено**: сам профиль `desktop` приложения, передача токена через `launchctl setenv`
  и установка через GUI `plugin_manager`; CLI-путь `dsh plugin add` проверен smoke-тестом из
  локального checkout'а. Установка из npm (`dsh plugin add @dshtrading/ru`) не проверена, пока
  пакет не опубликован и нет доступа к scope `@dshtrading`.

## Структура репозитория

| Путь | Что |
|---|---|
| `index.js`, `config.js`, `gateway-client.js`, `market-data.js`, `symbols.js`, `tools.js`, `trade.js` | Runtime-код пакета `@dshtrading/ru` |
| `package.json` | Манифест пакета и DSH-bundle (`dsh.bundle.patch`) |
| `cordis.patch.yml` | Bundle-патч: вставляет строку `dsh-trading-ru-connector-transaq` |
| `test/` | Тесты `node:test`, без сети и без Go |
| `docs/` | Исходники этого сайта GitHub Pages |
| `tools/dsh-connector-enable.sh` | Обёртка над `dsh plugin add` / `remove` |
| `QUICKSTART.md` | Текстовая версия быстрого старта |
| `README.md` | Обзор, установка, конфигурация, ограничения |
| `AGENTS.md` | Инструкция для агентов, работающих в репозитории |
| `mkdocs.yml`, `.github/workflows/pages.yml` | Сборка и публикация сайта |
| `.github/workflows/publish.yml` | Ручная публикация `@dshtrading/ru` в npm |
| `docs/migration.md` | Происхождение репозитория и сохранённая история |

## Ссылки

- [README репозитория](https://github.com/kmlebedev/dshtrading-connector-transaq/blob/main/README.md)
- [QUICKSTART.md](https://github.com/kmlebedev/dshtrading-connector-transaq/blob/main/QUICKSTART.md)
- [Контракт шлюза gateway-v1.md](https://github.com/kmlebedev/txmlconnector/blob/main/docs/ai-terminal/gateway-v1.md)
- [ADR dsh-trading](https://github.com/kmlebedev/txmlconnector/blob/main/docs/ai-terminal/adr-dsh-trading.md)
- [Go-шлюз txmlconnector](https://github.com/kmlebedev/txmlconnector)
- [Хост dsh-trading](https://github.com/zhu1090093659/dsh-trading)
- [Происхождение репозитория](migration.md)
- [Лицензия MIT](https://github.com/kmlebedev/dshtrading-connector-transaq/blob/main/LICENSE)
