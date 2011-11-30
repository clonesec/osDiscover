Greenbone::Application.routes.draw do
  get "latest-reports/:id" => "reports#latest_reports"
  get "latest-schedules/:id" => "tasks#latest_schedules"
  
  devise_for :users

  resources :openvas_users

  resources :tasks
  get 'start_schedule/:id'          => 'tasks#start_task',          :as => 'start_task'
  get 'pause_schedule/:id'          => 'tasks#pause_task',          :as => 'pause_task'
  get 'resume_paused_schedule/:id'  => 'tasks#resume_paused_task',  :as => 'resume_paused_task'
  get 'stop_schedule/:id'           => 'tasks#stop_task',           :as => 'stop_task'
  get 'resume_stopped_task/:id' => 'tasks#resume_stopped_task', :as => 'resume_stopped_task'
  get 'ajax_task'                   => 'tasks#ajax_task', :as => 'ajax_task'
  root :to => 'pages#index'

  resources :reports
  get 'view_report/:id' => 'reports#view_report', :as => 'view_report'
  get 'reports'         => 'reports#index',       :as => 'reports'


  resources :report_formats
  get 'export_report_format/:id' => 'report_formats#export_report_format', :as => 'export_report_format'
  get 'verify_report_format/:id' => 'report_formats#verify_report_format', :as => 'verify_report_format'

  resources :scan_targets

  resources :scan_configs
  get 'export_config/:id' => 'scan_configs#export_config', :as => 'export_config'
  get 'export_preference_file/:id' => 'scan_configs#export_preference_file', :as => 'export_preference_file'

  resources :schedules

  get 'settings' => 'admin_settings#index', :as => 'settings'

  get 'feeds' => 'nvt_feeds#index', :as => 'feeds'
  get 'sync_feed' => 'nvt_feeds#sync_feed', :as => 'sync_feed'

  resources :system_reports

  resources :preferences

  resources :escalators
  get 'test_escalator/:id' => 'escalators#test_escalator', :as => 'test_escalator'

  resources :slaves
  # note: rails sees the singular of 'slaves' as 'slafe'

  resources :credentials
  get 'download_public_key/:id' => 'credentials#download_public_key', :as => 'download_public_key'
  get 'download_format/:id' => 'credentials#download_format', :as => 'download_format'

  resources :notes

  resources :overrides

  resources :agents
  get 'verify_agent/:id' => 'agents#verify_agent', :as => 'verify_agent'
  get 'download_agent/:id' => 'agents#download_agent', :as => 'download_agent'
  
  get "details" => "pages#details", :as => "details"
  get "help" => "pages#help", :as => "help"
  get "monitor" => "pages#monitor", :as => "monitor"
  get "schedule-graph" => "pages#schedule_graph"
  get "report-graph" => "pages#report_graph"
  
end