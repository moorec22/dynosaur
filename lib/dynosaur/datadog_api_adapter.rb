require "time"
require "datadog_api_client"

module Dynosaur
  class DatadogApiAdapter
    def initialize(api_key, app_id)
      @api_key = api_key
      @app_id = app_id
    end

    # Returns a timeseries of a metric over a specific time period. The metric is rolled up,
    # as a count, over 60 second intervals
    #
    # metric_name: The name of the metric that is retrieved
    # from: epoch time in seconds, marking the start of the interval. Defaults to 10 minutes ago.
    # to: epochi time in seconds, marking the end of the interval. Defaults to now.
    def get_metric(metric_name, from: (Time.now.utc - (60 * 10)).iso8601, to: Time.now.utc.iso8601)
      api_instance = DatadogAPIClient::V1::MetricsAPI.new
      response = api_instance.query_metrics(
        from,
        to,
        "#{metric_name}{service:backend.heroku-router,env:prod}.rollup(count, 60)"
      )
      return response.message unless response.status == "ok"

      response.series.first.pointlist
    end
  end
end
