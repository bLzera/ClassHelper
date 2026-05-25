#!/usr/bin/env bash
#
# crew/run-tests.sh — roda a suíte rspec do backend de forma portável.
#
# Decide automaticamente entre rodar no host (se o bundle local estiver íntegro)
# ou dentro do container Docker `backend` (fallback). Cuida do setup idempotente
# do banco de teste (db:prepare) antes de rodar.
#
# Uso: crew/run-tests.sh [argumentos extras para o rspec]
#   ex: crew/run-tests.sh --format documentation
#       crew/run-tests.sh spec/requests/assignments_spec.rb
#
# Saída: repassa o exit code do rspec (0 = passou).
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
HOST_DB_URL="postgresql://classhelper:changeme@localhost:5433/classhelper_test"
DOCKER_DB_URL="postgresql://classhelper:changeme@db:5432/classhelper_test"

if command -v bundle >/dev/null 2>&1 && (cd "$ROOT/backend" && bundle check >/dev/null 2>&1); then
  echo "[run-tests] ambiente: host (bundle local íntegro)"
  cd "$ROOT/backend"
  TEST_DATABASE_URL="$HOST_DB_URL" RAILS_ENV=test bundle exec rails db:prepare
  exec env TEST_DATABASE_URL="$HOST_DB_URL" RAILS_ENV=test bundle exec rspec "$@"
else
  echo "[run-tests] ambiente: container Docker backend (bundle local indisponível/incompleto)"
  docker compose -f "$ROOT/docker-compose.yml" exec -T backend bash -lc \
    "TEST_DATABASE_URL='$DOCKER_DB_URL' RAILS_ENV=test bundle exec rails db:prepare && \
     TEST_DATABASE_URL='$DOCKER_DB_URL' RAILS_ENV=test bundle exec rspec $*"
fi
