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

- Раскладка — monorepo-стиль, как в dsh-trading-transaq: пакет сохраняет путь
  `dshtrading-connector-transaq/`, скрипт — `tools/`, поэтому `tools/dsh-connector-enable.sh`
  работает без правок (находит пакет рядом с собой).
- Имя пакета `@local/dshtrading-connector-transaq` и row id `dsh-trading-ru-connector-transaq`
  не менялись — профили DSH остаются совместимыми.
- Лицензия — решение владельца, пока не выбрана.

## Проверки

- `make test` — 43/43 (Node v26.12.0), до и после правки документов;
- `bash -n tools/dsh-connector-enable.sh` — ok.
