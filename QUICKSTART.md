# Quick start: коннектор TRANSAQ в DeepSeek Harness

Как за 5 шагов подключить `@dshtrading/ru` к DeepSeek Harness (DSH) Desktop или к профилю
`trading-web`, чтобы агент видел MOEX через инструменты `ru_*`. Подробности о коннекторе — в
[README](README.md), контракт шлюза — в
[gateway-v1.md](https://github.com/kmlebedev/txmlconnector/blob/main/docs/ai-terminal/gateway-v1.md).
Веб-версия этой инструкции — на
[GitHub Pages](https://kmlebedev.github.io/dshtrading-connector-transaq/).

Схема: `bin/terminal` (Go, TRANSAQ) отдаёт read-only шлюз `/api/gw/v1/*` на loopback, а
коннектор в профиле Desktop (`~/.dsh/profiles/desktop`) регистрирует рынок `ru` / провайдер
`finam` в реестрах хоста dsh-trading (`@dshtrading/base`) и 6 инструментов агента. Заявки только
dry-run, реальной торговли нет.

## Требования

- macOS, DeepSeek Harness Desktop **0.2.2-rc.1** (`dsh --version`), Go 1.27+, `openssl`.
- Два checkout'а рядом: этот репозиторий (коннектор) и
  [kmlebedev/txmlconnector](https://github.com/kmlebedev/txmlconnector) (Go-шлюз `bin/terminal`):

  ```bash
  git clone https://github.com/kmlebedev/dshtrading-connector-transaq.git
  git clone https://github.com/kmlebedev/txmlconnector.git
  cd dshtrading-connector-transaq        # команды ниже — из корня этого репозитория
  ```
- Доступ к npm: пакет `@dshtrading/ru` и, для чистого профиля, хост `@dshtrading/base`
  (пакеты dsh-trading распространяются под PolyForm Noncommercial 1.0.0; сам коннектор их код
  не содержит). В профиле `trading-web` `@dshtrading/base` уже установлен.
- Порт **18095** свободен. 18090 занят бэкендом плагина AI-терминала, если он включён; у того
  бэкенда свой случайный токен, поэтому коннектору нужен отдельный `bin/terminal`.

## 1. Токен шлюза

Один токен на шлюз и на приложение; хранится в файле с правами 600, в чат и логи не попадает:

```bash
mkdir -p ~/.config/txmlconnector
[ -s ~/.config/txmlconnector/gateway-token ] || (umask 077; openssl rand -hex 16 > ~/.config/txmlconnector/gateway-token)
```

## 2. Шлюз

```bash
make -C ../txmlconnector terminal
TERMINAL_API_TOKEN="$(cat ~/.config/txmlconnector/gateway-token)" \
  ../txmlconnector/bin/terminal -mode offline -addr 127.0.0.1:18095 -llm off
```

`-mode offline` — встроенный снимок демо-данных (`source: "seed"`). Для живых котировок —
`-mode live` с `TRANSAQ_*`/`TC_*` в окружении (см. [docs/ai-terminal/README.md](https://github.com/kmlebedev/txmlconnector/blob/main/docs/ai-terminal/README.md));
коннектор эти переменные не читает. Окно терминала со шлюзом оставьте открытым.

Проверка в другом окне:

```bash
curl -s -H "X-Terminal-Token: $(cat ~/.config/txmlconnector/gateway-token)" http://127.0.0.1:18095/api/gw/v1/info
```

Ожидается JSON с `"market":"ru","provider":"finam"`.

## 3. Установка в профиль

Коннектор подготовлен для публикации как `@dshtrading/ru` и является стандартным DSH-bundle:
корневой `package.json` объявляет `dsh.bundle.patch: ./cordis.patch.yml`, поэтому штатная
установка сама добавляет его в `dsh.profile.bundles` и вставляет строку в профиль. Пока пакет
не опубликован в npm (нужен доступ к scope `@dshtrading`), используйте локальный checkout
(`file:$PWD`).

### Штатно в dsh-trading (trading-web)

Профиль `trading-web` уже содержит `@dshtrading/base`:

```bash
dsh plugin --profile trading-web add @dshtrading/ru
```

Проверка: `dsh --profile trading-web --dump-config | grep -A6 dsh-trading-ru-connector-transaq`.

### Локальный checkout (DSH Desktop / разработка)

Закройте DSH Desktop. Сначала поставьте хост `@dshtrading/base`, если его ещё нет: DSH не
раскрывает транзитивные bundle-зависимости.

#### Вариант 1: CLI

```bash
dsh plugin --profile desktop add '@dshtrading/base@^0.7.0'
dsh plugin --profile desktop add "file:$PWD"
```

`$PWD` — корень этого репозитория. Отдельно править YAML не нужно.

#### Вариант 2: GUI

В DSH-сессии откройте `plugin_manager` → `install_bundle` и укажите target — абсолютный путь
к корню этого репозитория. `@dshtrading/base` установите тем же способом или командой CLI
из варианта 1.

#### Вариант 3: скрипт-обёртка

```bash
tools/dsh-connector-enable.sh
```

Скрипт делает бэкап `package.json` и `cordis.patch.yml` профиля рядом с ними
(`*.connector-<время>`), выполняет те же две команды `dsh plugin add` (из локального
checkout'а, `file:`) и умеет `--remove`. Порт, имя токена и профиль меняются переменными
`GATEWAY_URL`, `TOKEN_REF`, `PROFILE`, `DSH_HOME` (см. `tools/dsh-connector-enable.sh --help`).
Для dsh-trading используйте `PROFILE=trading-web`.

> **Переход со старой установки.** Прежняя версия ставилась как
> `@local/dshtrading-connector-transaq`, в том числе через `link:` на подкаталог
> `dshtrading-connector-transaq/`. Удалите старую зависимость и строку коннектора из профиля,
> затем установите `@dshtrading/ru`; скрипт-обёртка делает это автоматически.

### Что появляется в профиле

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

> **Для профиля `trading-web`.** Шаги 4–5 относятся к DSH Desktop. В `trading-web` токен
> передаётся окружением или credential-сервисом хоста; после `dsh plugin add` перезапустите
> `dsh --profile trading-web`.

## 4. Токен для приложения

Desktop, запущенный из Dock или Finder, не видит переменных вашего shell. Коннектор на каждый
запрос сначала спрашивает сервис `credentials` хоста, а затем переменную окружения
`TERMINAL_API_TOKEN`. Проще всего отдать её через launchd:

```bash
launchctl setenv TERMINAL_API_TOKEN "$(cat ~/.config/txmlconnector/gateway-token)"
```

Значение живёт до перезагрузки macOS; после перезагрузки повторите команду до запуска DSH.

## 5. Перезапуск и проверка

```bash
osascript -e 'quit app "DeepSeek Harness"'; open -a "DeepSeek Harness"
```

В новом чате попросите агента: «Вызови ru_get_ticker для SBER». Ожидается ответ с
`"symbol": "SBER.TQBR"` и `"source": "seed"` (или `"live"` в живом режиме). Другие
инструменты: `ru_get_klines`, `ru_get_orderbook`, `ru_get_trades`, `ru_list_instruments`,
`ru_get_paper_account`.

## Если что-то не так

| Симптом | Причина и что делать |
|---|---|
| Агент не видит `ru_*` | Проверьте `dsh plugin --profile desktop list` и `dsh --profile desktop --dump-config`; убедитесь, что установлены и `@dshtrading/base`, и коннектор, затем перезапустите приложение |
| `TRADING_AUTH_FAILED` | Токен приложения не совпадает с токеном шлюза: повторите шаг 4 и перезапустите DSH; шлюз запускайте из того же файла токена |
| `TRADING_NETWORK` | Шлюз не запущен или не на 18095: шаг 2, проверка `curl` |
| `TRADING_SYMBOL_NOT_FOUND` | Инструмента нет в universe шлюза: `ru_list_instruments` покажет доступные |
| `TRADING_LIVE_TRADING_DISABLED` | Попытка `dryRun: false`; живая торговля отключена намеренно |
| DSH не стартует после установки | Удалите коннектор: `dsh plugin --profile desktop remove @dshtrading/ru`; при ручной правке восстановите `package.json` / `cordis.patch.yml` из бэкапа или выполните `tools/dsh-connector-enable.sh --remove` |
| Строка коннектора задвоилась | Не добавляйте `insert` с тем же id вручную; для нестандартных настроек используйте replace-строку без `insert` |

Отключить коннектор: `dsh plugin --profile desktop remove @dshtrading/ru`
(или `tools/dsh-connector-enable.sh --remove`), затем перезапуск DSH. Хост `@dshtrading/base`
при этом остаётся установленным; убрать его — `dsh plugin --profile desktop remove @dshtrading/base`.

## Ограничения

- Вкладки MOEX в интерфейсе нет: апстрим dsh-trading держит закрытый список рынков. Данные
  доступны агенту через `ru_*`.
- Хост `@dshtrading/base` добавляет в Desktop свои роли, пресеты и инструменты других рынков
  (крипто, US, CN, HK). Если это мешает основному профилю, подключайте коннектор к отдельному
  профилю: `PROFILE=trading-web tools/dsh-connector-enable.sh` и запуск
  `dsh --profile trading-web` (web UI в браузере); профиль `desktop` CLI запускать не даёт, он
  принадлежит приложению.

## Что проверено

- 2026-11-09: старая версия `tools/dsh-connector-enable.sh` (монтирование `link:` и ручная
  строка в профиле) на изолированной копии профиля (`DSH_HOME` во временном каталоге, пакеты
  dsh-trading 0.6.3, dsh 0.2.2-rc.1) — строка и `link:` добавлены, повторный запуск строку не
  дублирует. Хост, запущенный из этого профиля против `bin/terminal -mode offline` на 18095,
  зарегистрировал `ru/finam` в `tradingMarketDataRegistry` и `tradingTradeRegistry`, все 6
  инструментов `ru_*` доступны.
- 2026-11-09: стандартная bundle-установка `@dshtrading/ru` в изолированных `DSH_HOME`
  (`@dshtrading/base@^0.6.3` и `@dshtrading/base@^0.7.0`, `file:$PWD`) — pnpm поставил оба
  пакета, `dsh.profile.bundles` содержит `@dshtrading/base` и `@dshtrading/ru`,
  `dsh --profile smoke --dump-config` показывает строку `dsh-trading-ru-connector-transaq`
  с `gatewayUrl: http://127.0.0.1:18095`.
- 2026-11-06: агентский вызов `ru_get_ticker SBER` → `SBER.TQBR` в реальном хосте dsh-trading
  ([приёмка](https://github.com/kmlebedev/txmlconnector/blob/main/docs/ai-terminal/acceptance-pr67-2026-11-06.md)).
- **Не проверено:** сам профиль `desktop` приложения, передача токена через `launchctl setenv`
  и установка через GUI `plugin_manager`; CLI-путь `dsh plugin add` проверен smoke-тестом из
  локального checkout'а. Установка из npm (`dsh plugin add @dshtrading/ru`) не проверена, пока
  пакет не опубликован и нет доступа к scope `@dshtrading`.
