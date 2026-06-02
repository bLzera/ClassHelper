#!/usr/bin/env bash
#
# crew/run-fe-lint.sh — gate de lint do frontend.
#
# Dois passos:
#   1. type-check (`vue-tsc --noEmit`) — roda no projeto inteiro (tsc é global e o
#      grafo de tipos do TS não é particionável por arquivo).
#   2. eslint — roda SOMENTE nos arquivos .ts/.vue que o épico tocou, espelhando
#      run-lint.sh do backend: o gate é "o épico não introduz offenses no que
#      toca", não "zero no repo".
#
# Detecção de arquivos alterados (importante): o gate roda ANTES do commit do
# épico (Passo 4 do orchestrator), então comparar `main...HEAD` daria vazio
# enquanto a branch ainda não tem commit — e arquivos novos ficam untracked. Por
# isso comparamos a árvore de trabalho com `main` (`git diff main`, pega
# modificados/staged) e UNIMOS os arquivos untracked (`git ls-files --others`).
# Assim o gate enxerga tudo que o épico criou ou alterou, commitado ou não.
#
# Se nenhum arquivo de frontend mudou, sai 0 (nada a checar).
# Mesma detecção host-vs-container e bootstrap (npm ci) do run-fe-tests.sh.
#
# Uso: crew/run-fe-lint.sh
# Saída: exit code combinado (0 = limpo).
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"

# Arquivos .ts/.vue do frontend alterados pelo épico (working tree vs main +
# untracked), relativos a frontend/ (eslint roda de dentro de frontend/).
mapfile -t CHANGED < <(
  {
    git -C "$ROOT" diff --name-only --diff-filter=d main -- frontend/
    git -C "$ROOT" ls-files --others --exclude-standard -- frontend/
  } | grep -E '\.(ts|vue)$' | sort -u | sed 's#^frontend/##'
)

if [ "${#CHANGED[@]}" -eq 0 ]; then
  echo "[run-fe-lint] nenhum arquivo .ts/.vue de frontend alterado pelo épico — nada a checar."
  exit 0
fi

echo "[run-fe-lint] checando ${#CHANGED[@]} arquivo(s) do épico:"
printf '  - %s\n' "${CHANGED[@]}"

if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
  echo "[run-fe-lint] ambiente: host (node/npm disponíveis)"
  cd "$ROOT/frontend"
  if [ ! -d node_modules ]; then
    echo "[run-fe-lint] node_modules ausente — rodando npm ci..."
    npm ci
  fi
  npm run type-check
  exec npx eslint "${CHANGED[@]}"
else
  echo "[run-fe-lint] ambiente: container Docker frontend (node/npm indisponíveis no host)"
  docker compose -f "$ROOT/docker-compose.yml" exec -T frontend sh -lc \
    "npm run type-check && npx eslint ${CHANGED[*]}"
fi
