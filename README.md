# dshtrading-connector-transaq — коннектор TRANSAQ для DeepSeek Harness

Cordis-плагин, который подключает рынок MOEX (Finam/TRANSAQ) к хосту
[dsh-trading](https://github.com/zhu1090093659/dsh-trading) в DeepSeek Harness: регистрирует
рынок `ru` / провайдер `finam` в реестрах хоста и даёт агенту 6 read-only инструментов `ru_*`
(тикер, свечи, стакан, лента, инструменты, бумажный счёт). Заявки только dry-run, реальной
торговли нет.

## Состав

| Путь | Что |
|---|---|
| [`dshtrading-connector-transaq/`](dshtrading-connector-transaq/README.md) | пакет `@local/dshtrading-connector-transaq`: ESM без зависимостей, тесты `node:test` |
| [`dshtrading-connector-transaq/QUICKSTART.md`](dshtrading-connector-transaq/QUICKSTART.md) | подключение к DeepSeek Harness Desktop за 5 шагов |
| [`tools/dsh-connector-enable.sh`](tools/dsh-connector-enable.sh) | монтирует коннектор в профиль DSH (по умолчанию `desktop`), `--remove` — откат |
| [`docs/migration.md`](docs/migration.md) | происхождение репозитория и сохранённая история |

## Где шлюз

Коннектор — только DSH-часть. Read-only шлюз `/api/gw/v1/*` (`bin/terminal`), клиент протокола
TRANSAQ без DLL и контракт шлюза живут в
[`kmlebedev/txmlconnector`](https://github.com/kmlebedev/txmlconnector):
[`docs/ai-terminal/gateway-v1.md`](https://github.com/kmlebedev/txmlconnector/blob/main/docs/ai-terminal/gateway-v1.md),
решение — [ADR](https://github.com/kmlebedev/txmlconnector/blob/main/docs/ai-terminal/adr-dsh-trading.md).
Связь — loopback HTTP + токен `X-Terminal-Token`.

## Быстрый старт

```bash
git clone https://github.com/kmlebedev/dshtrading-connector-transaq.git
git clone https://github.com/kmlebedev/txmlconnector.git
cd dshtrading-connector-transaq
make test
```

Дальше — [QUICKSTART.md](dshtrading-connector-transaq/QUICKSTART.md): токен, шлюз на
`127.0.0.1:18095`, `tools/dsh-connector-enable.sh`, перезапуск DSH.

## Лицензии

Код dsh-trading (PolyForm Noncommercial 1.0.0) здесь не копируется и не импортируется:
совместимость только структурная. Хост `@dshtrading/base` ставится пользователем из npm.
Лицензия этого репозитория пока не выбрана (`"license": "UNLICENSED"` в `package.json`).
