# ClassHelper — Diretrizes para Claude Code

## Commits

Nunca adicionar `Co-Authored-By` nem qualquer linha de co-autoria nos commits deste projeto. O único contribuidor é o dono do repositório (git user: bLzera).

---

## O que é o projeto

SaaS multi-usuário que integra com Google Classroom via OAuth 2.0. Oferece priorização de tarefas, timers e lembretes — funcionalidades que o Classroom não tem.

**Stack:** FastAPI (Python 3.12) + PostgreSQL (Railway em prod, Docker local) + Vue.js (ainda não iniciado)

---

## Como subir o ambiente local

**Pré-requisitos:** Docker + Docker Compose instalados. Copie `.env.example` para `.env` e preencha as variáveis.

```bash
cp .env.example .env
# edite .env: SECRET_KEY, GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET

docker compose up --build
```

O container `backend` roda `alembic upgrade head` automaticamente antes de subir o servidor. A API fica disponível em `http://localhost:8000`. Docs interativas em `http://localhost:8000/docs`.

O banco de dados fica na porta `5433` do host (para não conflitar com PostgreSQL local).

**Rodar testes (fora do Docker):**

```bash
cd backend
pip install -r requirements.txt -r requirements-dev.txt
pytest --cov=app --cov-report=term-missing
```

Os testes sobem o schema via `Base.metadata.create_all` — não precisam de Alembic rodando.

**Lint/type check:**

```bash
ruff check . && ruff format --check . && mypy app/
```

---

## Estado atual do backend

### Pronto

| Arquivo | O que faz |
|---|---|
| `app/models/user.py` | Model `User` — armazena google_id, tokens OAuth, email, name |
| `app/models/course.py` | Model `Course` — vinculado ao User via FK |
| `app/models/assignment.py` | Model `Assignment` — campos `manual_priority`, `auto_priority`, `due_date`, `state` |
| `app/core/security.py` | `create_access_token` / `decode_access_token` — JWT HS256, 30 min |
| `app/core/database.py` | Engine async + `AsyncSessionLocal` + `Base` |
| `app/core/config.py` | `Settings` via pydantic-settings — lê `.env` |
| `app/api/deps.py` | `get_db` — dependency de sessão async |
| `app/main.py` | App FastAPI com 4 routers registrados (`/auth`, `/courses`, `/assignments`, `/dashboard`) |
| `alembic/versions/84bee5f3c9a4_initial.py` | Migration inicial — cria tabelas `users`, `courses`, `assignments` |
| `tests/conftest.py` | Fixtures async: `setup_database`, `db_session`, `client` (override de `get_db`) |
| `tests/test_health.py` | Teste do `GET /health` |

### Vazio (esqueleto apenas — próximas implementações)

- `app/api/routes/auth.py` — sem endpoints
- `app/api/routes/courses.py` — sem endpoints
- `app/api/routes/assignments.py` — sem endpoints
- `app/api/routes/dashboard.py` — sem endpoints
- `app/schemas/` — vazio
- `app/services/` — vazio

**Frontend Vue.js:** ainda não iniciado.

---

## Próxima tarefa: Épico A — Autenticação

Implementar o fluxo OAuth 2.0 Google completo. Tudo no MVP depende disso.

### O que construir

**1. `GET /auth/login`**
- Gera a URL de autorização do Google e redireciona o usuário
- Scopes necessários: `openid`, `email`, `profile`, `https://www.googleapis.com/auth/classroom.courses.readonly`, `https://www.googleapis.com/auth/classroom.coursework.me.readonly`
- Use `access_type=offline` e `prompt=consent` para receber o `refresh_token`

**2. `GET /auth/callback`**
- Recebe o `code` vindo do Google
- Troca por `access_token` + `refresh_token` via POST para `https://oauth2.googleapis.com/token`
- Busca dados do usuário na `userinfo` endpoint do Google
- Faz upsert na tabela `users` (cria se não existe, atualiza tokens se já existe)
- Retorna um JWT próprio (usar `create_access_token` de `security.py`)

**3. `GET /auth/me`** (protegido)
- Retorna dados do usuário autenticado
- Precisa da dependency `get_current_user` (ainda não existe em `deps.py`)

**4. `get_current_user` em `app/api/deps.py`**
- Extrai o JWT do header `Authorization: Bearer <token>`
- Decodifica com `decode_access_token`
- Busca o `User` no DB pelo `user_id` do payload
- Levanta `HTTPException(401)` se inválido

### Arquivos a criar/editar

- `app/schemas/__init__.py` + schemas de Auth (ex: `UserOut`, `TokenOut`)
- `app/services/google_oauth.py` — encapsula as chamadas à API do Google
- `app/api/routes/auth.py` — os 3 endpoints acima
- `app/api/deps.py` — adicionar `get_current_user`
- Testes em `tests/test_auth.py`

### Variáveis de ambiente necessárias

```
GOOGLE_CLIENT_ID=      # do Google Cloud Console
GOOGLE_CLIENT_SECRET=  # do Google Cloud Console
SECRET_KEY=            # qualquer string aleatória longa
```

`GOOGLE_REDIRECT_URI` já está hardcoded em `config.py` como `http://localhost:8000/auth/callback`. Para produção, precisará de uma variável de ambiente.

---

## Backlog MVP completo

| Épico | Item | Descrição |
|---|---|---|
| A | A-1 | OAuth 2.0 Google — login, callback, me |
| A | A-2 | JWT stateless — create/decode (feito) |
| A | A-4 | `get_current_user` dependency |
| B | B-1 | `POST /courses/sync` — busca cursos no Classroom e faz upsert |
| B | B-2 | `POST /assignments/sync` — busca tarefas no Classroom e faz upsert |
| B | B-4 | Renovação de `access_token` via `refresh_token` quando expirar |
| C | C-1 | `PATCH /assignments/{id}/priority` — prioridade manual |
| C | C-2 | Cálculo de `auto_priority` por prazo (executado no sync) |
| F | F-1 | `GET /dashboard` — assignments ordenados por prioridade efetiva |
| F | F-2 | Frontend Vue.js — dashboard principal |

---

## Decisões de arquitetura

- **Banco local:** PostgreSQL no Docker, porta 5433
- **Banco prod:** PostgreSQL self-hosted no Railway
- **Sessão:** JWT stateless (sem session store)
- **Frontend state:** Vue Router + Pinia (a iniciar)
- **Deploy:** Railway
- **Migrações:** Alembic, rodadas automaticamente no entrypoint do container
