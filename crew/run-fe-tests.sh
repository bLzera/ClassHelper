#!/usr/bin/env bash
#
# crew/run-fe-tests.sh — roda a suíte Vitest do frontend de forma portável.
#
# Espelha a lógica host-vs-container do run-tests.sh (backend): se `node`/`npm`
# estiverem disponíveis no host, roda direto em frontend/; senão, faz fallback
# para o container Docker `frontend` via `docker compose exec`.
#
# Bootstrap: na primeira execução de uma máquina limpa, `frontend/node_modules`
# não existe (é gitignorado). O script roda `npm ci` automaticamente antes do
# vitest — análogo ao `db:prepare` do backend. Usa o package-lock.json versionado.
#
# Uso: crew/run-fe-tests.sh [argumentos extras para o vitest]
# Saída: repassa o exit code do vitest (0 = passou).
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"

if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
  echo "[run-fe-tests] ambiente: host (node/npm disponíveis)"
  cd "$ROOT/frontend"
  if [ ! -d node_modules ]; then
    echo "[run-fe-tests] node_modules ausente — rodando npm ci..."
    npm ci
  fi
  exec npm run test -- "$@"
else
  echo "[run-fe-tests] ambiente: container Docker frontend (node/npm indisponíveis no host)"
  docker compose -f "$ROOT/docker-compose.yml" exec -T frontend sh -lc \
    "npm run test -- $*"
fi
