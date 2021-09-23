# frozen_string_literal: true

ENV["RACK_ENV"] ||= "development"

require_relative "quince_sinatra/version"
require "sinatra/base"
require "sinatra/reloader" if ENV["RACK_ENV"] == "development"
require "rack/contrib"
require "quince"

module Quince
  class SinatraMiddleware
    def initialize
      Quince.underlying_app = Class.new(Sinatra::Base) do
        configure :development do
          if Object.const_defined? "Sinatra::Reloader"
            register Sinatra::Reloader
            dont_reload __FILE__
            also_reload $0
          end
        end
        use Rack::JSONBodyParser
        set :public_folder, File.join(File.dirname(File.expand_path($0)), "public")
      end
    end

    def create_route_handler(verb:, route:, component: nil, &blck)
      meth = case verb
        when :POST, :post
          :post
        when :GET, :get
          :get
        else
          raise "invalid verb"
        end
      handler = component ? ->(_) { component } : blck
      Quince::SinatraMiddleware.send(:routes)[[verb, route]] = handler

      Quince.underlying_app.public_send meth, route do
        handler = Quince::SinatraMiddleware.send(:routes)[[verb, route]]
        Quince.to_html(handler.call(params))
      end
    end

    private_class_method def self.routes
                           @routes ||= {}
                         end
  end
end

Quince.middleware = Quince::SinatraMiddleware.new

at_exit do
  if $!.nil? || ($!.is_a?(SystemExit) && $!.success?)
    if Object.const_defined? "Sinatra::Reloader"
      app_dir = Pathname(File.expand_path($0)).dirname.to_s
      $LOADED_FEATURES.each do |f|
        next unless f.start_with? app_dir

        Quince.underlying_app.also_reload f
      end
    end

    Quince.underlying_app.run!
  end
end
