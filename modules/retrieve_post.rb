#!/usr/bin/ruby

$KCODE = 'u' if RUBY_VERSION < '1.9'

require File.join(File.dirname(__FILE__), 'model')
require File.join(File.dirname(__FILE__), 'resource_manager')

# ******************************************************************************
# **                    Gestisce le ricerche di vecchi post                   **
# ******************************************************************************
module RetrievePost
  include REXML


  # @list insieme di post risposta alla query
  # @source_serverID server che fa la richiesta
  # @serverID server di origine dei post
  # @author autore dei post cercati
  # @username utente che fa la richiesta
  def research_by_author(list, source_serverID, serverID, author, username)

    posts=[]
    posts = Post.all(:user => author)

    posts.each do |p|
      done, content, likes, dislikes = add_likeness_reference(source_serverID, serverID, username, p.postID, p.body)
      if done
        list.append(RelatedPost.new(p.postID, author.username, serverID, content, DateTime.parse(p.created_at.to_s), '0', likes, dislikes))
      end
    end

    return list
  end


  # Metodo usato per recent e related
  # @list insieme di post risposta alla query
  # @source_serverID server che fa la richiesta
  # @serverID server di origine dei post
  # @username utente che fa la richiesta
  # @term termine da cercare
  # @lim numero di post richiesti
  def research_related_post(list, source_serverID, serverID, username, term, lim)

    if term.length==0
      if lim.eql?("all")
        posts = Post.all(:order => [ :created_at.desc ])

      else
        posts = Post.all(:order => [ :created_at.desc ], :limit => lim.to_i)
      end

      posts.each do |p|
        u2 = p.user
        done, content, likes, dislikes= add_likeness_reference(source_serverID, serverID, username, p.postID, p.body)
        if done
          list.append(RelatedPost.new(p.postID, u2.username, serverID, content, DateTime.parse(p.created_at.to_s), '0', likes, dislikes))
        end
      end

    else
      #Coppie (name, postID) | term=name
      references = Hashtag.all(:name.like => "%#{term}")

      references.each do |ref|
        p = Post.get(ref.postID)
        if not p.nil?
          u = p.user
          done, content, likes, dislikes= add_likeness_reference(source_serverID, serverID, username, p.postID, p.body)
          if done
            list.append(RelatedPost.new(p.postID, u.username, serverID, content, DateTime.parse(p.created_at.to_s), '0', likes, dislikes))
          end
        end
      end
    end

    return list
  end


  # @list insieme di post risposta alla query
  # @source_serverID server che fa la richiesta
  # @serverID server di origine dei post
  # @username utente che fa la richiesta
  # @term termine da cercare
  def research_fulltext(list, source_serverID, serverID, username, term)

    myposts = Post.all

    myposts.each do |p|

      begin
        doc = Document.new p.body
        # Ottiene il testo del post, senza i tag
        message = ""
        doc.each_element_with_text {|e| message += e.text}

        if (message.include?(term))
          done, content, likes, dislikes = add_likeness_reference(source_serverID, serverID, username, p.postID, p.body)
          if done
            list.append(RelatedPost.new(p.postID, p.user.username, serverID, content, DateTime.parse(p.created_at.to_s), '0', likes, dislikes))
          end
        end

      rescue
        next
      end
    end

    return list
  end


  # @list insieme di post risposta alla query
  # @source_serverID server che fa la richiesta
  # @serverID server di origine dei post
  # @username utente che fa la richiesta
  # @p1_tags array hashtag contenuti nel primo post
  # @p1_date data di creazione del primo post
  # @fresh moltiplicatore per la distanza temporale dei due post
  # @relate moltiplicatore per la somiglianza dei due post
  def research_by_affinity(list, source_serverID, serverID, username, p1_tags, p1_date, fresh, relate)

    maybe_related_posts = Post.all()
    p2_tags=[]
  
    maybe_related_posts.each do |p2|

      tag_references = Hashtag.all(:postID => "#{p2.postID}")
      tag_references.each do |ref|
        p2_tags << ref.name
      end

      # Se uno dei due post non contiene hashtag
      if p1_tags.length==0 or p2_tags.length==0
        closeness = 0

      else
        closeness = calculate_affinity(p1_tags, p2_tags)
      end
    
      freshness = (p1_date - p2.created_at).abs

      others_opinion = Preference.all(:postID => p2.postID)
      boost = 0
      others_opinion.each do |op|
        boost += op.value
      end
      # Se il post non ha like/dislike, boost viene settato a 1
      if boost == 0
        boost = 1
      end

      affinity = (fresh * (- freshness.to_f) + relate * closeness) * boost.to_f

      done, content, likes, dislikes = add_likeness_reference(source_serverID, serverID, username, p2.postID, p2.body)
      if done
        list.append(RelatedPost.new(p2.postID, p2.user.username, serverID, content, DateTime.parse(p2.created_at.to_s), affinity.to_i, likes, dislikes))
      end
    end
    
    return list
  end


  #--------------------------------- UTILITIES ---------------------------------
  def filter_search(posts, limit)

    if (limit <=> 'all')==0
      max = posts.length

    else
      max = limit.to_i
      if posts.length == 0
        return 0

      else
        if (posts.length < max)
          max = posts.length
        end
      end
    end

    return max
  end


  def add_related_post_from_others(list, serverID, bodyContent)

    doc = Document.new bodyContent

    if not doc.root.class != Element

      doc.elements.each("archive/post") do |p|
      
        begin

          if (p.elements["affinity"].nil?)
            affinity = "0"
          else
            affinity = p.elements["affinity"].get_text.value
          end

          article = p.elements["article"]
          resource = article.attributes["about"]
          data = resource.split('/')
          postID = data.at(2)
          userID = data.at(1)
          content = article.to_s
          created_at = article.attributes["content"]
          countlike = article.elements["span[@property='tweb:countLike']"].attributes["content"]
          countdislike = article.elements["span[@property='tweb:countDislike']"].attributes["content"]

          list.append(RelatedPost.new(postID, userID, serverID, content, DateTime.parse(created_at.to_s), affinity.to_i, countlike, countdislike))

        rescue
          next
        end
      end
    end
    
    return list
  end


  def check_limit(limit)
    if((limit.to_s.match(/\A[+]?\d+?\Z/) == nil) or (limit.eql?("all")))
      return true
    else
      return false
    end
  end


  def check_type(type)
    admitted_types = %w('author' 'following' 'recent' 'related' 'fulltext' 'affinity')
    if admitted_types.include?(type)
      return true
    else
      return false
    end
  end


  def check_type_upim(type)
    admitted_types = %w('author' 'recent' 'related' 'fulltext' 'affinity')
    if admitted_types.include?(type)
      return true
    else
      return false
    end
  end


  #---------------------------------- PARSING ----------------------------------
  def parse_post_to_relate(source_serverID, serverID, username, postID, post1, is_mine)

    content = ""
    created_at = ""
    tags = []
    likes = 0
    dislikes = 0

    if is_mine
      #body = post1.body
      created_at = DateTime.parse(post1.created_at.to_s)
      htags = Hashtag.all(:postID => "#{post1.postID}")
      htags.each do |h|
        tags << htags.name
      end

      done, content, likes, dislikes = add_likeness_reference(source_serverID, serverID, username, postID, post1.body)

    else
      # Trova hashtag e data di creazione
      begin
        doc = Document.new post1
        article = doc.elements["article"]

	countlike = article.elements["span[@property='tweb:countLike']"].attributes["content"]
        countdislike = article.elements["span[@property='tweb:countDislike']"].attributes["content"]

        content = remove_others_likeness_references_from_post(post1, serverID, username)
        created_at = DateTime.parse(article.attributes["content"].to_s)
        tags = find_hashtags(body)

      rescue
        return nil
      end
    end

    return content, created_at, tags, 10000000, likes, dislikes
  end


  def find_hashtags(post)

    tags=[]

    begin
      doc = Document.new post
      doc.elements.each("article/span/span@['typeof']") do |h|
        tags << h.attributes["about"].to_s
      end
    
    rescue
      return []
    end

    return tags
  end

end
