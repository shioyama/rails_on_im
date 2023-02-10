require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module MyApp
  module ImReloader
    def reload
      super.tap { Application.reload }
    end
  end

  # Define a custom routes reloader which loads route file(s) under the
  # Application namespace. This allows application constants to be referenced
  # in `config/routes.rb` (and any other route files) at toplevel.
  class RoutesReloader < ::Rails::Application::RoutesReloader
    def load(path)
      super(path, Application)
    end
  end

  class RailsApplication < Rails::Application
    # We need to create the loader here and assign it to the Application
    # constant so that initializers can be loaded under it. Those initializers
    # cannot actually access constants under it until the
    # :setup_application_loader initializer has been run, but that's fine since
    # you're not able to access Zeitwerk-loaded constants outside of
    # `to_prepare` blocks anyway, and those are only run later in boot.
    loader = Im::Loader.new
    loader.tag = "rails.main"
    loader.inflector = Rails::Autoloaders::Inflector

    def loader.use_relative_model_naming?
      true
    end

    ::MyApp::Application = loader

    initializer :setup_application_loader, before: :setup_main_autoloader do
      app_paths = ActiveSupport::Dependencies.autoload_paths.select do |path|
        path.start_with?(Rails.root.to_s)
      end
      ActiveSupport::Dependencies.autoload_paths -= app_paths

      app_paths.each do |path|
        next unless File.directory?(path)

        loader.push_dir(path)
        loader.do_not_eager_load(path) unless ActiveSupport::Dependencies.eager_load?(path)
      end

      unless config.cache_classes
        loader.enable_reloading

        # Ensure that every time Zeitwerk is reloaded, Im is too.
        Rails.autoloaders.main.extend(ImReloader)

        loader.on_load do |_cpath, value, _abspath|
          if value.is_a?(Class) && value.singleton_class < ActiveSupport::DescendantsTracker
            ActiveSupport::Dependencies._autoloaded_tracked_classes << value
          end
        end
      end

      loader.setup

      # We need to add these explicitly because we removed them from autoload paths.
      loader.autoloads.keys.each do |path|
        if path.end_with?(".rb")
          config.watchable_files << path
        else
          config.watchable_dirs[path] = [:rb]
        end
      end
    end

    def routes_reloader
      @routes_reloader ||= RoutesReloader.new
    end

    # We patch `load` to catch the call to `Kernel#load` so we can inject the
    # application to ensure initializers are loaded under it. This way,
    # constants can be referenced in initializers at toplevel.
    def load(initializer)
      super(initializer, Application)
    end

    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # We need to disable this to avoid ActionPack trying to load
    # ApplicationHelper when it sees app/helpers/application_helper.rb. This
    # won't work since our ApplicationHelper is under MyApp::Application.
    config.action_controller.include_all_helpers = false
  end
end
