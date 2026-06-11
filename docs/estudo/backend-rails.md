# Estudo: Backend (Ruby on Rails) do ClassHelper

> Guia de estudo da arquitetura atual. Baseado no código real em `backend/`.
> Última atualização: 2026-06-11.

---

## 1. Visão geral

O backend é uma **API-only** em Rails 7.2 (Ruby 3.2.3). "API-only" significa que o
Rails não renderiza HTML/views — ele só responde **JSON**. Por isso a classe base dos
controllers é `ActionController::API` (mais enxuta que a `ActionController::Base` de um
app web tradicional: sem cookies de sessão por padrão, sem helpers de view, sem CSRF
form-based).

Quem consome essa API é o **frontend Vue** (SPA na porta 5173). A comunicação é:

```
Navegador (Vue SPA :5173)  ⇄  API Rails (:3000)  ⇄  Google (OAuth + Classroom API)
                                      ⇅
                               PostgreSQL (:5433)
```

O banco é PostgreSQL 16. Em dev roda no Docker; as PKs são **UUID** (extensão
`pgcrypto`, função `gen_random_uuid()`), não os `id` inteiros sequenciais padrão do Rails.

---

## 2. O ciclo de vida de uma requisição

Toda requisição HTTP passa por 4 camadas. Vale fixar esse mapa mental — é o coração do Rails:

```
1. ROTA        config/routes.rb        → decide qual controller#action atende a URL
2. CONTROLLER  app/controllers/*.rb     → orquestra: autentica, chama models/services, monta resposta
3. MODEL       app/models/*.rb          → representa uma tabela; regras de negócio + validações + queries
   ou SERVICE  app/services/*.rb        → lógica que não pertence a um model (ex.: chamadas HTTP externas)
4. RESPOSTA    render json: {...}        → serializa em JSON e devolve com um status HTTP
```

### 2.1 Rotas (`config/routes.rb`)

A tabela de rotas é declarativa: cada linha mapeia `método HTTP + caminho → controller#ação`.

```ruby
get   "/health",                   to: "health#index"
get   "/auth/login",               to: "auth#login"
get   "/auth/callback",            to: "auth#callback"
get   "/auth/me",                  to: "auth#me"
post  "/courses/sync",             to: "courses#sync"
post  "/assignments/sync",         to: "assignments#sync"
patch "/assignments/:id/priority", to: "assignments#update_priority"
get   "/dashboard",                to: "dashboard#index"
```

- `"auth#login"` quer dizer: classe `AuthController`, método (action) `login`.
- `:id` é um **segmento dinâmico** — vira `params[:id]` dentro do controller.
- Aqui as rotas são escritas "à mão", uma a uma. Rails também tem `resources :x` que
  gera as 7 rotas REST de uma vez, mas neste projeto preferimos ser explícitos.

> Para ver todas as rotas resolvidas: `docker compose exec backend bin/rails routes`.

### 2.2 Controllers

Um controller é uma classe Ruby; cada **método público** é uma "action" que atende uma rota.
Convenções importantes que aparecem no nosso código:

- `params` — hash com tudo que veio na requisição (query string, corpo JSON, segmentos da
  rota como `:id`). Ex.: `params[:manual_priority]`, `params[:id]`.
- `render json: <objeto>, status: :ok` — serializa e responde. Os status podem ser símbolos
  (`:ok` = 200, `:not_found` = 404, `:unauthorized` = 401, `:bad_gateway` = 502).
- `before_action :authenticate_user!` — roda **antes** da action. Se a action precisa de
  login, é assim que se exige.

Exemplo completo, o mais simples do projeto (`health_controller.rb`):

```ruby
class HealthController < ApplicationController
  def index
    render json: { status: "ok" }
  end
end
```

---

## 3. Autenticação — o `ApplicationController` e o JWT

Todos os controllers herdam de `ApplicationController`, que centraliza a autenticação.
Esse é o equivalente Rails do `Depends(get_current_user)` que existia na versão FastAPI.

```ruby
class ApplicationController < ActionController::API
  private

  def authenticate_user!
    token = extract_bearer_token
    return render_unauthorized unless token

    payload = JwtService.decode_access_token(token, ENV.fetch("SECRET_KEY_BASE"))
    @current_user = User.find(payload["user_id"])
  rescue JWT::DecodeError, ActiveRecord::RecordNotFound
    render_unauthorized
  end

  attr_reader :current_user
  # ...
end
```

Fluxo mental:

1. A action protegida declara `before_action :authenticate_user!`.
2. `authenticate_user!` lê o header `Authorization: Bearer <jwt>`, decodifica o JWT, e
   carrega o usuário em `@current_user`.
3. Se qualquer coisa falhar (token ausente, inválido, expirado, ou usuário não existe),
   o `rescue` responde `401 unauthorized` e **interrompe** — a action nunca roda.
4. Dentro da action, `current_user` devolve o usuário autenticado.

Pontos didáticos:

- `@current_user` é uma **variável de instância** (o `@`). Ela vive durante uma única
  requisição e é compartilhada entre o `before_action` e a action. O
  `attr_reader :current_user` gera o método leitor (`current_user`) automaticamente.
- `rescue` no nível do método captura exceções de qualquer linha acima dele. Aqui ele lista
  duas classes de erro específicas — não captura tudo cegamente. (`JWT::ExpiredSignature`
  é subclasse de `JWT::DecodeError`, então token expirado também cai aqui.)
- O token é extraído do header com a regex `/\ABearer (.+)\z/` — só aceita o formato
  exato `Bearer <token>`; um header malformado (ex.: só `"Bearer"`) vira `nil` → 401.
- `ENV.fetch("SECRET_KEY_BASE")` — `fetch` (sem default) **explode** se a env var faltar.
  Isso é intencional: melhor falhar na hora do que assinar JWT com chave vazia.

### 3.1 O `JwtService`

Diferente dos controllers e models, isso é um **módulo** puro (`module`, não `class`), sem
estado. `module_function` torna os métodos chamáveis como `JwtService.create_access_token(...)`.

```ruby
module JwtService
  ALGORITHM   = "HS256"
  EXPIRY_SECS = 30 * 60   # 30 minutos

  module_function

  def create_access_token(data, secret_key)
    payload = data.dup
    payload["exp"] = Time.now.utc.to_i + EXPIRY_SECS
    JWT.encode(payload, secret_key, ALGORITHM)
  end

  def decode_access_token(token, secret_key)
    decoded, _header = JWT.decode(token, secret_key, true, algorithms: [ALGORITHM])
    decoded
  end
end
```

- **Stateless**: o token carrega o `user_id` no payload e a data de expiração (`exp`). Não há
  tabela de sessões no banco. A própria gem `jwt` valida `exp` ao decodificar e levanta
  `JWT::ExpiredSignature` se passou dos 30 min.
- HS256 = assinatura simétrica com `SECRET_KEY_BASE`. Quem tem o segredo consegue emitir e
  verificar tokens.

---

## 4. Models (ActiveRecord) — o ORM

Cada model é uma classe que herda de `ApplicationRecord` e mapeia **uma tabela**. O Rails
descobre as colunas sozinho (lendo o schema do banco) — não declaramos os campos no model,
só as **associações**, **validações** e **métodos de negócio**.

### 4.1 As três tabelas e como se relacionam

```
User  1 ──< Course  1 ──< Assignment
  └──────────────────────< Assignment   (Assignment também pertence direto ao User)
```

```ruby
# app/models/user.rb
class User < ApplicationRecord
  has_many :courses,     dependent: :destroy
  has_many :assignments, dependent: :destroy
  # validações de google_id, email, name, tokens...
end

# app/models/course.rb
class Course < ApplicationRecord
  belongs_to :user
  has_many   :assignments, dependent: :destroy
  # validações...
end

# app/models/assignment.rb
class Assignment < ApplicationRecord
  belongs_to :course
  belongs_to :user
  # ...
end
```

O que as associações te dão de graça:

- `user.courses` → todos os cursos daquele usuário (uma query).
- `course.assignments` → as tarefas do curso.
- `assignment.user` / `assignment.course` → navega pro "pai".
- `dependent: :destroy` → apagar um User apaga seus courses e assignments em cascata (no
  app). Note que o banco **também** tem `on_delete: :cascade` na FK, então há defesa em dois
  níveis.

### 4.2 Validações

Rodam antes de salvar; se falham, `save!`/`update!` levantam `ActiveRecord::RecordInvalid`.

```ruby
validates :google_id, presence: true, uniqueness: true, length: { maximum: 255 }
validates :state, inclusion: { in: VALID_STATES }
validates :manual_priority, :auto_priority,
          numericality: { only_integer: true, greater_than_or_equal_to: 1 },
          allow_nil: true
```

A validação de `numericality` nas prioridades garante o contrato com o frontend
(inteiros ≥ 1, ou `nil` para "sem prioridade"). Quando ela falha, o controller responde
`422 { "error": "invalid_priority" }` em vez de estourar um 500.

### 4.3 Lógica de negócio no model — `auto_priority`

O cálculo da prioridade automática mora no model `Assignment`, como método de classe:

```ruby
VALID_STATES = %w[CREATED TURNED_IN RETURNED RECLAIMED_BY_STUDENT].freeze

def self.calculate_auto_priority(due_date)
  return nil if due_date.nil?

  days_until_due = (due_date.to_date - Time.zone.today).to_i
  [days_until_due, 1].max   # nunca menor que 1
end
```

Regra: **quanto menos dias até o prazo, menor o número, maior a prioridade.** Sem prazo →
`nil` (vai pro fim da lista). Esse método é chamado durante o sync de assignments.

### 4.4 A prioridade efetiva (no Dashboard)

O dashboard ordena por `manual_priority` se existir, senão por `auto_priority`. Isso é feito
direto no SQL via `COALESCE`:

```ruby
current_user.assignments
            .where(state: "CREATED")
            .order(Arel.sql("COALESCE(manual_priority, auto_priority) ASC NULLS LAST"))
```

- `COALESCE(a, b)` = primeiro valor não-nulo → a prioridade manual sobrepõe a automática.
- `ASC` = menor primeiro (maior prioridade no topo).
- `NULLS LAST` = tarefas sem nenhuma prioridade ficam no fim.
- `Arel.sql(...)` é necessário para o Rails aceitar esse SQL cru no `.order` (proteção contra
  SQL injection em ordenações dinâmicas — aqui a string é fixa, então é seguro).

---

## 5. Services — lógica que não é de um model

Quando a lógica é **chamada HTTP externa** ou orquestração que não pertence naturalmente a
uma tabela, ela vira um objeto em `app/services/`. Usamos a gem `httparty` como cliente HTTP.

Temos dois:

| Service | Responsabilidade |
|---|---|
| `GoogleOauthService` | Falar com o OAuth do Google: gerar URL de login, trocar `code` por tokens, renovar token, buscar `userinfo`. |
| `GoogleClassroomService` | Falar com a Classroom API: buscar cursos e tarefas do usuário. |

### 5.1 `GoogleClassroomService`: paginação e timeout

A Classroom API **pagina** as listagens: cada resposta traz até `pageSize` itens e, se
houver mais, um `nextPageToken` que deve ser reenviado como `pageToken` na próxima
chamada. O service centraliza isso em `fetch_all_pages`, que acumula os itens de todas
as páginas num único array:

```ruby
def fetch_all_pages(url, items_key, query: {})
  items      = []
  page_token = nil

  loop do
    body = fetch_page(url, query, page_token)
    items.concat(body.fetch(items_key, []))
    page_token = body["nextPageToken"]
    break if page_token.nil?
  end

  items
end
```

`fetch_courses` e `fetch_course_work` viram chamadas de uma linha para esse helper —
só mudam a URL, a chave (`"courses"` / `"courseWork"`) e a query extra.

Toda chamada HTTP dos services leva `timeout: REQUEST_TIMEOUT` (10s). Sem isso o
HTTParty espera **indefinidamente**, e uma API externa lenta penduraria workers do Puma.

### 5.2 O refresh automático de token

O detalhe mais esperto do backend está aqui. Toda chamada ao Classroom passa por
`with_token_refresh`, que tenta a chamada, e **se tomar 401, renova o access_token uma vez e
tenta de novo**:

```ruby
def with_token_refresh
  response = yield(@user.google_access_token)
  return response if response.success?

  if response.code == 401
    refresh_access_token!
    response = yield(@user.google_access_token)
    return response if response.success?

    raise_for_response(response)
  end

  raise_for_response(response)
end
```

- `yield` chama o bloco que foi passado pro método — o bloco é a chamada HTTP de fato
  (`HTTParty.get(...)`). Esse é o padrão Ruby de "passar comportamento" via bloco.
- `refresh_access_token!` usa o `refresh_token` salvo pra pegar um `access_token` novo. Se o
  Google recusar o refresh, ele **limpa os dois tokens do usuário** e levanta
  `TokenExpiredError` → o usuário precisa re-logar.

```ruby
def refresh_access_token!
  raise_token_expired if @user.google_refresh_token.blank?

  tokens = @oauth_service.refresh_access_token(@user.google_refresh_token)
  @user.update!(google_access_token: tokens["access_token"])
rescue GoogleOauthService::RefreshError
  @user.update!(google_access_token: nil, google_refresh_token: nil)
  raise_token_expired
end
```

As exceções customizadas (`ApiError`, `TokenExpiredError`) são definidas dentro do service e
**tratadas no controller**, virando status HTTP apropriados (502 ou 401).

---

## 6. Os fluxos de ponta a ponta

### 6.1 Login OAuth (Google → JWT próprio)

```
1. GET /auth/login
   AuthController#login → redirect 302 para a URL do Google (GoogleOauthService#authorization_url)

2. Usuário autoriza no Google → Google redireciona para
   GET /auth/callback?code=XXXX

3. AuthController#callback:
   a. exchange_code(code)        → troca o code por { access_token, refresh_token }
   b. fetch_userinfo(token)      → pega { sub, email, name }
   c. upsert_user(...)           → User.find_or_initialize_by(google_id:) e salva tokens
   d. issue_jwt(user)            → emite NOSSO JWT (com user_id)
   e. redirect 302 para  <FRONTEND_URL>/auth/callback#token=<jwt>
```

Detalhes que valem reparar:

- O token/erro vai sempre no **fragment** (`#token=...`), nunca na query string. Fragment não
  é enviado ao servidor nem fica em logs — o SPA lê via JavaScript.
- `find_or_initialize_by` = busca; se não achar, instancia (sem salvar ainda). Depois
  `assign_attributes` + `save!`. É o padrão de **upsert** (cria-ou-atualiza).
- O `refresh_token` só vem do Google na primeira autorização — por isso o `||` preserva o
  antigo: `tokens["refresh_token"] || user.google_refresh_token`.
- Tudo está dentro de um `rescue StandardError` que redireciona com `#error=auth_failed` em
  vez de estourar um 500 cru pro navegador.

### 6.2 Sync de cursos — `POST /courses/sync`

```ruby
def sync
  service = GoogleClassroomService.new(user: current_user)
  courses = upsert_courses(service.fetch_courses)
  render json: { synced: courses.size, courses: courses.as_json(only: %i[...]) }
rescue GoogleClassroomService::TokenExpiredError => e
  render json: { error: "token_expired", ... }, status: :unauthorized
rescue GoogleClassroomService::ApiError => e
  render json: { error: "classroom_api_error", ... }, status: :bad_gateway
end
```

`upsert_courses` envolve tudo numa **transação** (`ActiveRecord::Base.transaction`): ou todos
os cursos são salvos, ou nenhum (rollback se der erro no meio). O upsert usa o índice único
`(user_id, google_course_id)` pra não duplicar — `assignments` tem o equivalente em
`(user_id, course_id, google_assignment_id)`.

### 6.3 Sync de tarefas — `POST /assignments/sync`

Igual em espírito, mas itera sobre cada curso do usuário. Detalhe importante de design,
documentado no próprio código:

```ruby
def upsert_assignments(service)
  current_user.courses.find_each.sum do |course|
    # A busca HTTP fica FORA da transação: um refresh malsucedido limpa os
    # tokens do usuário e essa limpeza não pode ser desfeita por rollback.
    course_work = service.fetch_course_work(course.google_course_id)
    upsert_course_work(course, course_work)
  end
end
```

- A chamada HTTP fica **fora** da transação de propósito (o comentário explica: se o refresh
  falha e limpa os tokens, não queremos que um rollback "desfaça" essa limpeza — ela tem que
  persistir). Só o `upsert_course_work` (escrita no banco) roda dentro da transação.
- `find_each` itera em lotes (escala melhor que carregar tudo de uma vez).
- Durante o upsert, calcula `auto_priority` e normaliza o `state` do Classroom
  (`PUBLISHED` → `CREATED`; estados desconhecidos caem em `CREATED`).

### 6.4 Editar prioridade — `PATCH /assignments/:id/priority`

```ruby
def update_priority
  assignment = Assignment.find_by(id: params[:id], user: current_user)
  return render json: { error: "not_found" }, status: :not_found if assignment.nil?

  assignment.update!(manual_priority: params[:manual_priority])
  render json: assignment.as_json(only: %i[id title manual_priority auto_priority due_date state course_id])
rescue ActiveRecord::RecordInvalid, ActiveRecord::RangeError, ActiveModel::RangeError
  render json: { error: "invalid_priority" }, status: :unprocessable_content
end
```

Repare no `find_by(id:, user: current_user)`: a busca já **escopa pelo dono**. Um usuário não
consegue editar a tarefa de outro — se o id não for dele, `find_by` devolve `nil` → 404. Esse
é o padrão de segurança multi-tenant do projeto, presente em todos os endpoints.

Valores inválidos de `manual_priority` (não inteiro, < 1, ou fora do alcance de um
`integer` de 4 bytes do PostgreSQL) respondem `422 { "error": "invalid_priority" }`:
a validação do model cobre os dois primeiros casos (`RecordInvalid`) e os `RangeError`
cobrem o estouro de int4, que só aparece na hora de serializar pro banco.

---

## 7. Resumo dos endpoints

| Método | Rota | Auth | Controller#action | O que faz |
|---|---|---|---|---|
| GET | `/health` | — | `health#index` | Healthcheck `{status:"ok"}` |
| GET | `/auth/login` | — | `auth#login` | Redireciona pro Google |
| GET | `/auth/callback` | — | `auth#callback` | Troca code→tokens, upsert user, emite JWT, redireciona pro front |
| GET | `/auth/me` | Bearer | `auth#me` | Dados do usuário logado |
| POST | `/courses/sync` | Bearer | `courses#sync` | Busca cursos no Classroom e faz upsert |
| POST | `/assignments/sync` | Bearer | `assignments#sync` | Busca tarefas e calcula auto_priority |
| PATCH | `/assignments/:id/priority` | Bearer | `assignments#update_priority` | Define prioridade manual (422 se inválida) |
| GET | `/dashboard` | Bearer | `dashboard#index` | Tarefas `CREATED` ordenadas por prioridade efetiva |

---

## 8. Pontos de atenção conhecidos

Limitações conscientes do backend atual, levantadas na revisão de 2026-06-11. Nenhuma
bloqueia o uso; estão aqui para não serem esquecidas.

| # | Ponto | Por que importa | Quando tratar |
|---|---|---|---|
| 1 | O fluxo OAuth não usa o parâmetro `state` | Sem ele, o callback é vulnerável a *login-CSRF* (um atacante pode forçar o navegador da vítima a completar o login na conta dele). A correção exige um nonce em cookie assinado no domínio da API + middleware de cookies no Rails API-only | Backlog (decisão de 2026-06-11: adiado) |
| 2 | Tokens Google (`google_access_token` / `google_refresh_token`) ficam em texto puro no banco | Um vazamento do banco expõe acesso ao Classroom dos usuários. A correção é o Active Record Encryption (`encrypts`), que exige 3 chaves novas em env (local + Railway) e tratamento dos dados já gravados | Backlog (adiado) |
| 3 | `map_state` mistura o estado do *courseWork* (`PUBLISHED`/`DRAFT`) com estados de *submissão* (`TURNED_IN`...) | O estado "real" da tarefa do aluno vem das `studentSubmissions`, não do courseWork | Épico **B-8** (sync de submissões) |
| 4 | O sync nunca **remove** cursos/tarefas apagados no Classroom | Registros órfãos ficam para sempre no banco e no dashboard | Candidato a épico futuro (B-10 já mexerá no sync) |
| 5 | `auto_priority` envelhece entre syncs | É "dias até o prazo" congelado no momento do sync; sem sincronizar, a ordenação desatualiza | Mitigado pelo auto-sync com throttle de 1h do **B-10** |
| 6 | `due_date` é `datetime` mas só guarda a data (ignora o `timeOfDay` do Google) | Tarefas com hora-limite no mesmo dia empatam na priorização | Melhoria futura |

---

## 9. Glossário rápido de Rails/Ruby (para consulta)

| Termo | Significado |
|---|---|
| `ActionController::API` | Classe base de controller sem as partes de view/HTML |
| `before_action :x` | Roda o método `x` antes da action; pode interromper a requisição |
| `params` | Hash com dados da requisição (query, body, segmentos da rota) |
| `render json:` | Serializa um objeto em JSON e responde |
| `@variavel` | Variável de instância — vive durante uma requisição |
| `ApplicationRecord` | Classe base dos models (ActiveRecord = o ORM) |
| `has_many` / `belongs_to` | Declaram associações entre tabelas |
| `validates` | Regras que rodam antes de salvar |
| `find_by` | Busca 1 registro; devolve `nil` se não achar |
| `find_or_initialize_by` | Busca ou instancia (sem salvar) — base do upsert |
| `update!` / `save!` | Salvam; o `!` faz levantar exceção em caso de falha |
| `as_json(only: [...])` | Serializa só os campos listados |
| `ActiveRecord::Base.transaction` | Tudo-ou-nada: rollback se der erro no bloco |
| `module_function` | Torna métodos de um módulo chamáveis como `Modulo.metodo` |
| `yield` | Executa o bloco passado para o método |
| `rescue` | Captura exceções |
| `ENV.fetch("X")` | Lê env var; sem default, explode se faltar |
