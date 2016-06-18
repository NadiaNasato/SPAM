#!/usr/bin/ruby

require 'run-common.rb'
require 'project_app.rb'

server_options = {
	:app => ProjectApp.new,
	:Port => 9090
}

server = Rack::Server.new(server_options)
server.instance_variable_set('@app', server_options[:app])
server.start
