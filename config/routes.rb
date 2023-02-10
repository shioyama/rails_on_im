Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  scope module: "my_app/application" do
    resources :posts do
      resources :comments, only: [:new, :destroy, :create]
    end

    # Demonstrate that routes load constants from application namespace.
    get "ping", to: "ping#index", constraints: RestrictedAccess::RouteConstraint.new

    # Defines the root path route ("/")
    root "posts#index"
  end
end
