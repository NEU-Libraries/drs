Cerberus::Application.routes.draw do
  root :to => "catalog#index"

  Blacklight.add_routes(self)
  HydraHead.add_routes(self)
  # Hydra::BatchEdit.add_routes(self)

  resources :collections, :path => 'collections', except: [:index, :destroy]
  get "/collections" => redirect("/communities")

  resources :communities, only: [:show]

  resque_web_constraint = lambda do |request|
    current_user = request.env['warden'].user
    current_user.present? && current_user.respond_to?(:admin?) && current_user.admin?
  end

  constraints resque_web_constraint do
    mount Resque::Server, :at => "/resque"
  end

  # Featured Content
  get '/communities' => 'catalog#communities', as: 'catalog_communities'
  get '/theses_and_dissertations' => 'catalog#theses_and_dissertations', as: 'catalog_theses_and_dissertations'
  get '/research' => 'catalog#research', as: 'catalog_research'
  get '/presentations' => 'catalog#presentations', as: 'catalog_presentations'
  get '/datasets' => 'catalog#datasets', as: 'catalog_datasets'
  get '/faculty_and_staff' => 'catalog#faculty_and_staff', as: 'catalog_faculty_and_staff'

  # Community Specific queries
  get '/communities/:id/employees' => 'communities#employees', as: 'community_employees'
  get '/communities/:id/research' => 'communities#research_publications', as: 'community_research'
  get '/communities/:id/presentations' => 'communities#presentations', as: 'community_presentations'
  get '/communities/:id/datasets' => 'communities#datasets', as: 'community_datasets'
  get '/communities/:id/learning' => 'communities#learning_objects', as: 'community_learning_objects'
  post '/communities/:id/attach_employee/:employee_id' => 'communities#attach_employee', as: 'attach_employee'

  resources :compilations, :controller => "compilations", :path => "sets"
  get "/sets/:id/download" => 'compilations#show_download', as: 'prepare_download'
  get "/sets/:id/ping" => 'compilations#ping_download', as: 'ping_download'
  get "/sets/:id/trigger_download" => 'compilations#download', as: 'trigger_download'

  match "/sets/:id/:entry_id" => 'compilations#delete_entry', via: 'delete', as: 'delete_entry'
  match "/sets/:id/:entry_id" => 'compilations#add_entry', via: 'post', as: 'add_entry'

  get "/files/:id/provide_metadata" => "core_files#provide_metadata", as: "files_provide_metadata"
  post "/files/:id/process_metadata" => "core_files#process_metadata", as: "files_process_metadata"

  get "/files/rescue_incomplete_file" => "core_files#rescue_incomplete_file", as: 'rescue_incomplete_file'
  match "/incomplete_file/:id" => "core_files#destroy_incomplete_file", via: 'delete', as: 'destroy_incomplete_file'

  get "/files/:id/edit/xml" => "core_files#edit_xml", as: "edit_core_file_xml"
  put "/files/:id/validate_xml" => "core_files#validate_xml", as: "core_file_validate_xml"

  put '/item_display' => 'users#update', as: 'view_pref'

  get '/employees/:id' => 'employees#show', as: 'employee'
  get '/employees/:id/files' => 'employees#list_files', as: 'employee_files'
  get '/employees/:id/communities' => 'employees#communities', as: 'employee_communities'
  get '/my_drs' => 'employees#personal_graph', as: 'personal_graph'
  get '/my_files' => 'employees#personal_files', as: 'personal_files'
  get '/my_communities' => 'employees#my_communities', as: 'my_communities'


  # Facets for communities and collections
  get "/communities/:id/facet/:solr_field" => 'communities#facet', as: 'community_facet'
  get "/collections/:id/facet/:solr_field" => 'collections#facet', as: 'collection_facet'

  namespace :admin do
    # Add/Remove communities from an employee, delete employee
    resources :communities, except: [:show]
    resources :employees, only: [:index, :edit, :update, :destroy]
    resources :statistics, only: [:index]
  end

  namespace :api, defaults: {format: 'json'} do
    namespace :v1 do
      # handles
      get "/handles/get_handle/*url" => "handles#get_handle", as: "get_handle", :defaults => { :format => 'json' }, :url => /.*/
      post "/handles/create_handle/*url" => "handles#create_handle", as: "create_handle", :defaults => { :format => 'json' }, :url => /.*/
    end
  end

  resource :shopping_cart, :path => "download_queue", :controller => "shopping_carts", except: [:new, :create, :edit]
  put '/download_queue' => 'shopping_carts#update', as: 'update_cart'
  get '/download_queue/download' => 'shopping_carts#download', as: 'cart_download'
  get '/download_queue/fire_download' => 'shopping_carts#fire_download', as: 'fire_download'

  get '/admin' => 'admin#index', as: 'admin_panel'
  get '/admin/modify_employee' => 'admin#modify_employee', as: 'modify_employee'

  #fixing sufia's bad route
  match 'notifications/:uid/delete' => 'mailbox#delete', as: :mailbox_delete, via: [:delete]

  # Generic file routes
  resources :core_files, :path => :files, :except => [:index, :destroy] do
    member do
      get 'citation', :as => :citation
      post 'audit'
    end
  end

  devise_for :users, :controllers => { :sessions => "sessions", :omniauth_callbacks => "users/omniauth_callbacks" }

  # SUFIA
  # Downloads controller route
  resources :downloads, :only => "show"
  # "Notifications" route for catalog index view
  get "users/notifications_number" => "users#notifications_number", :as => :user_notify
  # Messages
  get 'notifications' => 'mailbox#index', :as => :mailbox
  match 'notifications/delete_all' => 'mailbox#delete_all', as: :mailbox_delete_all, via: [:get, :post]
  match 'notifications/:uid/delete' => 'mailbox#delete', as: :mailbox_delete, via: [:get, :post]

  get ':action' => 'static#:action', constraints: { action: /help|terms/ }, as: :static

  # This must be the very last route in the file because it has a catch all route for 404 errors.
  # This behavior seems to show up only in production mode.
  # mount Sufia::Engine => '/'


  # The priority is based upon order of creation:
  # first created -> highest priority.

  # Sample of regular route:
  #   match 'products/:id' => 'catalog#view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   match 'products/:id/purchase' => 'catalog#purchase', :as => :purchase
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Sample resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Sample resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Sample resource route with more complex sub-resources
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', :on => :collection
  #     end
  #   end

  # Sample resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end

  # You can have the root of your site routed with "root"
  # just remember to delete public/index.html.
  # root :to => 'welcome#index'

  # See how all your routes lay out with "rake routes"

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  # match ':controller(/:action(/:id))(.:format)'
end
