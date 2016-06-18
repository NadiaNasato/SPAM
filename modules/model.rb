#!/usr/bin/ruby

$KCODE="u"

require 'rubygems'
require 'dm-core'
require 'dm-timestamps'
require 'dm-aggregates'
require 'dm-migrations'
require 'dm-yaml-adapter'

DataMapper::setup(:default, "yaml://#{Dir.pwd}/models")

class Server
  include DataMapper::Resource
  property :serverID, String, :key => true
  property :serverURL, String, :key => true

  # Metodo per l'estrazione di un server
  # a partire dal suo ID
  def self.find_by_id(sID)
    s = first(:serverID.like => "%#{sID}%")
    return s
  end
end

class User
  include DataMapper::Resource
  property :userID, Serial
  property :username, String

  # Metodo wrapper per la ricerca nel database
  def self.find(username)
    u = first(:username => username)
    return u
  end
end

class ServerList
  include DataMapper::Resource
  property :userID, Integer, :key => true
  property :serverID, String, :key => true
  property :serverURL, String, :key => true

  def self.find(userID, serverID)
    s = first(:userID => userID, :serverID => serverID)
    return s
  end

  def self.find_by_id(sID)
    s = first(:serverID.like => "%#{sID}%")
    return s
  end
end

class Post
  include DataMapper::Resource
  property :postID, Serial
  property :body, String, :required => true
  property :created_at, DateTime
  belongs_to :user

  def self.body
    return self.body
  end

  def self.find(postID)
    p = first(:postID => postID)
    return p
  end
end

class Hashtag
  include DataMapper::Resource
  property :name, String, :key => true
  property :postID, Integer, :key => true
end

class Preference
  include DataMapper::Resource
  property :serverID, String, :key => true
  property :userID, String, :key => true
  property :postID, Integer, :key => true
  property :username, String
  property :value, Integer

  def self.find(serverID, userID, postID, username)
    preference = first(:serverID => serverID, :userID => userID, :postID => postID, :username => username)
    return preference
  end

  def self.find_my_preference(serverID, postID, username)
    preference = first(:serverID => serverID, :postID => postID, :username => username)
    return preference
  end
end

class Friendship
  include DataMapper::Resource
  property :followed, String, :key => true
  property :follower, String, :key => true

  def self.find(followed, follower)
    mates = first(:followed => followed, :follower => follower)
    return mates
  end
end

DataMapper.finalize
