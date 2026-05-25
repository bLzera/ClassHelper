# Protocolo do Orquestrador — ClassHelper Crew

Quando o usuário pedir "implementa o épico X", execute os passos abaixo em ordem.

---

## Pré-condições

Antes de começar, verificar:
- Docker DB rodando: `docker compose up db -d` (na raiz do projeto)
- Branch atual é `main` e está limpa (`git status`)

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
- `{{FILES_TO_READ}}` → lista do epic file (já lidos no passo 1, incluir o conteúdo)
- `{{FILES_TO_CREATE_OR_MODIFY}}` → lista do epic file
- `{{ACCEPTANCE_CRITERIA}}` → critérios do epic file
- `{{RETRY_CONTEXT}}` → vazio na primeira tentativa; nos retries, incluir o output de erro do rspec/rubocop/feedback humano

Spawnar com `Agent(subagent_type="general-purpose", prompt=<prompt_preenchido>)`.

O agente implementa o código e os specs. **Não commita, não roda testes.**

---

## Passo 3 — Rodar rspec

```bash
cd /home/blzera/projetos/ClassHelper/backend && \
TEST_DATABASE_URL=postgresql://classhelper:changeme@localhost:5433/classhelper_test \
RAILS_ENV=test bundle exec rspec --format documentation 2>&1
```

- **Passou:** ir para o Passo 4
- **Falhou:** incrementar `attempts`. Se `attempts < 3`, voltar ao Passo 2 com o output de erro em `{{RETRY_CONTEXT}}`. Se `attempts >= 3`, ir para **Abort**.

---

## Passo 4 — Rodar rubocop

```bash
cd /home/blzera/projetos/ClassHelper/backend && \
bundle exec rubocop --parallel 2>&1
```

- **Limpo (no offenses):** ir para o Passo 5
- **Com offenses:** incrementar `attempts`. Se `attempts < 3`, voltar ao Passo 2 com o output do rubocop em `{{RETRY_CONTEXT}}`. Se `attempts >= 3`, ir para **Abort**.

---

## Passo 5 — Spawnar Reviewer Agent (opcional)

Para épicos simples (C-1, F-1) o orquestrador pode revisar diretamente.
Para épicos complexos (B-2, B-4), spawnar o Reviewer Agent:

Obter o diff:
```bash
git diff main...epic/<X>
```

Construir o prompt preenchendo `crew/prompts/reviewer.md` com:
- `{{EPIC_ID}}` → ex: `B-2`
- `{{DIFF}}` → output do git diff

Spawnar com `Agent(subagent_type="general-purpose", prompt=<prompt_preenchido>)`.

- **Output "APROVADO":** ir para o Passo 6
- **Output "REPROVADO: ...":** incrementar `attempts`. Se `attempts < 3`, voltar ao Passo 2 com o feedback em `{{RETRY_CONTEXT}}`. Se `attempts >= 3`, ir para **Abort**.

---

## Passo 6 — Checkpoint humano

Mostrar o diff para o usuário:
```bash
git diff main...epic/<X>
```

Perguntar: "O diff está aprovado para commit e merge?"

- **Aprovado:** ir para o Passo 7
- **Rejeitado com feedback:** incrementar `attempts`. Se `attempts < 3`, voltar ao Passo 2 com o feedback do usuário em `{{RETRY_CONTEXT}}`. Se `attempts >= 3`, ir para **Abort**.

---

## Passo 7 — Commit, merge e cleanup

### Commit na branch do épico

```bash
cd /home/blzera/projetos/ClassHelper/backend
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

No arquivo `/home/blzera/projetos/ClassHelper/CLAUDE.md`, na tabela de backlog, substituir:
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
