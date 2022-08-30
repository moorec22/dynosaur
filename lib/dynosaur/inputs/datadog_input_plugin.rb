require 'dynosaur/new_relic_api_client'
require 'dynosaur/version'
require 'dynosaur/error_handler'

# ScalerPlugin implementation that uses the New Relic API
# to get the current requests per minute on the site, and scale to an
# appropriate number of dynos.

module Dynosaur
  module Inputs
    class DatadogInputPlugin < AbstractInputPlugin
      DEFAULT_RPM_PER_DYNO = 150

      # Load config from the config hash
      def initialize(config)
        super

        @api_key = config["api_key"].to_s
        @app_key = config["app_key"].to_s
        @rpm_per_dyno = config.fetch("rpm_per_dyno", DEFAULT_RPM_PER_DYNO).to_i


        raise "The hysteresis_period must be longer than 120s for Datadog" if @hysteresis_period < 120
        raise "You must supply the api_key in the datadog plugin config" if @api_key.blank?
        raise "You must supply the app_key in the new relic plugin config" if @api_key.blank?

        @metric_name = "sum:trace.http_server.queue.hits"
      end

      def retrieve
        begin
          # New Relic is not very accurate and sometimes returns data for the
          # current minute, as if it was already complete.
          # This is not an issue here because we always use the max value from
          # the ring buffer. This would become an issue if we had an
          # hysteresis_period smaller than 1 minute.
          to_time = Time.now.iso8601
          @datadog_api_client.get_metric(@metric_name, from: to_time - @hysteresis_period, to: to_time)
        rescue StandardError => e
          Dynosaur::ErrorHandler.handle(e)
          puts "ERROR: failed to decipher Datadog result"
          puts e.inspect
        end
      end

      def value_to_resources(value)
        return -1 if value.nil?

        (value / @rpm_per_dyno.to_f).ceil
      end

      private

      def datadog_api_client
        @datadog_api_client ||= Dynosaur::DatadogApiAdapater.new(@api_key, @app_key)
      end
    end
  end
end
