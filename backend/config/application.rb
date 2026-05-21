require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "rails/test_unit/railtie"

Bundler.require(*Rails.groups)

module ClassHelper
  class Application < Rails::Application
    config.load_defaults 7.2
    config.api_only = true
    config.active_record.default_timezone = :utc
    config.time_zone = "UTC"
  end
end
