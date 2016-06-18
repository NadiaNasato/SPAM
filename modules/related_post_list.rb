class RelatedPostList

  def initialize
    @posts = []
  end

  def append(aPost)
    @posts.push(aPost)
    return self
  end

  def sort()
    @posts.sort! { |a,b| b.created_at <=> a.created_at }
    return self
  end

  def sort_by_affinity()
    @posts.sort! { |a,b| b.affinity <=> a.affinity }
    return self
  end

  def length
    return @posts.length
  end

  def [](key)
    if key.kind_of?(Integer)
      return @posts[key]
    else
      for i in 0...@posts.length
        return @posts[i] if key == @posts[i].postID
      end
    end
    return nil
  end

  def getArray
    return @posts
  end
end

