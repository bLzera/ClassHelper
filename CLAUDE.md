# ClassHelper — Diretrizes para Claude Code

## Commits

Nunca adicionar `Co-Authored-By` nem qualquer linha de co-autoria nos commits deste projeto. O único contribuidor é o dono do repositório (git user: bLzera).

---

## O que é o projeto

SaaS multi-usuário que integra com Google Classroom via OAuth 2.0. Oferece priorização de tarefas, timers e lembretes — funcionalidades que o Classroom não tem.

**Stack:** Ruby on Rails 7.2.3 (Ruby 3.2.3, API-only) + PostgreSQL 16 (Railway em prod, Docker local) + Vue.js (ainda não iniciado)

---

## Como subir o ambiente local

**Pré-requisitos:** Docker + Docker Compose instalados, Ruby 3.2.3, Bundler.

```bash
cp .env.example .env
# edite .env: SECRET_KEY_BASE, GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET

docker compose up --build
```

O container `backend` roda `bundle exec rails db:migrate` automaticamente antes de subir o Puma. A API fica disponível em `http://localhost:3000`.

O banco de dados fica na porta `5433` do host (para não conflitar com PostgreSQL local).

---

## Como rodar testes localmente (fora do Docker)

O banco precisa estar rodando. Suba só o container do DB:

```bash
docker compose up db -d
```

Então, dentro de `backend/`:

```bash
cd backend
bundle install

# Cria o banco de teste e roda as migrations
TEST_DATABASE_URL=postgresql://classhelper:changeme@localhost:5433/classhelper_test \
  RAILS_ENV=test bundle exec rails db:create db:migrate

# Roda os testes
TEST_DATABASE_URL=postgresql://classhelper:changeme@localhost:5433/classhelper_test \
  RAILS_ENV=test bundle exec rspec --format documentation
```

Specs que não usam banco (ex: `jwt_service_spec`) usam `spec_helper` diretamente e rodam sem DB:

```bash
bundle exec rspec spec/services/jwt_service_spec.rb --format documentation
```

---

## Lint

```bash
cd backend
bundle exec rubocop --parallel
```

---

## Variáveis de ambiente

| Variável | Descrição |
|---|---|
| `POSTGRES_USER` | Usuário do PostgreSQL |
| `POSTGRES_PASSWORD` | Senha do PostgreSQL |
| `POSTGRES_DB` | Nome do banco principal |
| `DATABASE_URL` | URL completa para o banco (`postgresql://...`) |
| `TEST_DATABASE_URL` | URL para o banco de teste (opcional — derivado de `DATABASE_URL` se ausente) |
| `SECRET_KEY_BASE` | Chave para assinar JWTs. Gere com `bundle exec rails secret` |
| `GOOGLE_CLIENT_ID` | Client ID do Google Cloud Console |
| `GOOGLE_CLIENT_SECRET` | Client Secret do Google Cloud Console |
| `GOOGLE_REDIRECT_URI` | URI de callback OAuth (padrão: `http://localhost:3000/auth/callback`) |
| `CORS_ORIGINS` | Domínio do frontend (padrão: `http://localhost:5173`) |

---

## Estrutura do backend

```
backend/
├── app/
│   ├── controllers/
│   │   ├── application_controller.rb   # authenticate_user! before_action
│   │   ├── auth_controller.rb          # GET /auth/login, /callback, /me
│   │   ├── assignments_controller.rb   # POST /assignments/sync, PATCH /assignments/:id/priority
│   │   ├── courses_controller.rb       # POST /courses/sync
│   │   ├── dashboard_controller.rb     # GET /dashboard
│   │   └── health_controller.rb        # GET /health
│   ├── models/
│   │   ├── user.rb                     # has_many courses, assignments
│   │   ├── course.rb                   # belongs_to user, has_many assignments
│   │   └── assignment.rb               # belongs_to course, user
│   └── services/
│       ├── jwt_service.rb              # create_access_token / decode_access_token (HS256, 30 min)
│       ├── google_oauth_service.rb     # authorization_url, exchange_code, fetch_userinfo
│       └── google_classroom_service.rb # fetch_courses — GET /v1/courses (courseStates=ACTIVE)
├── config/
│   ├── routes.rb                       # todos os endpoints mapeados
│   ├── database.yml
│   └── initializers/cors.rb
├── db/
│   └── migrate/
│       ├── 20260520000001_create_initial_schema.rb
│       └── 20260524000001_add_unique_index_to_courses.rb  # índice único (user_id, google_course_id)
└── spec/
    ├── factories/users.rb
    ├── requests/
    │   ├── health_spec.rb
    │   └── courses_spec.rb
    └── services/jwt_service_spec.rb
```

---

## Estado atual do backend

### Implementado

| Arquivo | O que faz |
|---|---|
| `app/models/user.rb` | Model `User` — google_id, tokens OAuth, email, name |
| `app/models/course.rb` | Model `Course` — vinculado ao User via FK |
| `app/models/assignment.rb` | Model `Assignment` — manual_priority, auto_priority, due_date, state |
| `app/services/jwt_service.rb` | `create_access_token` / `decode_access_token` — JWT HS256, 30 min |
| `app/services/google_oauth_service.rb` | Chamadas à API Google — authorization_url, exchange_code, fetch_userinfo |
| `app/services/google_classroom_service.rb` | `fetch_courses` — GET /v1/courses com access_token do usuário |
| `app/controllers/application_controller.rb` | `authenticate_user!` — extrai e valida JWT do header `Authorization: Bearer` |
| `app/controllers/auth_controller.rb` | Fluxo OAuth completo: login → callback (upsert user, emite JWT) → me |
| `app/controllers/courses_controller.rb` | `POST /courses/sync` — upsert de cursos via google_course_id |
| `app/controllers/health_controller.rb` | `GET /health` → `{ status: "ok" }` |
| `db/migrate/20260520000001_create_initial_schema.rb` | Cria tabelas users, courses, assignments com UUID PKs (pgcrypto) |
| `db/migrate/20260524000001_add_unique_index_to_courses.rb` | Índice único em `(user_id, google_course_id)` |
| `spec/factories/users.rb` | Factory FactoryBot para User |
| `spec/requests/health_spec.rb` | Teste do `GET /health` |
| `spec/requests/courses_spec.rb` | 6 testes do `POST /courses/sync` (WebMock) |
| `spec/services/jwt_service_spec.rb` | 5 testes do JwtService (encode, decode, expiração, erros) |
| `app/controllers/assignments_controller.rb` | `PATCH /assignments/:id/priority` — prioridade manual (C-1) |
| `spec/factories/courses.rb` | Factory FactoryBot para Course |
| `spec/factories/assignments.rb` | Factory FactoryBot para Assignment |
| `spec/requests/assignments_spec.rb` | 8 testes do `PATCH /assignments/:id/priority` |

### Esqueleto (sem lógica — próximas implementações)

> **Próximo épico recomendado: B-2** (`POST /assignments/sync`, que já inclui o cálculo de `auto_priority` de C-2) — ordem: B-2 (+C-2) → F-1 → B-4
>
> Racional: o `GET /dashboard` (F-1) ordena por `COALESCE(manual_priority, auto_priority)`. Sem B-2 rodado, `auto_priority` é sempre `NULL` e o dashboard não tem inteligência de prazo. Por isso B-2 vem antes de F-1.

| Controller | Épico | Endpoint |
|---|---|---|
| `assignments_controller.rb#sync` | B-2 | `POST /assignments/sync` ← próximo |
| `dashboard_controller.rb#index` | F-1 | `GET /dashboard` |

---

## Especificação de cada endpoint

### `GET /health`
- Auth: nenhuma
- Response 200: `{ "status": "ok" }`

### `GET /auth/login`
- Auth: nenhuma
- Lógica: `GoogleOauthService#authorization_url` → redirect 302 para Google
- Scopes: `openid email profile classroom.courses.readonly classroom.coursework.me.readonly`
- Params Google: `access_type=offline`, `prompt=consent`

### `GET /auth/callback`
- Auth: nenhuma
- Query params: `code` (obrigatório), `error` (indica falha OAuth)
- Lógica: troca `code` por tokens → busca userinfo → upsert em `users` → emite JWT próprio
- Response 200: `{ "access_token": String, "token_type": "bearer" }`
- Response 400: `{ "error": "oauth_error", "message": String }`
- Response 500: `{ "error": "auth_failed", "message": String }`

### `GET /auth/me`
- Auth: `Bearer <jwt>` obrigatório
- Response 200: `{ "id": UUID, "email": String, "name": String, "created_at": ISO8601 }`
- Response 401: `{ "error": "unauthorized" }`

### `POST /courses/sync` (Épico B-1 — pendente)
- Auth: `Bearer <jwt>` obrigatório
- Lógica: chama `GET https://classroom.googleapis.com/v1/courses` com o access_token do usuário; upsert via `google_course_id`
- Response 200: `{ "synced": Integer, "courses": Array }`

### `POST /assignments/sync` (Épico B-2 — pendente)
- Auth: `Bearer <jwt>` obrigatório
- Lógica: para cada course, chama `GET https://classroom.googleapis.com/v1/courses/:id/courseWork`; upsert; calcula `auto_priority` por prazo
- Response 200: `{ "synced": Integer }`

### `PATCH /assignments/:id/priority` (Épico C-1 — pendente)
- Auth: `Bearer <jwt>` obrigatório
- Body: `{ "manual_priority": Integer }`
- Lógica: `Assignment.find_by(id:, user: current_user)` → atualiza `manual_priority`
- Response 200: assignment atualizado
- Response 404: `{ "error": "not_found" }`

### `GET /dashboard` (Épico F-1 — pendente)
- Auth: `Bearer <jwt>` obrigatório
- Lógica: `current_user.assignments.where(state: "CREATED")` ordenados por prioridade efetiva (`manual_priority || auto_priority`, menor número = maior prioridade)
- Response 200: `{ "assignments": Array }`

---

## Backlog MVP completo

| Épico | Item | Status | Descrição |
|---|---|---|---|
| A | A-1 | ✅ Feito | OAuth 2.0 Google — login, callback, me |
| A | A-2 | ✅ Feito | JWT stateless — create/decode |
| A | A-4 | ✅ Feito | `authenticate_user!` before_action |
| B | B-1 | ✅ Feito | `POST /courses/sync` — busca cursos no Classroom e faz upsert |
| B | B-2 | Pendente | `POST /assignments/sync` — busca tarefas no Classroom e faz upsert |
| B | B-4 | Pendente | Renovação de `access_token` via `refresh_token` quando expirar |
| C | C-1 | ✅ Feito | `PATCH /assignments/:id/priority` — prioridade manual |
| C | C-2 | Pendente | Cálculo de `auto_priority` por prazo (executado no sync) |
| F | F-1 | Pendente | `GET /dashboard` — assignments ordenados por prioridade efetiva |
| F | F-2 | Pendente | Frontend Vue.js — dashboard principal |

---

## Decisões de arquitetura

| Decisão | Escolha | Motivo |
|---|---|---|
| Framework | Rails 7.2 API-only | Convenção sobre configuração, migrations + ORM integrados |
| Banco local | PostgreSQL 16 no Docker, porta 5433 | Não conflita com PostgreSQL local |
| Banco prod | PostgreSQL self-hosted no Railway | — |
| Sessão | JWT stateless, HS256, 30 min | Sem session store, `user_id` no payload |
| Auth middleware | `authenticate_user!` em `ApplicationController` | Equivalente ao `Depends(get_current_user)` do FastAPI anterior |
| HTTP client | `httparty` | Chamadas à API Google simples, sem necessidade de middleware chain |
| PKs | UUID via `pgcrypto` (`gen_random_uuid()`) | Consistência com o schema original |
| Frontend state | Vue Router + Pinia | A iniciar |
| Deploy | Railway | — |
| Migrações | Rails ActiveRecord, rodadas no entrypoint do container | — |
| Porta local | 3000 | Padrão Rails (era 8000 com Uvicorn) |
| CORS | `rack-cors`, origins via `CORS_ORIGINS` env | Preparado para o frontend Vue.js na porta 5173 |
