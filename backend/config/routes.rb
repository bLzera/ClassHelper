Rails.application.routes.draw do
  get   "/health",                   to: "health#index"
  get   "/auth/login",               to: "auth#login"
  get   "/auth/callback",            to: "auth#callback"
  get   "/auth/me",                  to: "auth#me"
  get   "/courses",                  to: "courses#index"
  post  "/courses/sync",             to: "courses#sync"
  post  "/assignments/sync",         to: "assignments#sync"
  patch "/assignments/:id/priority", to: "assignments#update_priority"
  get   "/dashboard",                to: "dashboard#index"
end
