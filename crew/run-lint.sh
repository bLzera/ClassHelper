#!/usr/bin/env bash
#
# crew/run-lint.sh — roda o rubocop SOMENTE nos arquivos .rb que o épico tocou.
#
# Por quê só os arquivos do épico: `main` carrega offenses pré-existentes (dívida
# técnica anterior), então exigir "zero offenses no repo" jamais passaria. O gate
# real é "o épico não introduz offenses nos arquivos que altera". Lintamos apenas
# o diff em relação a main; se um épico editar um arquivo já sujo, herda a dívida
# dele (incentivo a limpar de passagem).
#
# Decide host-vs-container do mesmo modo que run-tests.sh.
#
# Detecção de arquivos alterados: o gate roda ANTES do commit do épico, então
# comparar `main...HEAD` daria vazio enquanto a branch não tem commit, e arquivos
# novos ficam untracked. Comparamos a árvore de trabalho com `main` (`git diff
# main`) e unimos os untracked (`git ls-files --others`) — assim o gate enxerga
# tudo que o épico criou ou alterou, commitado ou não.
#
# Uso: crew/run-lint.sh
# Saída: exit code do rubocop (0 = limpo nos arquivos do épico).
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"

# Arquivos .rb alterados pelo épico (working tree vs main + untracked), relativos
# a backend/ (rubocop roda de dentro de backend/).
mapfile -t CHANGED < <(
  {
    git -C "$ROOT" diff --name-only --diff-filter=d main -- backend/
    git -C "$ROOT" ls-files --others --exclude-standard -- backend/
  } | grep -E '\.rb$' | sort -u | sed 's#^backend/##')

if [ "${#CHANGED[@]}" -eq 0 ]; then
  echo "[run-lint] nenhum arquivo .rb alterado pelo épico — nada a lintar."
  exit 0
fi

echo "[run-lint] lintando ${#CHANGED[@]} arquivo(s) do épico:"
printf '  - %s\n' "${CHANGED[@]}"

if command -v bundle >/dev/null 2>&1 && (cd "$ROOT/backend" && bundle check >/dev/null 2>&1); then
  echo "[run-lint] ambiente: host"
  cd "$ROOT/backend"
  exec bundle exec rubocop --force-exclusion "${CHANGED[@]}"
else
  echo "[run-lint] ambiente: container Docker backend"
  docker compose -f "$ROOT/docker-compose.yml" exec -T backend bash -lc \
    "bundle exec rubocop --force-exclusion ${CHANGED[*]}"
fi
