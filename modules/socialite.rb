#!/usr/bin/ruby

$KCODE = 'u' if RUBY_VERSION < '1.9'

require File.join(File.dirname(__FILE__), 'model')


# ******************************************************************************
# **               Gestisce like e relazioni follower-followed                **
# ******************************************************************************
module Socialite

  # Restituisce gli ID degli utenti (<serverID>/<userID>) seguiti dal richiedente
  def get_followed(serverID, userID)

    followedIDs = []
    followeds = Friendship.all(:follower => "#{serverID}/#{userID}")

    followeds.each do |f|
      followedIDs << f.followed
    end
    return followedIDs
  end


  # sID1/uID1 => utente che fa follow
  # sID2/uID2 => followed
  def set_follow(sID1, uID1, val, sID2, uID2)

    f = Friendship.find("#{sID2}/#{uID2}", "#{sID1}/#{uID1}")

    if val == 1
      if f.nil?
        Friendship.create(:followed => "#{sID2}/#{uID2}", :follower => "#{sID1}/#{uID1}")
        return true
      end
    end

    if val==0
      if not f.nil?
        f.destroy
        return true
      end
    end

    return false
  end


  # Crea la risposta contentente tutti gli utenti
  # seguiti dall'utente che fa la richiesta.
  def create_following_list(serverID, userID)

    root = Element.new "followers"
    list = Friendship.all(:follower => "#{serverID}/#{userID}")
    list.each do |l|
      root.add_element 'follower', {"id" => l.followed}
    end

    return root.to_s
  end


  # Aggiorna i riferimenti like/dislike
  # Se l'utente ha gia' espresso una preferenza
  # su quel post, ritorna errore
  def set_preference(sID, uID, pID, val, username)

    p = Preference.find(sID, uID, pID, username)

    if p.nil?
      if val=='+1' or val=='1'
        Preference.create(:serverID => sID, :userID => uID, :postID => pID, :username => username, :value => 1)
        return true
      end

      if val=='-1'
        Preference.create(:serverID => sID, :userID => uID, :postID => pID, :username => username, :value => -1)
        return true
      end

      if val=='0'
        return true
      end

    else
      if val == '0'
        p.destroy
        return true
      end
    end

    return false
  end

end
