#!/usr/bin/ruby

$KCODE = 'u' if RUBY_VERSION < '1.9'


# ******************************************************************************
# **             Crea le risposte per i client e gli altri server             **
# ******************************************************************************
module ServerReply
  include REXML


  # Wrapper per i messaggi di errore
  def error_response(status_code, message)
    status = status_code
    headers = Hash.new
    headers['Content-Type'] = 'text/plain'
    body = message
    return [status, headers, body]
  end


  # Wrapper
  def xml_response(bodyContent)
    status = 200 # OK
    headers = Hash.new
    headers['Content-Type'] = 'text/xml'
    body = bodyContent
    return [status, headers, body]
  end


  # Compone il body da restituire alle richieste 'search'
  def create_body(posts)

    archive = Element.new "archive"

    if not posts.nil?
      for i in 0...posts.length
        post = archive.add_element "post"
        content = post.add_element "content"
        content.text = "text/html; charset=UTF8"
        affinity = post.add_element "affinity"
        affinity.text = posts[i].affinity
        article = Document.new posts[i].body
        body = post.add_element article
      end
    end
    
    return archive.to_s
  end


  # Costruisce il post con tutti i tag richiesti.
  # Usato sia per PAM che per UPIM.
  # @source_serverID server che fa la richiesta
  # @serverID server di origine dei post
  # @username utente che fa la richiesta
  # @postID id del post
  # @post contenuto del messaggio
  def add_likeness_reference(source_serverID, serverID, username, postID, post)

    likes = 0
    dislikes = 0
    others_opinion = Preference.all(:postID => postID)
    others_opinion.each do |op|
      if op.value == 1
        likes += 1
      end
      if op.value == -1
        dislikes += 1
      end
    end

    begin
      doc = Document.new post
      art = doc.elements["article"]

      # Se la richiesta proviene dal nostro server aggiungiamo
      # solo il riferimento a like/dislike fatto dal richiedente
      if source_serverID == serverID
        # Non serve conoscere l'autore del post perché è sufficiente la coppia
        # (serverID e postID), visto che gli ID dei post sono unici nel nostro server
        is_marked = Preference.find_my_preference(serverID, postID, "/#{serverID}/#{username}")

        if not is_marked.nil?
          if is_marked.value == 1
            art.add_element 'span', {"rev" => "tweb:like", "resource" => "#{is_marked.username}"}

          else
            art.add_element 'span', {"rev" => "tweb:dislike", "resource" => "#{is_marked.username}"}
          end
        end

      else
        others_opinion.each do |op|
          if op.value == 1
            art.add_element 'span', {"rev" => "tweb:like", "resource" => "#{op.username}"}

          else
            art.add_element 'span', {"rev" => "tweb:dislike", "resource" => "#{op.username}"}
          end
        end
      end

      art.add_element 'span', {"property" => "tweb:countLike", "content" => "#{likes}"}
      art.add_element 'span', {"property" => "tweb:countDislike", "content" => "#{dislikes}"}

    rescue
      return false, nil, nil, nil
    end

    return true, doc.to_s, likes, dislikes
  end


  # Per i post provenienti dagli altri server, toglie i riferimenti inutili
  # @posts nel formato <archive></<archive>
  # @server server dell'utente che fa la richiesta
  # @user utente che fa la richiesta
  def remove_others_likeness_references(posts, server, user)

    begin
      doc = Document.new posts

      doc.elements.each("archive/post/article") do |art|
        art.elements.delete_all "span[@rev]"
        resource = art.attributes["about"].to_s
        data = resource.split('/')
        serverID = data.at(1)
        userID = data.at(2)
        postID = data.at(3)

        pref = Preference.find(serverID, userID, postID, "/#{server}/#{user}")
        if not pref.nil?
          if pref.value == 1
            art.add_element 'span', {"rev" => "tweb:like", "resource" => "#{pref.username}"}

          else
            art.add_element 'span', {"rev" => "tweb:dislike", "resource" => "#{pref.username}"}
          end
        end
      end  

      return doc.to_s
    
    rescue REXML::ParseException
      return nil
    end
  end


  def remove_others_likeness_references_from_post(post, server, user)

    art= ""

    begin
      art = Document.new post

      art.elements.delete_all "article/span[@rev]"
      resource = art.attributes["about"].to_s
      data = resource.split('/')
      serverID = data.at(1)
      userID = data.at(2)
      postID = data.at(3)

      pref = Preference.find(serverID, userID, postID, "/#{server}/#{user}")
      if not pref.nil?
        if pref.value == 1
          art.add_element 'span', {"rev" => "tweb:like", "resource" => "#{pref.username}"}

        else
          art.add_element 'span', {"rev" => "tweb:dislike", "resource" => "#{pref.username}"}
        end
      end

    rescue
      return nil
    end
    return art.to_s
  end

end
