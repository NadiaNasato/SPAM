#!/usr/bin/ruby

require 'run-common.rb'
require 'project_app.rb'

Rack::Handler::CGI.run ProjectApp.new
