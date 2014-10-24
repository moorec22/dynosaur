
module Dynosaur
  module Controllers
    class AbstractControllerPlugin < Dynosaur::BasePlugin

      DEFAULT_HYSTERESIS_PERIOD = 300    # seconds we must be below threshold before reducing estimated dynos
      DEFAULT_INTERVAL = 60

      attr_reader :input_plugins, :interval, :current_estimate, :current,
        :dry_run, :buffer_size

      def initialize(config)
        super(config)

        @value = nil
        @interval = config.fetch("interval", DEFAULT_INTERVAL).to_f
        hysteresis_period = config.fetch("hysteresis_period", DEFAULT_HYSTERESIS_PERIOD).to_f
        @buffer_size = hysteresis_period / @interval  # num intervals to keep
        # State variables
        @stopped = false
        @current_estimate = 0
        @current = 0
        @dry_run = config.fetch("dry_run", false)

        load_input_plugins config['input_plugins']
      end

      def load_input_plugins(input_plugins_config)
        @input_plugins = []
        (input_plugins_config || []).each do |input_plugin_config|
          @input_plugins << load_input_plugin(input_plugin_config)
        end
      end

      def load_input_plugin(input_plugin_config)
        # Load the class and instanciate it
        begin
          klass = Kernel.const_get(input_plugin_config['type'])
          return klass.new(input_plugin_config, self)
        rescue NameError => e
          raise "Could not load #{input_plugin_config['type']}, #{e.message}"
        end
      end

      def heroku_manager
        @heroku_manager ||= HerokuManager.new(@heroku_api_key, @heroku_app_name, @dry_run)
      end


      def get_combined_estimate
        estimates = []
        details = {}
        now = Time.now
        # Get the estimated dynos from all configured plugins
        @input_plugins.each { |plugin|
          value = plugin.get_value
          estimate = plugin.estimated_resources  # minor race condition, but only matters for logging
          health = "OK"
          if now - plugin.last_retrieved_ts > interval
            health = "STALE"
          end
          details[plugin.name] = {
            "estimate" => estimate,
            "value" => value,
            "unit" => plugin.unit,
            "last_retrieved" => plugin.last_retrieved_ts,
            "health" => health

          }
          estimates << estimate
        }
        @last_results = details


        # Combine the estimates and mo
        combined_estimate = estimates.max

        combined_estimate = [@max_web_dynos, combined_estimate].min
        combined_estimate = [@min_web_dynos, combined_estimate].max

        return combined_estimate
      end

      # Modify config at runtime
      def set_config(config)
        puts "Dynosaur reconfig:"
        pp  config

        if config.has_key?("scaler")
          puts "Modifying scaler config"
          global_config(config["scaler"])
        end
        if config.has_key?("plugins")
          config["plugins"].each { |plugin_config|
            found = nil
            @plugins.each { |plugin|
              if plugin.name == plugin_config["name"]
                puts "Replacing config for #{plugin.name}"
                @plugins.delete(plugin)
              end
            }
            if found.nil?
              puts "Configuring new plugin"
            end
            @plugins << config_one_plugin(plugin_config)
          }
        end
      end

      def scale
        raise NotImplementedError.new("You must define scale in your controller")
      end

      def run
        now = Time.now

        before = heroku_manager.get_current_dynos
        @current_estimate = get_combined_estimate

        if @current_estimate != before
          scale
        end
        after = heroku_manager.get_current_dynos

        if before != after
          puts "CHANGE: #{before} => #{after}"
          @last_change_ts = Time.now
        end
        @current = after
        details = ""
        @last_results.each { |name, result|
          details += "#{name}: #{result["value"]}, #{result["estimate"]}; "
        }
        puts "#{now} [combined: #{@current_estimate}]  #{details}"

        handle_stats(now, @current_estimate, before, after)
      end

    end # AbstractControllerPlugin
  end # Controllers
end # Dynosaur
