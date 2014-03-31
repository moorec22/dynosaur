# This file was generated by the `rspec --init` command. Conventionally, all
# specs live under a `spec` directory, which RSpec adds to the `$LOAD_PATH`.
# Require this file using `require "spec_helper"` to ensure that it is only
# loaded once.

require 'pry'

# See http://rubydoc.info/gems/rspec-core/RSpec/Core/Configuration
RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
  config.filter_run :focus

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = 'random'
end

def get_config_with_test_plugin(num_plugins=1)
  api_key = SecureRandom.uuid
  app_name = SecureRandom.uuid
  config = {
    "scaler" => {
      "min_web_dynos" => 3,
      "max_web_dynos" => 27,
      "heroku_api_key" => api_key,
      "heroku_app_name" => app_name,
      "dry_run" => true,
      "interval" => 0.1,

    }
  }
  plugins = []
  num_plugins.times { |i|
    plugins << {
      "name" => "random_#{i}",
      "type" => "RandomPlugin",
      "seed" => 1234,
      "hysteresis_period" => 30
    }
  }
  config["plugins"] = plugins

  return config
end
