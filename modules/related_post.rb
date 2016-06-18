# To change this template, choose Tools | Templates
# and open the template in the editor.

class RelatedPost
  @postID
  @author
  @serverID
  @body
  @created_at
  @affinity
  @countIlike
  @countIdislike

  def initialize(pID, au, sID, content, date, aff, like, dislike)
    @postID = pID
    @author = au
    @serverID = sID
    @body = content
    @created_at = date
    @affinity = aff
    @countIlike = like
    @countIdislike = dislike
  end

  def postID
    @postID
  end

  def author
    @author
  end

  def serverID
    @serverID
  end

  def body
    @body
  end

  def created_at
    @created_at
  end

  def affinity
    @affinity
  end

  def countlike
    @countIlike
  end

  def countdislike
    @countIdislike
  end

end
