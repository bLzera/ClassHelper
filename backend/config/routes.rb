Rails.application.routes.draw do
  get   "/health",                   to: "health#index"
  get   "/auth/login",               to: "auth#login"
  get   "/auth/callback",            to: "auth#callback"
  get   "/auth/me",                  to: "auth#me"
  get   "/courses",                  to: "courses#index"
  get   "/courses/:id/assignments",  to: "courses#assignments"
  post  "/courses/sync",             to: "courses#sync"
  get   "/assignments/:id",          to: "assignments#show"
  post  "/assignments/sync",         to: "assignments#sync"
  patch "/assignments/:id/priority", to: "assignments#update_priority"
  get   "/dashboard",                to: "dashboard#index"
end
