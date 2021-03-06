=begin 
    Copyright 2015 Wavefront Inc.
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
   limitations under the License.

=end

require 'wavefront/client/version'
require 'wavefront/exception'
require 'wavefront/mixins'
require 'json'

module Wavefront
  class Response
    class Raw
      attr_reader :response, :options

      def initialize(response, options={})
        @response = response
        @options = options
      end

      def to_s
        return @response
      end

    end

    class Ruby
      include JSON
      attr_reader :response, :options
      
      def initialize(response, options={})
        @response = response
        @options = options

        JSON.parse(response).each_pair do |k,v|
          self.instance_variable_set("@#{k}", v)	# Dynamically populate instance vars
          self.class.__send__(:attr_reader, k)		# and set accessors
        end
      end

    end

    class Graphite < Wavefront::Response::Ruby
      include Wavefront::Mixins
      attr_reader :response, :graphite, :options

      def initialize(response, options={})
        super
        options[:prefix_length] ||= 1     # See also Wavefront::Client
        
        @graphite = Array.new
        self.timeseries.each do |ts|

          output_timeseries = Hash.new
          output_timeseries['target'] = interpolate_schema(ts['label'], ts['host'], options[:prefix_length])

          datapoints = Array.new
          ts['data'].each do |d|
            datapoints << [d[1], d[0]]
          end

          output_timeseries['datapoints'] = datapoints
          @graphite << output_timeseries 

        end
      end

    end

    class Highcharts < Wavefront::Response::Ruby
      include JSON
      attr_reader :response, :highcharts, :options

      def initialize(response, options={})
        super

        @response = JSON.parse(response)
	      @highcharts = []
	      self.timeseries.each do |series|
          # Highcharts expects the time in milliseconds since the epoch
          # And for some reason the first value tends to be BS
          # We also have to deal with missing (null/nil) data points.
          amended_data = Array.new
          next unless series['data'].size > 0
          series['data'][1..-1].each do |time_value_pair|
            if time_value_pair[0]
              time_value_pair[0] = time_value_pair[0] * 1000
            else
              time_value_pair[0] = "null"
            end
            amended_data << time_value_pair
          end
          @highcharts << { 'name' => series['label'],  'data' => amended_data }
        end
      end

      def to_json
        @highcharts.to_json
      end
    end

  end
end
