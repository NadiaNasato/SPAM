#!/usr/bin/ruby
# -*- coding: utf-8 -*-

$KCODE = 'u' if RUBY_VERSION < '1.9'

require 'thread'
require 'modules/mod_loader'

include ResourceManager
include Login
include ServerReply
include NewPost
include RetrievePost
include Socialite


# ******************************************************************************
# **                            Routes matching                               **
# ******************************************************************************
class ProjectApp < Sinatra::Base
  include REXML

  #-----------------------------------------------------------------------------
  #----------------------------------- SETUP -----------------------------------
  #-----------------------------------------------------------------------------
  configure do

    ROOT = File.dirname(__FILE__)

    set :static, true
    set :public, ROOT + '/public/'
    set :views, ROOT + '/views/'

    # Middleware per la gestione cookie
    use Rack::Session::Pool, :expire_after => 2591500

    # Variabili globali
    @@SERVER_ID = 'NetForce'
    @@SERVER_LIST = 'resources/server.xml'
    @@THESAURUS = 'resources/ltw1114-thesaurus.xml'

    # Parametri per il calcolo dell'affinita'
    @@FRESHNESS = 1  # Freshness multiplier
    @@RELATEDNESS = 10  # Relatedness multiplier

    @@semaphore_server = Mutex.new

  end


  #-----------------------------------------------------------------------------
  #------------------------------------ HOME -----------------------------------
  #-----------------------------------------------------------------------------
  get '/' do
    redirect to 'index.html', 302
  end


  #-----------------------------------------------------------------------------
  #--------------------------- GESTIONE AUTENTICAZIONE -------------------------
  #-----------------------------------------------------------------------------
  get '/login' do

    status, headers, body = error_response(405, 'Method not implemented yet') # Method Not Allowed
    return [status, headers, body]
  end


  post '/login' do

    u = login(params[:username], @@semaphore_server)

    if u.nil?
      status, headers, body = error_response(400, 'Username must not be empty') # Bad Request
      return [status, headers, body]

    else
      @user = u
      status = 200 # OK
      response.set_cookie("ltwlogin", {:value => "#{@user.username}", :path => '/'})
      return [status, response, ""]
    end
  end


  get '/logout' do

    status, headers, body = error_response(405, 'Method not implemented yet') # Method Not Allowed
    return [status, headers, body]
  end


  post '/logout' do

    if logout(@user)
      session.clear
      @user = nil
      status = 200 # OK
      response.delete_cookie("ltwlogin")
      return [status, response, ""]

    else
      status, headers, body = error_response(401, 'Unauthorized')
      return [status, headers, body]
    end
  end


  #-----------------------------------------------------------------------------
  #------------------------------- CREAZIONE POST ------------------------------
  #-----------------------------------------------------------------------------
  post '/post' do
    
    if not @user.nil?
      
      repo = load_thesaurus(@user.username)
      tags = load_admitted_tags(repo)

      if spam(@@SERVER_ID, @user, params[:article], tags)
        return 201 # Created
    
      else
        status, headers, body = error_response(400, 'Format not allowed')
        return [status, headers, body]
      end
    
    else
      status, headers, body = error_response(401, 'You should authenticate first')
      return [status, headers, body]
    end
  end


  post '/respam' do

    if not @user.nil?
      sID, uID, pID = params[:serverID], params[:userID], params[:postID]
      post = ""
      check = false

      # Controlla a quale Server appartiene l'autore del post oggetto del respam
      # Ricerca interna
      if sID.eql?(@@SERVER_ID)
        u = User.find(uID)

        if not u.nil?
          p = Post.find(pID)

          if not p.nil?
            post=p.body
            check = true

          else
            status, headers, body = error_response(400, 'Original post might have been deleted or is corrupted')
            return [status, headers, body]
          end

        else
          status, headers, body = error_response(400, 'Username does not match any existing user')
          return [status, headers, body]
        end

      else
        # Ricerca esterna
        s = Server.find_by_id(sID)

        if not s.nil?
          begin
            res = RestClient::Request.execute(:method => :get,
              :url => "#{s.serverURL}/postserver/#{uID}/#{pID}", :timeout => 15)

          rescue => e
            status, headers, body = error_response(400, 'Communication error')
            return [status, headers, body]
          end

          if not res.nil?
            post = res.to_s
            check = true

          else
            status, headers, body = error_response(400, 'Original post might have been deleted or is corrupted')
            return [status, headers, body]
          end

        else
          status, headers, body = error_response(400, 'Invalid input')
          return [status, headers, body]
        end
      end

      if check == true
        repo = load_thesaurus(@user.username)
        tags = load_admitted_tags(repo)

        if respam(@@SERVER_ID, @user, sID, uID, pID, post.to_s, tags)
          status = 201 # Created
          headers = ""
          body = ""
          return [status, headers, body]

        else
          status, headers, body = error_response(400, 'Format not allowed')
          return [status, headers, body]
        end
      end

    else
      status, headers, body = error_response(401, 'You should authenticate first')
      return [status, headers, body]
    end
  end


  post '/replyto' do

    if not @user.nil?

      sID, uID, pID, post = params[:serverID], params[:userID], params[:postID], params[:article]

      # Controlla che il post originale esista
      check = false
      s = nil

      if sID.eql?(@@SERVER_ID)
        u = User.find(uID)

        if not u.nil?
          p = Post.find(pID)

          if not p.nil?
            check=true

          else
            status, headers, body = error_response(400, 'Original post might have been deleted or is corrupted')
            return [status, headers, body]
          end

        else
          status, headers, body = error_response(400, 'Username does not match any existing user')
          return [status, headers, body]
        end

      else
        s = Server.find_by_id(sID)
        if not s.nil?
          begin
            res = RestClient::Request.execute(:method => :get,
              :url => "#{s.serverURL}/postserver/#{uID}/#{pID}", :timeout => 15)

          rescue #=> e
            status, headers, body = error_response(400, 'Communication error')
            return [status, headers, body]
          end

          if not res.nil?
            check = true
          else
            status, headers, body = error_response(400, 'Original post might have been deleted or is corrupted')
            return [status, headers, body]
          end
        end
      end

      # Viene effettivamente creato il post.
      if check==true
        repo = load_thesaurus(@user.username)
        tags = load_admitted_tags(repo)
        # Controlla che il nuovo post abbia un contenuto
        # -> nil se il post e' vuoto.
        new_post = reply(@@SERVER_ID, @user, sID, uID, post, pID, tags)

        # Propaga la risposta se il server di origine non e' NetForce
        if not new_post.nil?

          if not sID.eql?(@@SERVER_ID) and not s.nil?

            begin
              RestClient.post "#{s.serverURL}/hasreply", :serverID => "#{@@SERVER_ID}",
                :userID => "#{@user.username}", :postID => "#{new_post.postID}",
                :userID2Up => "#{uID}", :postID2Up => "#{pID}"

            rescue #=> e
              # Elimina il post se propagate has_reply non va a buon fine
              new_post.destroy
              htags = Hashtag.all(:postID => new_post.postID)
              htags.each do |t|
                t.destroy
              end
              status, headers, body = error_response(400, 'Communication error. Reply dropped.')
              return [status, headers, body]
            end
          end

          status = 201 # Created
          headers = ""
          body = ""
          return [status, headers, body]
        
        else
          status, headers, body = error_response(400, 'Format not allowed')
          return [status, headers, body]
        end
      end

    else
      status, headers, body = error_response(401, 'You should authenticate first')
      return [status, headers, body]
    end
  end


  #-----------------------------------------------------------------------------
  #-------------------------------- RICERCA POST -------------------------------
  #-----------------------------------------------------------------------------
  get '/search/:limit/author/:serverID/:userID' do

    if not @user.nil?
      sID = params[:serverID]

      if sID.eql?(@@SERVER_ID)
        mylist = RelatedPostList.new
        u = User.find(params[:userID])

        if not u.nil?
          # Se l'autore non ha ancora creato post, ritorna come body -> <archive></archive>
          mylist = research_by_author(mylist, @@SERVER_ID, @@SERVER_ID, u, @user.username)
          if not mylist.length == 0
            mylist = mylist.sort()
            posts = mylist.getArray[0...(filter_search(mylist.getArray, params[:limit]))]
            status, headers, body = xml_response("#{create_body(posts)}")
            return [status, headers, body]

          else
            status, headers, body = error_response(400, 'No posts found')
            return [status, headers, body]
          end

        else
          status, headers, body = error_response(400, 'Username does not match any existing user')
          return [status, headers, body]
        end

      else
        s = Server.find_by_id(sID)

        if not s.nil?
          begin
            res = RestClient::Request.execute(:method => :get,
              :url => "#{s.serverURL}/searchserver/#{params[:limit]}/author/#{params[:serverID]}/#{params[:userID]}",
              :timeout => 15)
        
          rescue #=> e
            status, headers, body = error_response(400, 'Communication error')
            return [status, headers, body]
          end

          if not res.nil?
            res = remove_others_likeness_references(res.to_s, @@SERVER_ID, @user.username)
            if not res.nil?
              status, headers, body = xml_response(res.to_s)
          
            else
              status, headers, body = error_response(400, 'Posts may be not well-formed')
            end

          else
            status, headers, body = error_response(400, 'No posts found')
          end
        
          return [status, headers, body]

        else
          status, headers, body = error_response(400, 'Invalid input')
          return [status, headers, body]
        end
      end

    else
      status, headers, body = error_response(405, 'You should authenticate first')
      return [status, headers, body]
    end
  end


  get '/search/:limit/following' do

    if not @user.nil?

      semaphore = Mutex.new
      threads = []
      mylist = RelatedPostList.new
      followeds = get_followed(@@SERVER_ID, @user.username)

      followeds.each do |f|

        threads << Thread.new do

          data = f.split('/')

          if data.at(0).eql?(@@SERVER_ID)
            u = User.find(data.at(1))
            if not u.nil?
              semaphore.synchronize {
                mylist = research_by_author(mylist, @@SERVER_ID, @@SERVER_ID, u, @user.username)
              }
            end
       
          else
            s = Server.find_by_id(data.at(0))

            if not s.nil?
              begin
                res = RestClient::Request.execute(:method => :get,
                  :url => "#{s.serverURL}/searchserver/#{params[:limit]}/author/#{data.at(0)}/#{data.at(1)}",
                  :timeout => 15)

              rescue #=> e
              end

              if not res.nil?
                res = remove_others_likeness_references(res.to_s, @@SERVER_ID, @user.username)
                if not res.nil?
                  semaphore.synchronize {
                    mylist = add_related_post_from_others(mylist, s.serverID, res)
                  }
                end
              end
            end
          end
        end
        threads.each { |t| t.join}
      end

      if not mylist.length == 0
        mylist = mylist.sort()
        posts = mylist.getArray[0...(filter_search(mylist.getArray, params[:limit]))]
        status, headers, body = xml_response("#{create_body(posts)}")
        return [status, headers, body]

      else
        status, headers, body = error_response(400, 'No posts found')
        return [status, headers, body]
      end

    else
      status, headers, body = error_response(405, 'You should authenticate first')
      return [status, headers, body]
    end
  end

  
  get '/search/:limit/recent' do

    if not @user.nil?

      semaphore = Mutex.new
      threads = []
      servers = []
      @@semaphore_server.synchronize {
        servers = ServerList.all(:userID => @user.userID)
      }
      mylist = RelatedPostList.new

      servers.each do |s|

        threads << Thread.new do

          sID = get_server_id(s.serverID)

          if not sID.nil?

            if sID.eql?(@@SERVER_ID)
              semaphore.synchronize {
                mylist = research_related_post(mylist, @@SERVER_ID, @@SERVER_ID, @user.username, "", params[:limit])
              }

            else
              begin
                res = RestClient::Request.execute(:method => :get,
                  :url => "#{s.serverURL}/searchserver/#{params[:limit]}/recent", :timeout => 15)

              rescue #=> e
              end

              if not res.nil?
                res = remove_others_likeness_references(res.to_s, @@SERVER_ID, @user.username)
                if not res.nil?
                  semaphore.synchronize {
                    mylist = add_related_post_from_others(mylist, s.serverID, res)
                  }
                end
              end
            end
          end
        end

        threads.each { |t| t.join}
      end

      if not mylist.length == 0
        mylist = mylist.sort()
        posts = mylist.getArray[0...(filter_search(mylist.getArray, params[:limit]))]
        status, headers, body = xml_response("#{create_body(posts)}")
        return [status, headers, body]

      else
        status, headers, body = error_response(400, 'No posts found')
        return [status, headers, body]
      end

    else
      status, headers, body = error_response(405, 'You should authenticate first')
      return [status, headers, body]
    end
  end


  get '/search/:limit/recent/:term' do

    if not @user.nil?

      semaphore = Mutex.new
      threads = []
      servers = []
      @@semaphore_server.synchronize {
        servers = ServerList.all(:userID => @user.userID)
      }
      mylist = RelatedPostList.new

      servers.each do |s|

        threads << Thread.new do

          sID = get_server_id(s.serverID)

          if not sID.nil?

            if sID.eql?(@@SERVER_ID)
              semaphore.synchronize {
                mylist = research_related_post(mylist, @@SERVER_ID, @@SERVER_ID, @user.username, params[:term], params[:limit])
              }

            else
              begin
                res = RestClient::Request.execute(:method => :get,
                  :url => "#{s.serverURL}/searchserver/#{params[:limit]}/recent/#{params[:term]}",
                  :timeout => 15)

              rescue #=> e
              end

              if not res.nil?
                res = remove_others_likeness_references(res.to_s, @@SERVER_ID, @user.username)
                if not res.nil?
                  semaphore.synchronize {
                    mylist = add_related_post_from_others(mylist, s.serverID, res)
                  }
                end
              end
            end
          end
        end

        threads.each { |t| t.join}
      end

      if not mylist.length == 0
        mylist = mylist.sort()
        posts = mylist.getArray[0...(filter_search(mylist.getArray, params[:limit]))]
        status, headers, body = xml_response("#{create_body(posts)}")
        return [status, headers, body]

      else
        status, headers, body = error_response(400, 'No posts found')
        return [status, headers, body]
      end

    else
      status, headers, body = error_response(405, 'You should authenticate first')
      return [status, headers, body]
    end
  end


  get '/search/:limit/related/:term' do

    if not @user.nil?

      semaphore = Mutex.new
      threads = []
      mylist = RelatedPostList.new
      servers = []
      @@semaphore_server.synchronize {
        servers = ServerList.all(:userID => @user.userID)
      }

      servers.each do |s|

        threads << Thread.new do

          sID = get_server_id(s.serverID)

          if not sID.nil?

            if sID.eql?(@@SERVER_ID)
              repo = load_thesaurus(@user.username)
              tags = load_admitted_tags(repo)
              if tags.include?(params[:term])
                related = get_related_terms(repo, params[:term])
                related.each do |term|
                  semaphore.synchronize {
                    mylist = research_related_post(mylist, @@SERVER_ID, @@SERVER_ID, @user.username, term, "all")
                  }
                end
              end

            else
              begin
                res = RestClient::Request.execute(:method => :get,
                  :url => "#{s.serverURL}/searchserver/#{params[:limit]}/related/#{params[:term]}",
                  :timeout => 15)

              rescue #=> e
              end

              if not res.nil?
                res = remove_others_likeness_references(res.to_s, @@SERVER_ID, @user.username)
                if not res.nil?
                  semaphore.synchronize {
                    mylist = add_related_post_from_others(mylist, s.serverID, res)
                  }
                end
              end
            end
          end
        end

        threads.each { |t| t.join}
      end

      if not mylist.length == 0
        mylist = mylist.sort()
        posts = mylist.getArray[0...(filter_search(mylist.getArray, params[:limit]))]
        status, headers, body = xml_response("#{create_body(posts)}")
        return [status, headers, body]
 
      else
        status, headers, body = error_response(400, 'No posts found')
        return [status, headers, body]
      end

    else
      status, headers, body = error_response(405, 'You should authenticate first')
      return [status, headers, body]
    end
  end

  
  get '/search/:limit/fulltext/:string' do

    if not @user.nil?

      if params[:string].length == 0
        status, headers, body = error_response(400, 'Invalid input')
        return [status, headers, body]
      end

      semaphore = Mutex.new
      threads = []
      mylist = RelatedPostList.new
      servers = []
      @@semaphore_server.synchronize {
        servers = ServerList.all(:userID => @user.userID)
      }

      servers.each do |s|

        threads << Thread.new do

          sID = get_server_id(s.serverID)

          if not sID.nil?

            if sID.eql?(@@SERVER_ID)
              semaphore.synchronize {
                mylist = research_fulltext(mylist, @@SERVER_ID, @@SERVER_ID, @user.username, "#{params[:string]}")
              }

            else
              begin
                res = RestClient::Request.execute(:method => :get,
                  :url => "#{s.serverURL}/searchserver/#{params[:limit]}/fulltext/#{params[:string]}",
                  :timeout => 15)

              rescue #=> e
              end

              if not res.nil?
                res = remove_others_likeness_references(res.to_s, @@SERVER_ID, @user.username)
                if not res.nil?
                  semaphore.synchronize {
                    mylist = add_related_post_from_others(mylist, s.serverID, res)
                  }
                end
              end
            end
          end
        end

        threads.each { |t| t.join}
      end

      if not mylist.length == 0
        mylist = mylist.sort()
        posts = mylist.getArray[0...(filter_search(mylist.getArray, params[:limit]))]
        status, headers, body = xml_response("#{create_body(posts)}")
        return [status, headers, body]

      else
        status, headers, body = error_response(400, 'No posts found')
        return [status, headers, body]
      end

    else
      status, headers, body = error_response(405, 'You should authenticate first')
      return [status, headers, body]
    end
  end


  get '/search/:limit/affinity/:serverID/:userID/:postID' do

    if not @user.nil?

      semaphore = Mutex.new
      threads = []
      mylist = RelatedPostList.new
      is_mine = false

      # Acquisisce post incriminato
      p1 = nil
      if params[:serverID].eql?(@@SERVER_ID)
        p1 = Post.find(params[:postID])
        is_mine = true

      else
        s = Server.find_by_id(params[:serverID])

        if not s.nil?
          begin
            res = RestClient::Request.execute(:method => :get,
              :url => "#{s.serverURL}/postserver/#{params[:userID]}/#{params[:postID]}",
              :timeout => 15)

          rescue #=> e
            status, headers, body = error_response(400, 'Original post might have been deleted or is corrupted')
            return [status, headers, body]
          end

          if not res.nil?
            p1 = res.to_s
          end

        else
          status, headers, body = error_response(400, 'Communication error')
          return [status, headers, body]
        end
      end


      if p1.nil?
        status, headers, body = error_response(400, 'Original post might have been deleted or is corrupted')
        return [status, headers, body]

      else
      servers = []
      @@semaphore_server.synchronize {
        servers = ServerList.all(:userID => @user.userID)
      }

        servers.each do |s|

          threads << Thread.new do

            sID = get_server_id(s.serverID)

            if not sID.nil?

              if sID.eql?(@@SERVER_ID)
                if not parse_post_to_relate(@@SERVER_ID, @@SERVER_ID, @user.username, params[:postID], p1, is_mine).nil?
                  p1_body, p1_date, p1_tags, p1_affinity, p1_likes, p1_dislikes = parse_post_to_relate(@@SERVER_ID, @@SERVER_ID, @user.username, params[:postID], p1, is_mine)
                  semaphore.synchronize {
                    mylist.append(RelatedPost.new(params[:postID], params[:userID], params[:serverID], p1_body, p1_date, p1_affinity.to_i, p1_likes, p1_dislikes))
                    mylist = research_by_affinity(mylist, @@SERVER_ID, @@SERVER_ID, @user.username, p1_tags, p1_date, @@FRESHNESS, @@RELATEDNESS)
                  }
                end

              else
                begin
                  res = RestClient::Request.execute(:method => :get,
                    :url => "#{s.serverURL}/searchserver/#{params[:limit]}/affinity/#{params[:serverID]}/#{params[:userID]}/#{params[:postID]}/#{@@FRESHNESS}/#{@@RELATEDNESS}",
                    :timeout => 15)

                rescue #=> e
                end

                if not res.nil?
                  res = remove_others_likeness_references(res.to_s, @@SERVER_ID, @user.username)
                  if not res.nil?
                    semaphore.synchronize {
                      mylist = add_related_post_from_others(mylist, s.serverID, res)
                    }
                  end
                end
              end
            end
          end

          threads.each { |t| t.join}
        end

        if not mylist.length == 0
          mylist = mylist.sort_by_affinity()
          posts = mylist.getArray[0...(filter_search(mylist.getArray, params[:limit]))]
          status, headers, body = xml_response("#{create_body(posts)}")
          return [status, headers, body]

        else
          status, headers, body = error_response(400, 'No posts found')
          return [status, headers, body]
        end
      end

    else
      status, headers, body = error_response(405, 'You should authenticate first')
      return [status, headers, body]
    end
  end


  get '/post/:serverID/:userID/:postID' do

    if not @user.nil?

      post = ""

      if params[:serverID].eql?(@@SERVER_ID)
        
        u = User.find(params[:userID])

        if not u.nil?
          p = Post.find(params[:postID])

          if not p.nil?
	    if p.user.username.eql?(params[:userID])
              post = add_likeness_reference(@@SERVER_ID, @@SERVER_ID, @user.username, params[:postID], p.body).at(1)
	    else
              status, headers, body = error_response(400, 'Author/post mismatch')
              return [status, headers, body]
            end
          else
            status, headers, body = error_response(400, 'Original post might have been deleted or is corrupted')
            return [status, headers, body]
          end

        else
          status, headers, body = error_response(400, 'Username does not match any existing user')
          return [status, headers, body]
        end

      else
        s = Server.find_by_id(params[:serverID])

        if not s.nil?

          begin
            res = RestClient::Request.execute(:method => :get,
              :url => "#{s.serverURL}/postserver/#{params[:userID]}/#{params[:postID]}",
              :timeout => 15)

          rescue #=> e
            status, headers, body = error_response(400, 'Communication error')
            return [status, headers, body]
          end

          if not res.nil?
            res = remove_others_likeness_references_from_post(res.to_s, @@SERVER_ID, @user.username)
            if not res.nil?
              post = res.to_s
            else
              status, headers, body = error_response(400, 'Original post might have been deleted or is corrupted')
              return [status, headers, body]
            end

          else
            status, headers, body = error_response(400, 'Original post might have been deleted or is corrupted')
            return [status, headers, body]
          end

        else
          status, headers, body = error_response(400, 'Invalid input')
          return [status, headers, body]
        end
      end

      status, headers, body = xml_response("#{post}")
      return [status, headers, body]

    else
      status, headers, body = error_response(401, 'You should authenticate first')
      return [status, headers, body]
    end
  end


  #-----------------------------------------------------------------------------
  #--------------------------------- SOCIALITE ---------------------------------
  #-----------------------------------------------------------------------------
  post '/setlike' do

    if not @user.nil?

      ## val è una stringa: '-1', '0', '+1'
      sID, uID, pID, val = params[:serverID], params[:userID], params[:postID], params[:value]

      val = val.strip
      if set_preference(sID, uID, pID, val, "/#{@@SERVER_ID}/#{@user.username}")

        if not sID.eql?(@@SERVER_ID)
          s = Server.find_by_id(sID)

          if not s.nil?
            begin
              if val.strip == "1"
                val = '+1'
              end
              RestClient.post "#{s.serverURL}/propagatelike",
                :serverID1 => "#{@@SERVER_ID}", :userID1 => "#{@user.username}",
                :value => "#{val}", :serverID2 => "#{sID}", :userID2 => "#{uID}",
                :postID2 => "#{pID}"

            rescue #=> e
              pref = Preference.find(sID, uID, pID, "/#{@@SERVER_ID}/#{@user.username}")
              if not pref.nil?
                pref.destroy
              end
              status, headers, body = error_response(400, 'Communication error')
              return [status, headers, body]
            end

          else
            status, headers, body = error_response(400, 'Invalid input')
            return [status, headers, body]
          end
        end

        status = 200 # OK
        headers = ""
        body = ""
        return [status, headers, body]

      else
        status, headers, body = error_response(400, 'You already rated this post')
        return [status, headers, body]
      end

    else
      status, headers, body = error_response(401, 'You should authenticate first')
      return [status, headers, body]
    end
  end


  get '/followers' do

    if not @user.nil?
      status, headers, body = xml_response(create_following_list(@@SERVER_ID, @user.username))
      return [status, headers, body]

    else
      status, headers, body = error_response(401, 'You should authenticate first')
      return [status, headers, body]
    end
  end


  post '/setfollow' do

    if not @user.nil?

      sID, uID, val = params[:serverID], params[:userID], params[:value].to_i
      check = false

      if val==1
        # Controlla che il followed aggiunto esista effettivamente
        if @@SERVER_ID.eql?(sID)
          if User.find(uID).nil?
            status, headers, body = error_response(400, 'Username does not match any existing user')
            return [status, headers, body]
          end

        else
          s = Server.find_by_id(sID)

          if not s.nil?
            begin
              res = RestClient::Request.execute(:method => :get,
                :url => "#{s.serverURL}/searchserver/1/author/#{sID}/#{uID}",
                :timeout => 15)

            rescue #=> e
              status, headers, body = error_response(400, 'Communication error')
              return [status, headers, body]
            end

            begin
              doc = Document.new res.to_s
              # Controlla se la riposta non contiene post, cioè contiene solo
              # l'elemento radice <archive></archive>
              if doc.elements["archive/post"].nil?
                status, headers, body = error_response(400, 'Username does not match any existing user')
                return [status, headers, body]
              end

            rescue
              status, headers, body = error_response(400, 'Username does not match any existing user')
              return [status, headers, body]
            end

          else
            status, headers, body = error_response(400, 'Invalid input')
            return [status, headers, body]
          end
        end
      end

      # Controlla che non sia già stato creato un legame di following
      if set_follow(@@SERVER_ID, @user.username, val, sID, uID)
        status = 200 # OK
        headers = ""
        body = ""
        return [status, headers, body]
      
      else
        status, headers, body = error_response(400, 'You are already following this user')
        return [status, headers, body]
      end

    else
      status, headers, body = error_response(401, 'You should authenticate first')
      return [status, headers, body]
    end
  end

  #-----------------------------------------------------------------------------
  #---------------------------------- TESAURO ----------------------------------
  #-----------------------------------------------------------------------------
  post '/addterm' do

    if not @user.nil?
      
      repo = load_thesaurus(@user.username)
      tags = load_admitted_tags(repo)
      parent, child = params[:parentterm], params[:term]

      # Controlla l'ammissibilita' dei termini
      if add_term(parent, child, repo, tags, @user.username)
        status = 201 # Created
        headers = ""
        body = ""
        return [status, headers, body]
        
      else
        status, headers, body = error_response(400, 'Invalid input')
        return [status, headers, body]
      end

    else
      status, headers, body = error_response(401, 'You should authenticate first')
      return [status, headers, body]
    end
  end


  get '/addterm' do

    status, headers, body = error_response(405, 'Method not implemented yet') # Method Not Allowed
    return [status, headers, body]
  end


  get '/thesaurus' do

    if not @user.nil?
      semaphore = Mutex.new
      thesaurus = ""
      semaphore.synchronize {
        f = File.open(load_his_thesaurus(@user.username), "r+:UTF-8")
        begin
        doc = Document.new f
        thesaurus = doc.to_s
        rescue
          f.close
          thesaurus = ""
        end
      }
      status, headers, body = xml_response(thesaurus)
      return [status, headers, body]

    else
      status, headers, body = error_response(401, 'You should authenticate first')
      return [status, headers, body]
    end
  end


  #-----------------------------------------------------------------------------
  #------------------------------ SERVER FEDERATI ------------------------------
  #-----------------------------------------------------------------------------

  get '/servers' do
    
    if not @user.nil?
      status, headers, body = xml_response(create_user_servers_list(@user.userID, @@semaphore_server))
      return [status, headers, body]

    else
      status, headers, body = error_response(401, 'You should authenticate first')
      return [status, headers, body]
    end
  end


  post '/servers' do

    if not @user.nil?

      if load_new_user_servers_list(@user.userID, params[:servers], @@semaphore_server)
        status = 201 # Created
        headers = ""
        body = ""
        return [status, headers, body]

      else
        # Se un server aggiunto non esiste
        status, headers, body = error_response(400, 'Invalid input')
        return [status, headers, body]
      end

    else
      status, headers, body = error_response(401, 'You should authenticate first')
      return [status, headers, body]
    end
  end


  #*****************************************************************************
  #*********************************** UPIM ************************************
  #*****************************************************************************
  #-----------------------------------------------------------------------------
  #----------------------------------- REPLY -----------------------------------
  #-----------------------------------------------------------------------------
  post '/hasreply' do
    
    sID1, uID1, pID, uID2, sID2 = params[:serverID], params[:userID], params[:postID],
      params[:serverID2Up], params[:userID2Up]
    
    u = User.find(uID1)
    
    if not u.nil?
      p = Post.find(pID)
      if not p.nil?
        if update_replied_metadata(sID2, uID2, pID, p.body)
          return 201 # Created
        else
          status, headers, body = error_response(400, 'Communication error')
          return [status, headers, body]
        end
        
      else
        status, headers, body = error_response(400, 'Original post might have been deleted or is corrupted')
        return [status, headers, body]
      end
    
    else
      status, headers, body = error_response(400, 'Username does not match any existing user')
      return [status, headers, body]
    end
  end


  #-----------------------------------------------------------------------------
  #----------------------------------- SEARCH ----------------------------------
  #-----------------------------------------------------------------------------
  get '/searchserver/:limit/author/:serverID/:userID' do
 
    mylist = RelatedPostList.new
    u = User.find(params[:userID])

    if not u.nil?
      # Se l'autore non ha ancora creato post, ritorna come body -> <archive></archive>
      mylist = research_by_author(mylist, "aServer", @@SERVER_ID, u, "aUser")
      if not mylist.length == 0
        mylist = mylist.sort()
        posts = mylist.getArray[0...(filter_search(mylist.getArray, params[:limit]))]
        status, headers, body = xml_response("#{create_body(posts)}")
        return [status, headers, body]

      else
        status, headers, body = error_response(400, 'No posts found')
        return [status, headers, body]
      end

    else
      status, headers, body = error_response(400, 'Username does not match any existing user')
      return [status, headers, body]
    end
  end


  get '/searchserver/:limit/recent' do

    mylist = RelatedPostList.new
    mylist = research_related_post(mylist, "aServer", @@SERVER_ID, "aUser", "", params[:limit])

    if not mylist.length == 0
      posts = mylist.getArray
      status, headers, body = xml_response("#{create_body(posts)}")
      return [status, headers, body]

    else
      status, headers, body = error_response(400, 'No posts found')
      return [status, headers, body]
    end
  end


  get '/searchserver/:limit/recent/:term' do

    mylist = RelatedPostList.new
    mylist = research_related_post(mylist, "aServer", @@SERVER_ID, "aUser", params[:term], "all")

    if not mylist.length == 0
      mylist = mylist.sort()
      posts = mylist.getArray[0...(filter_search(mylist.getArray, params[:limit]))]
      status, headers, body = xml_response("#{create_body(posts)}")
      return [status, headers, body]

    else
      status, headers, body = error_response(400, 'No posts found')
      return [status, headers, body]
    end
  end


  get '/searchserver/:limit/related/:term' do

    mylist = RelatedPostList.new
    repo = load_thesaurus("aUser")
    tags = load_admitted_tags(repo)
    related = get_related_terms(repo, params[:term])

    related.each do |term|
      mylist = research_related_post(mylist, "aServer", @@SERVER_ID, "aUser", params[:term], params[:limit])
    end

    if not mylist.length == 0
      mylist = mylist.sort()
      posts = mylist.getArray[0...(filter_search(mylist.getArray, params[:limit]))]
      status, headers, body = xml_response("#{create_body(posts)}")
      return [status, headers, body]

    else
      status, headers, body = error_response(400, 'No posts found')
      return [status, headers, body]
    end
  end


  get '/searchserver/:limit/fulltext/:string' do

    if params[:string].length == 0
      status, headers, body = error_response(400, 'Invalid input')
      return [status, headers, body]
    end

    mylist = RelatedPostList.new
    mylist = research_fulltext(mylist, "aServer", @@SERVER_ID, "aUser", params[:string])
    
    if not mylist.length == 0
      mylist = mylist.sort()
      posts = mylist.getArray[0...(filter_search(mylist.getArray, params[:limit]))]
      status, headers, body = xml_response("#{create_body(posts)}")
      return [status, headers, body]

    else
      status, headers, body = error_response(400, 'No posts found')
      return [status, headers, body]
    end
  end


  get '/searchserver/:limit/affinity/:serverID/:userID/:postID/:k/:j' do
 
    mylist = RelatedPostList.new
    is_mine = false

    # Acquisisce post incriminato
    p1 = nil
    if params[:serverID].eql?(@@SERVER_ID)
      p1 = Post.find(params[:postID])
      is_mine = true

    else
      s = Server.find_by_id(params[:serverID])

      if not s.nil?
        begin
          res = RestClient::Request.execute(:method => :get,
            :url => "#{s.serverURL}/postserver/#{params[:userID]}/#{params[:postID]}",
            :timeout => 15)
      
        rescue #=> e
          status, headers, body = error_response(400, 'Original post might have been deleted or is corrupted')
          return [status, headers, body]
        end
      
        if not res.nil?
          p1 = res.to_s
        end

      else
        status, headers, body = error_response(400, 'Invalid input')
        return [status, headers, body]
      end
    end

    if p1.nil?
      status, headers, body = error_response(400, 'Original post might have been deleted or is corrupted')
      return [status, headers, body]

    else
      if not parse_post_to_relate("aServer", @@SERVER_ID, "aUser", params[:postID], p1, is_mine).nil?
        p1_body, p1_date, p1_tags, p1_affinity, p1_likes, p1_dislikes = parse_post_to_relate("aServer", @@SERVER_ID, "aUser", params[:postID], p1, is_mine)
        mylist = research_by_affinity(mylist, "aServer", @@SERVER_ID, "aUser", p1_tags, p1_date, params[:k].to_i, params[:j].to_i)

        if not mylist.length == 0
          mylist = mylist.sort_by_affinity()
          posts = mylist.getArray[0...(filter_search(mylist.getArray, params[:limit]))]
          status, headers, body = xml_response("#{create_body(posts)}")
          return [status, headers, body]

        else
          status, headers, body = error_response(400, 'No posts found')
          return [status, headers, body]
        end

      else
        status, headers, body = error_response(400, 'Communication error')
        return [status, headers, body]
      end
    end
  end


  get '/postserver/:userID/:postID' do

    u = User.find(params[:userID])
     post = ""

    if not u.nil?
      p = Post.find(params[:postID])

      if not p.nil?
	if p.user.username.eql?(params[:userID])
          post = add_likeness_reference("aServer", @@SERVER_ID, params[:userID], params[:postID], p.body)[0]
          status, headers, body = xml_response("#{post}")
          return [status, headers, body]
	else
          status, headers, body = error_response(400, 'Author/post mismatch')
          return [status, headers, body]
        end

      else
        status, headers, body = error_response(400, 'Original post might have been deleted or is corrupted')
        return [status, headers, body]
      end

    else
      status, headers, body = error_response(400, 'Username does not match any existing user')
      return [status, headers, body]
    end
  end


  #-----------------------------------------------------------------------------
  #--------------------------------- SOCIALITE ---------------------------------
  #-----------------------------------------------------------------------------
  post '/propagatelike' do

    sID1, uID1, val, sID2, uID2, pID = params[:serverID1], params[:userID1], params[:value],
      params[:serverID2], params[:userID2], params[:postID2]

    val = val.strip
    if set_preference(sID1, uID1, pID, val, "/#{sID2}/#{uID2}")
      return 200 # OK

    else
      status, headers, body = error_response(400, 'You already rated this post')
      return [status, headers, body]
    end
  end


  #-----------------------------------------------------------------------------
  #----------------------------------- FILTRI ----------------------------------
  #-----------------------------------------------------------------------------
  # Filtro per gestire la sessione del Client
  before do
    username = request.cookies["ltwlogin"]
    @user = User.find(username)
  end

  # Filtri sui parametri di ricerca ammessi
  before '/search/:limit/:type' do
    if not check_limit(params[:limit]) or not check_type(params[:type])
      status, headers, body = error_response(501, 'Errore nei parametri di ricerca')
      return [status, headers, body]
    end
  end

  before '/searchserver/:limit/:type/*' do
    if not check_limit(params[:limit]) and not check_type_upim(params[:type])
      status, headers, body = error_response(501, 'Errore nei parametri di ricerca')
      return [status, headers, body]
    end
  end

  #-----------------------------------------------------------------------------
  #----------------------------- GESTIONE ERRORI -------------------------------
  #-----------------------------------------------------------------------------
  delete "/*" do
    status, headers, body = error_response(405, 'Non hai il permesso di eseguire questa operazione')
    return [status, headers, body]
  end

  not_found do
    @error_message = "404 - NotFound"
    erb :error
  end

  error do
    'Si è verificato un errore: ' + env['sinatra.error'].name
  end

  get '/search/:limit/since-date/:date' do
    status, headers, body = error_response(501, 'Errore nei parametri di ricerca')
    return [status, headers, body]
  end

end
