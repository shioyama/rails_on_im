Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  scope module: "my_app/application" do
    # Defines the root path route ("/")
    root "posts#index"
  end
end
