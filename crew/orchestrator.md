# Protocolo do Orquestrador — ClassHelper Crew

Quando o usuário pedir "implementa o épico X", execute os passos abaixo em ordem.

---

## Pré-condições

Antes de começar, verificar (preflight):

1. **Resolver a raiz do projeto de forma portável.** Nunca use paths absolutos hard-coded — o repositório vive em máquinas diferentes. Sempre derive a raiz com:
   ```bash
   ROOT="$(git rev-parse --show-toplevel)"
   ```
   Se o comando falhar (não estamos num repositório git), **aborte** e reporte ao usuário. Todos os comandos abaixo usam `"$ROOT/..."`.
2. Sanidade do checkout: `test -d "$ROOT/backend" && test -f "$ROOT/CLAUDE.md"` — se falhar, aborte (estrutura inesperada).
3. Containers Docker no ar: `docker compose up -d` (rodar a partir de `"$ROOT"`). Subir `db` **e** `backend` — quando o bundle local não está íntegro, `run-tests.sh`/`run-lint.sh` (Passos 3 e 4) executam dentro do container `backend` via `docker compose exec`.
4. Branch atual é `main` e está limpa (`git status`)

---

## Passo 1 — Carregar contexto

1. Ler `crew/epics/<X>.md` (spec completa do épico)
2. Ler todos os arquivos listados na seção "Arquivos a ler" do epic file
3. Criar a branch do épico:
   ```bash
   git checkout -b epic/<X>
   ```

---

## Passo 2 — Spawnar Developer Agent

Construir o prompt preenchendo `crew/prompts/developer.md` com os valores do épico:
- `{{EPIC_ID}}` → ex: `C-1`
- `{{EPIC_SPEC}}` → spec do endpoint do epic file
- `{{FILES_TO_READ}}` → **apenas a lista de paths** do epic file (não cole o conteúdo — o Developer Agent abre cada arquivo com `Read` por conta própria)
- `{{FILES_TO_CREATE_OR_MODIFY}}` → lista do epic file
- `{{ACCEPTANCE_CRITERIA}}` → critérios do epic file
- `{{RETRY_CONTEXT}}` → vazio na primeira tentativa; nos retries, incluir o output de erro do rspec/rubocop/feedback humano

Spawnar com `Agent(subagent_type="general-purpose", prompt=<prompt_preenchido>)`.

O agente implementa o código e os specs. **Não commita, não roda testes.**

**Sobre retries:** cada retry (vindo dos Passos 3, 4, 5 ou 6) spawna um Developer Agent **novo** — não há continuação de sessão de agente neste ambiente (`SendMessage` não está disponível). No retry, o prompt deve ser **enxuto**: apenas o `{{RETRY_CONTEXT}}` (output cru do rspec/rubocop ou o feedback humano) + o `{{EPIC_ID}}` + instrução para ler a branch atual com `Read`/`git diff`. **Não** re-cole todo o contexto de arquivos do primeiro spawn — o código já está na branch e o agente o lê sozinho.

---

## Passo 3 — Rodar rspec

```bash
"$(git rev-parse --show-toplevel)/crew/run-tests.sh" --format documentation 2>&1
```

O script `run-tests.sh` é portável: detecta sozinho se roda no host (bundle local íntegro) ou dentro do container Docker `backend` (fallback), e prepara o banco de teste (`db:prepare`) antes de rodar. **Não** chame `bundle exec rspec` direto — o ambiente do host varia entre máquinas e pode não ter o bundle completo.

- **Passou (exit 0):** ir para o Passo 4
- **Falhou:** incrementar `attempts`. Se `attempts < 3`, voltar ao Passo 2 com o output de erro em `{{RETRY_CONTEXT}}`. Se `attempts >= 3`, ir para **Abort**.

---

## Passo 4 — Rodar rubocop

```bash
"$(git rev-parse --show-toplevel)/crew/run-lint.sh" 2>&1
```

O script `run-lint.sh` linta **apenas os arquivos `.rb` que o épico alterou** (diff `main...HEAD`), não o repo inteiro. Isso é proposital: `main` carrega offenses pré-existentes, então o gate é *"o épico não introduz offenses no que toca"*, e não *"zero offenses no repo"*. Mesma detecção host-vs-container do `run-tests.sh`.

- **Limpo (exit 0, no offenses nos arquivos do épico):** ir para o Passo 5
- **Com offenses:** incrementar `attempts`. Se `attempts < 3`, voltar ao Passo 2 com o output do rubocop em `{{RETRY_CONTEXT}}`. Se `attempts >= 3`, ir para **Abort**.

---

## Passo 5 — Spawnar Reviewer Agent (opcional)

Para épicos simples (C-1, F-1) o orquestrador pode revisar diretamente.
Para épicos complexos (B-2, B-4), spawnar o Reviewer Agent:

Antes de qualquer coisa, garanta que arquivos **novos** (untracked) entrem no diff — `git diff` sozinho não os mostra:
```bash
git add -A
git diff main...HEAD   # confirme que o diff cobre tudo, inclusive arquivos novos
```

Construir o prompt preenchendo `crew/prompts/reviewer.md` com:
- `{{EPIC_ID}}` → ex: `B-2`

O Reviewer Agent roda `git diff main...HEAD` e lê os arquivos no disco por conta própria (ver `crew/prompts/reviewer.md`) — **não** cole o diff no prompt.

Spawnar com `Agent(subagent_type="general-purpose", prompt=<prompt_preenchido>)`.

- **Output "APROVADO":** ir para o Passo 6
- **Output "REPROVADO: ...":** incrementar `attempts`. Se `attempts < 3`, voltar ao Passo 2 com o feedback em `{{RETRY_CONTEXT}}`. Se `attempts >= 3`, ir para **Abort**.

---

## Passo 6 — Checkpoint humano

Mostrar o diff para o usuário (com `git add -A` já feito no Passo 5, arquivos novos aparecem):
```bash
git diff main...HEAD
```

Perguntar: "O diff está aprovado para commit e merge?"

- **Aprovado:** ir para o Passo 7
- **Rejeitado com feedback:** incrementar `attempts`. Se `attempts < 3`, voltar ao Passo 2 com o feedback do usuário em `{{RETRY_CONTEXT}}`. Se `attempts >= 3`, ir para **Abort**.

---

## Passo 7 — Commit, merge e cleanup

### Commit na branch do épico

```bash
cd "$(git rev-parse --show-toplevel)"
git add <arquivos_listados_pelo_developer>
git commit -m "feat: <descrição gerada pelo developer — uma linha>"
```

**Regra obrigatória:** nunca incluir `Co-Authored-By` no commit. Único contribuidor: `bLzera`.

### Merge para main

```bash
git checkout main
git merge --no-ff epic/<X> -m "Merge epic/<X>"
git branch -d epic/<X>
```

### Atualizar CLAUDE.md

No arquivo `"$ROOT/CLAUDE.md"`, na tabela de backlog, substituir:
```
| <X> | Pendente |
```
por:
```
| <X> | ✅ Feito |
```

---

## Abort

Se `attempts >= 3` em qualquer etapa:

1. Reportar ao usuário: qual etapa falhou, qual foi o último erro
2. Fazer checkout de volta para main:
   ```bash
   git checkout main
   git branch -D epic/<X>
   ```
3. **Não commitar nada.**

---

## Contador de attempts

| Evento que incrementa | Limite |
|---|---|
| rspec falhou | 3 total |
| rubocop com offenses | 3 total (compartilhado com rspec) |
| Reviewer reprovou | 3 total (compartilhado) |
| Usuário rejeitou no checkpoint | 3 total (compartilhado) |
