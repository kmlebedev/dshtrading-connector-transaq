# AGENTS.md — dshtrading-connector-transaq

Репозиторий Cordis-коннектора TRANSAQ для хоста dsh-trading в DeepSeek Harness. Документация
и отчёты — русский, код и комментарии — английский (как в исходном `kmlebedev/txmlconnector`).
Этот файл — обязательная инструкция для агентов, работающих в этом репозитории.

## Что здесь

- `dshtrading-connector-transaq/` — единственный runtime-пакет: ESM
  `@local/dshtrading-connector-transaq` без зависимостей (`"dependencies": {}`), тесты `node:test`.
- `tools/dsh-connector-enable.sh` — монтирование в профиль DSH с бэкапом и `--remove`.
- Go-шлюз `/api/gw/v1/*` и его контракт живут в
  [`kmlebedev/txmlconnector`](https://github.com/kmlebedev/txmlconnector); меняя ожидания к
  полям/единицам, сверяйтесь с `docs/ai-terminal/gateway-v1.md` там.

## Проверки перед коммитом

```bash
make test                                  # node --test dshtrading-connector-transaq/test/*.test.mjs
bash -n tools/dsh-connector-enable.sh
git grep -nE 'TC_(PASSWORD|LOGIN)[[:space:]]*=' -- ':!*.md'   # значений секретов быть не должно
```

## Жёсткие правила

- Код dsh-trading (PolyForm Noncommercial) не копировать и не импортировать — ни исходники, ни
  типы; совместимость только структурная.
- Никакой живой торговли: `placeOrder` только dry-run, `dryRun:false` →
  `TRADING_LIVE_TRADING_DISABLED`; не регистрировать `ru_place_order`/`ru_cancel_order`.
- Шлюз — только `http://` loopback; токен не логировать и не включать в тексты ошибок.
- `TC_LOGIN`, `TC_PASSWORD`, номера счетов/клиентов не попадают в репозиторий, тесты, логи и
  коммиты.
- Тесты не ходят в сеть (только loopback-фейки) и не требуют Go/DSH.
- Профиль пользователя `~/.dsh` меняется только по явной просьбе пользователя.
