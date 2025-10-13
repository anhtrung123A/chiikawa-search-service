Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      get "/search", to: "search#search"
    end
  end
end
