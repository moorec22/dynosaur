require 'spec_helper'
require 'dynosaur/controllers/rediscloud_controller_plugin'
require 'dynosaur/inputs/rediscloud_memory_usage_input_plugin'

describe Dynosaur::Controllers::RediscloudControllerPlugin do
  let(:input_plugin_config) {
    {
      "name" => 'test',
      "type" => 'Dynosaur::Inputs::RediscloudMemoryUsageInputPlugin',
      "component_id" => 42,
    }
  }
  let(:controller_plugin) {
    Dynosaur::Controllers::RediscloudControllerPlugin.new({
      "name" => 'test controller',
      'input_plugins' => [input_plugin_config],
    })
  }

  it { expect(controller_plugin).not_to be_nil }

  describe '#get_combined_estimate' do
    context 'with only one value' do
      it "returns the max estimated" do
        stub_redis_memory_usage(70)
        expect(controller_plugin.get_combined_estimate['name']).to eq('rediscloud:100')
      end
    end

    context 'with multiple values' do
      before do
        input_plugin = controller_plugin.input_plugins[0]
        input_plugin.instance_variable_set(:@interval, 0)
      end
      it "returns the max estimated" do
        stub_redis_memory_usage(120)
        controller_plugin.get_combined_estimate
        stub_redis_memory_usage(30)
        expect(controller_plugin.get_combined_estimate['name']).to eq('rediscloud:250')
      end
    end

    context 'with a max resource' do
      before do
        input_plugin = controller_plugin.input_plugins[0]
        input_plugin.instance_variable_set(:@interval, 0)
        rediscloud_250 = AddonPlan.new(Dynosaur::Addons.all['rediscloud'].find{|plan| plan['name'] == 'rediscloud:250'})
        controller_plugin.instance_variable_set(:@max_resource, rediscloud_250)
      end
      it "returns the max estimated" do
        stub_redis_memory_usage(2000)
        controller_plugin.get_combined_estimate
        stub_redis_memory_usage(2500)
        expect(controller_plugin.get_combined_estimate['name']).to eq('rediscloud:250')
      end
    end

    context 'with a min resource' do
      before do
        input_plugin = controller_plugin.input_plugins[0]
        input_plugin.instance_variable_set(:@interval, 0)
        rediscloud_250 = AddonPlan.new(Dynosaur::Addons.all['rediscloud'].find{|plan| plan['name'] == 'rediscloud:250'})
        controller_plugin.instance_variable_set(:@min_resource, rediscloud_250)
      end
      it "returns the max estimated" do
        stub_redis_memory_usage(5)
        controller_plugin.get_combined_estimate
        stub_redis_memory_usage(10)
        expect(controller_plugin.get_combined_estimate['name']).to eq('rediscloud:250')
      end
    end
  end
end