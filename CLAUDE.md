# ClassHelper — Diretrizes para Claude Code

## Fluxo de trabalho (OBRIGATÓRIO)

Quando o usuário pedir para **implementar um épico** (ex: "implementa o épico B-2", "pode fazer o C-2"), você atua como **ORQUESTRADOR**, não como implementador. Você **não escreve o código de produção nem os specs diretamente** — esse trabalho é delegado a um Developer Agent.

Antes de qualquer ação, leia `crew/orchestrator.md` e siga o protocolo descrito lá passo a passo (preflight → branch do épico → spawnar Developer Agent → testes → lint → Reviewer Agent → checkpoint humano → commit/merge/cleanup). Os prompts a preencher dependem do tipo de épico:

- **Épicos de backend (Rails):** `crew/prompts/developer.md` e `crew/prompts/reviewer.md`; gates `crew/run-tests.sh` (rspec) + `crew/run-lint.sh` (rubocop).
- **Épicos de frontend (`F-*`, Vue/TS):** `crew/prompts/developer-fe.md` e `crew/prompts/reviewer-fe.md`; gates `crew/run-fe-tests.sh` (vitest) + `crew/run-fe-lint.sh` (vue-tsc + eslint). Ver a seção "Épicos de frontend (F-2+)" em `crew/orchestrator.md`.

A spec de cada épico está em `crew/epics/<X>.md`.

Só implemente algo você mesmo quando o usuário pedir explicitamente uma tarefa fora desse fluxo (ex: um ajuste pontual, uma pergunta, um bugfix isolado).

---

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

## Frontend (Vue 3 + Vite + TS)

SPA em `frontend/`. Stack: Vue 3 (`<script setup lang="ts">`), Vite, TypeScript, Pinia (estado), Vue Router 4, Tailwind. Testes com Vitest + Vue Test Utils (jsdom).

### Estrutura

```
frontend/
├── Dockerfile                      # node:20-alpine, npm ci, vite dev --host 0.0.0.0
├── index.html
├── package.json / package-lock.json
├── vite.config.ts                  # alias @ → src; config do vitest (jsdom, globals)
├── tsconfig*.json / eslint.config.js / tailwind.config.js / postcss.config.js
├── .env.example                    # VITE_API_BASE_URL
└── src/
    ├── main.ts                     # registra Pinia + Router
    ├── App.vue                     # <RouterView />
    ├── lib/api.ts                  # instância axios: baseURL + interceptors (Bearer / 401→logout)
    ├── router/index.ts             # rotas + guard de auth (meta.public libera)
    ├── stores/auth.ts              # store Pinia: token, user, setToken, fetchMe, logout, isAuthenticated (F-3)
    └── views/                      # LoginView, CallbackView, DashboardView, HomeView
```

### Como subir / testar / lintar

```bash
cd frontend
npm ci                 # primeira vez (node_modules é gitignorado)

npm run dev            # dev server em http://localhost:5173
npm run test           # vitest run
npm run type-check     # vue-tsc --noEmit
npm run lint           # eslint
```

Via Docker (junto do backend): `docker compose up frontend` (porta 5173). Aponta para a API em `VITE_API_BASE_URL` (default `http://localhost:3000`).

Os gates do crew (`crew/run-fe-tests.sh` / `crew/run-fe-lint.sh`) rodam `npm ci` automaticamente quando falta `node_modules` e detectam host vs container `frontend`.

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
| `GOOGLE_REDIRECT_URI` | URI de callback OAuth registrada no Google (padrão: `http://localhost:3000/auth/callback`) |
| `CORS_ORIGINS` | Domínio do frontend para CORS (padrão: `http://localhost:5173`) |
| `FRONTEND_URL` | Base do SPA para onde o callback redireciona com o token (padrão: `http://localhost:5173`) — B-5 |

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

> **Próximo épico: F-4** (F-2 ✅ scaffold, F-3 ✅ auth — login/callback/store/guard/logout).
>
> O frontend foi quebrado em 5 verticais (ver Backlog): **F-2** scaffold ✅ → **F-3** auth ✅ →
> **F-4** dashboard → **F-5** sync → **F-6** prioridade. Specs em `crew/epics/F-2.md`..`F-6.md`.
>
> Sequência sugerida: F-4 → (F-5 ∥ F-6).
>
> **Atenção:** os épicos `F-*` são frontend (Vue 3 + Vite + TS + Pinia + Tailwind, dir `frontend/`).
> O gate do crew usa `crew/run-fe-tests.sh` (`vitest run`) + `crew/run-fe-lint.sh` (`vue-tsc --noEmit` +
> `eslint`) — ver a seção "Épicos de frontend (F-2+)" em `crew/orchestrator.md`.

_Backend de API do MVP completo (B-5 ✅). Resta o frontend (F-2..F-6)._

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

### `GET /auth/callback` (Épico B-5 — ✅ feito)
- Auth: nenhuma
- Query params: `code` (obrigatório no sucesso), `error` (indica falha OAuth do Google)
- Lógica: troca `code` por tokens → busca userinfo → upsert em `users` → emite JWT próprio → **redireciona pro frontend** com o token no fragment
- Response 302 (sucesso): `Location: <FRONTEND_URL>/auth/callback#token=<jwt>`
- Response 302 (erro OAuth): `Location: <FRONTEND_URL>/auth/callback#error=oauth_error`
- Response 302 (exceção): `Location: <FRONTEND_URL>/auth/callback#error=auth_failed`
- Token/erro vão sempre no fragment (`#`), nunca na query string
- Env nova: `FRONTEND_URL` (default `http://localhost:5173`)
- _Antes do B-5 o callback respondia JSON 200 `{ access_token, token_type }` — incompatível com SPA._

### `GET /auth/me`
- Auth: `Bearer <jwt>` obrigatório
- Response 200: `{ "id": UUID, "email": String, "name": String, "created_at": ISO8601 }`
- Response 401: `{ "error": "unauthorized" }`

### `POST /courses/sync` (Épico B-1 — pendente)
- Auth: `Bearer <jwt>` obrigatório
- Lógica: chama `GET https://classroom.googleapis.com/v1/courses` com o access_token do usuário; upsert via `google_course_id`
- Response 200: `{ "synced": Integer, "courses": Array }`

### `POST /assignments/sync` (Épico B-2 — ✅ feito)
- Auth: `Bearer <jwt>` obrigatório
- Lógica: para cada course, chama `GET https://classroom.googleapis.com/v1/courses/:id/courseWork`; upsert; calcula `auto_priority` por prazo
- Response 200: `{ "synced": Integer }`

### `PATCH /assignments/:id/priority` (Épico C-1 — pendente)
- Auth: `Bearer <jwt>` obrigatório
- Body: `{ "manual_priority": Integer }`
- Lógica: `Assignment.find_by(id:, user: current_user)` → atualiza `manual_priority`
- Response 200: assignment atualizado
- Response 404: `{ "error": "not_found" }`

### `GET /dashboard` (Épico F-1 — ✅ feito)
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
| B | B-2 | ✅ Feito | `POST /assignments/sync` — busca tarefas no Classroom e faz upsert |
| B | B-4 | ✅ Feito | Renovação de `access_token` via `refresh_token` quando expirar |
| B | B-5 | ✅ Feito | Callback OAuth redireciona pro frontend com token no fragment (`#token=`) |
| C | C-1 | ✅ Feito | `PATCH /assignments/:id/priority` — prioridade manual |
| C | C-2 | ✅ Feito | Cálculo de `auto_priority` por prazo (executado no sync) |
| F | F-1 | ✅ Feito | `GET /dashboard` — assignments ordenados por prioridade efetiva |
| F | F-2 | ✅ Feito | Frontend — scaffold & infra (Vite+Vue3+TS+Pinia+Router+Tailwind+Vitest); adapta o crew |
| F | F-3 | ✅ Feito | Frontend — fluxo de autenticação (login, callback, store, guard, logout) |
| F | F-4 | Pendente | Frontend — dashboard (listagem ordenada, estados loading/vazio/erro) |
| F | F-5 | Pendente | Frontend — ações de sync (cursos/tarefas) com refresh do dashboard |
| F | F-6 | Pendente | Frontend — editar prioridade manual (`PATCH` + reordenação) |

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
