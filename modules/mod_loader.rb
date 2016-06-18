#!/usr/bin/ruby

PARENT = File.dirname(__FILE__)

# Carico le gemme
%w(rubygems sinatra net/http rest_client rexml/document rdf/rdfxml tree).each  { |gem| require gem}

# Carico i moduli
%w(model login server_reply new_post retrieve_post related_post related_post_list resource_manager socialite).each {|mod| require File.join(PARENT, "#{mod}")}
