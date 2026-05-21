# ClassHelper

SaaS que integra com Google Classroom via OAuth 2.0 para oferecer o que o Classroom não tem: priorização de tarefas, timers e lembretes.

**Stack:** Rails 7.2 (Ruby 3.2, API-only) · PostgreSQL 16 · Vue.js (em breve)

---

## Subindo o ambiente local

**Pré-requisitos:** Docker e Docker Compose.

```bash
cp .env.example .env
# Preencha SECRET_KEY_BASE, GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET
docker compose up --build
```

API disponível em `http://localhost:3000`. Banco na porta `5433`.

---

## Rodando os testes

```bash
# Sobe apenas o banco
docker compose up db -d

cd backend
bundle install

# Prepara o banco de teste
TEST_DATABASE_URL=postgresql://classhelper:changeme@localhost:5433/classhelper_test \
  RAILS_ENV=test bundle exec rails db:create db:migrate

# Roda os testes
TEST_DATABASE_URL=postgresql://classhelper:changeme@localhost:5433/classhelper_test \
  RAILS_ENV=test bundle exec rspec --format documentation
```

---

## Lint

```bash
cd backend && bundle exec rubocop --parallel
```

---

## Endpoints

| Método | Rota | Auth | Status |
|---|---|---|---|
| GET | `/health` | — | ✅ |
| GET | `/auth/login` | — | ✅ |
| GET | `/auth/callback` | — | ✅ |
| GET | `/auth/me` | Bearer JWT | ✅ |
| POST | `/courses/sync` | Bearer JWT | Pendente |
| POST | `/assignments/sync` | Bearer JWT | Pendente |
| PATCH | `/assignments/:id/priority` | Bearer JWT | Pendente |
| GET | `/dashboard` | Bearer JWT | Pendente |

---

## Variáveis de ambiente

Veja `.env.example` para a lista completa. As obrigatórias:

| Variável | Como obter |
|---|---|
| `SECRET_KEY_BASE` | `bundle exec rails secret` |
| `GOOGLE_CLIENT_ID` | Google Cloud Console → Credenciais OAuth 2.0 |
| `GOOGLE_CLIENT_SECRET` | Google Cloud Console → Credenciais OAuth 2.0 |

O `GOOGLE_REDIRECT_URI` padrão é `http://localhost:3000/auth/callback`. Cadastre esse URI no Google Cloud Console para desenvolvimento local.
