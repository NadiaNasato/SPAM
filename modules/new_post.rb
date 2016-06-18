#!/usr/bin/ruby

$KCODE = 'u' if RUBY_VERSION < '1.9'

require File.join(File.dirname(__FILE__), 'model')


# ******************************************************************************
# **                    Gestisce la creazione di nuovi post                   **
# ******************************************************************************

module NewPost

  #------------------------------ CREAZIONE POST -------------------------------
  # Crea un nuovo post
  # @serverID server a cui e' collegato l'utente
  # @user utente che fa la richiesta
  # @post testo del messaggio
  # @tags insieme di tag del tesauro dell'utente
  # @return true se il post e' stato creato correttamente,
  #         false altrimenti
  def spam(serverID, user, post, tags)

    if post.length > 0
      p = Post.create(:body => post, :created_at => DateTime.now.strftime("%Y-%m-%dT%H:%M:%SZ"), :user => user)

      # Il post con i metadati viene aggiornato all'interno del metodo
      if add_metadata(serverID, user.username, p, tags)
        return true

        # Se si verifica un errore di parsing, elimino il post scorretto
      else
        p.destroy
        return false
      end
    end

    return false
  end


  # Crea un nuovo post a partire dal contenuto di un altro post
  # @serverID server a cui e' collegato l'utente
  # @user utente che fa la richiesta
  # @source_server server in cui risiede il post originale
  # @user_respammed autore del post originale
  # @post_respammedID id del post originale
  # @post_respammed contenuto del post originale
  # @tags insieme di tag del tesauro dell'utente
  # @return true se il post e' stato creato correttamente,
  #         false altrimenti
  def respam(serverID, user, source_server, user_respammed, post_respammedID, post_respammed, tags)

    p = Post.create(:body => post_respammed, :created_at => DateTime.now.strftime("%Y-%m-%dT%H:%M:%SZ"), :user => user)

    if update_respam_metadata(serverID, user, source_server, user_respammed, post_respammedID, p, tags)
      return true

    else
      p.destroy
      return false
    end
  end


  # Crea un nuovo post risposta di un altro post
  # @serverID server a cui e' collegato l'utente
  # @user utente che fa la richiesta
  # @source_server server in cui risiede il post originale
  # @user_answered autore del post originale
  # @post contenuto del post originale
  # @post_answeredID id del post originale
  # @tags insieme di tag del tesauro dell'utente
  # @return il post se i parametri sono corretti,
  #         nil altrimenti
  def reply(serverID, user, source_server, user_answered, post, post_answeredID, tags)

    if post.length > 0
      p1 = Post.create(:body => post, :created_at => DateTime.now.strftime("%Y-%m-%dT%H:%M:%SZ"), :user => user)

      if update_reply_metadata(serverID, user.username, p1, tags, source_server, user_answered, post_answeredID)

        # Se e' un post interno posso gia' aggiornare il post originale
        if serverID.eql?(source_server)
          # Ho gia' fatto la ricerca e so che il post esiste
          p2 = Post.find(post_answeredID)
          if not update_replied_metadata(serverID, user.username, p1.postID, p2)
            p1.destroy
            htags = Hashtag.all(:postID => p1.postID)
            htags.each do |t|
              t.destroy
            end
            return nil
          end
        end

        return p1

      else
        post.destroy
        return nil
      end
    end

    return nil
  end


  #----------------------------- GESTIONE METADATI -----------------------------
  def add_metadata(serverID, username, post, tags)

    begin
      doc = Document.new post.body
      art = doc.elements["article"]
      art.add_attributes({"prefix" => "sioc: http://rdfs.org/sioc/ns# ctag: http://commontag.org/ns# skos: http://www.w3.org/2004/02/skos/core# dcterms: http://purl.org/dc/terms/ tweb: http://vitali.web.cs.unibo.it/vocabulary/",
          "about" => "/#{serverID}/#{username}/#{post.postID}",
          "typeof" => "sioc:Post",
          "rel" => "sioc:has_creator",
          "resource" => "/#{serverID}/#{username}",
          "property" => "dcterms:created",
          "content" => "#{post.created_at}"})

    rescue
      return false
    end
    
    doc = add_hashtags(doc.to_s, post.postID, tags)

    if not doc.nil?
      post.update(:body => doc.to_s)
      return true

    else
      return false
    end
  end


  def update_respam_metadata(serverID, user, source_serverID, user_respammed, post_respammedID, respam, tags)
 
    begin
      doc = Document.new respam.body
      art = doc.elements["article"]
      # Aggiorna gli attributi di article
      art.attributes["about"] = "/#{serverID}/#{user.username}/#{respam.postID}"
      art.attributes["resource"] = "/#{serverID}/#{user.username}"
      art.attributes["content"] = "#{respam.created_at}"

      # Rimuove i riferimenti propri del post originale
      doc.elements.delete_all "article/span[@rel='sioc:has_reply']"
      doc.elements.delete_all "article/span[@rel='tweb:respamOf']"
      doc.elements.delete_all "article/span[@rel='sioc:reply_of']"

      doc.elements.delete_all "article/span[@rev='tweb:like']"
      doc.elements.delete_all "article/span[@rev='tweb:dislike']"
      
      doc.elements.delete_all "article/span[@property='tweb:countLike']"
      doc.elements.delete_all "article/span[@property='tweb:countDislike']"

      # Se un hashtag non fa parte del tesauro dell'utente, lo trasforma
      # in un tag semplice
      doc.elements.each("article/span/span[@typeof='skos:Concept']") do |h|
        if not tags.include?(h.get_text.value)
          h.attributes["typeof"] = "ctag:Tag"
          h.attributes["property"] = "ctag:label"
          h.attributes.delete "resource"
          h.attributes.delete "about"
          h.attributes.delete "rel"
        end
      end

      # Aggiunge il riferimento al post originale
      art.add_element 'span', {'rel' => "tweb:respamOf", 'resource' => "/#{source_serverID}/#{user_respammed}/#{post_respammedID}"}
    
    rescue
      return false
    end

    doc = add_hashtags(doc.to_s, respam.postID, tags)

    if not doc.nil?
      respam.update(:body => doc.to_s)
      return true

    else
      return false
    end    
  end


  def update_reply_metadata(serverID, username, post, tags, source_server, user_answered, post_answeredID)

    begin
      doc = Document.new post.body
      art = doc.elements["article"]
      art.add_element 'span', {'rel' => "sioc:reply_of", 'resource' => "/#{source_server}/#{user_answered}/#{post_answeredID}"}

    rescue
      return false
    end

    post.update(:body => doc.to_s)

    if add_metadata(serverID, username, post, tags)
      return true

    else
      return false
    end
  end


  def update_replied_metadata(server, username, answerID, post)

    begin
      doc = Document.new post.body
      art = doc.elements["article"]
      art.add_element 'span', {'rel' => "sioc:has_reply", 'resource' => "/#{server}/#{username}/#{answerID}"}
      post.update(:body => doc.to_s)

    rescue
      return false
    end

    return true
  end


  #----------------------------- GESTIONE HASHTAG ------------------------------
  def add_hashtags(post, postID, tags)

    begin
      doc = Document.new post

      doc.elements.each("article/span/span[@typeof='skos:Concept']") do |h|
        if tags.include?(h.get_text.value)
          Hashtag.create(:name => h.attributes["about"].to_s, :postID => postID)
        end
      end

    rescue
      return nil
    end

    return doc.to_s
  end
  
end
