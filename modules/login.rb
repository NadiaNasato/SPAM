#!/usr/bin/ruby

$KCODE = 'u' if RUBY_VERSION < '1.9'

require File.join(File.dirname(__FILE__), 'resource_manager')
require File.join(File.dirname(__FILE__), 'model')

# ******************************************************************************
# **                         Gestisce l'autenticazione                        **
# ******************************************************************************
module Login

  # Ritorna il riferimento all'utente autenticato.
  # Se si tratta di un nuovo utente, prima lo crea e
  # carica la lista di server federati di default.
  # @return user
  #         nil se il parametro non e' corretto
  def login(username, semaphore)

    if username.length > 0

      if authenticate(username)
        user = User.find(username)
        return user

      else
        User.create(:username => username)
        user = User.find(username)
        load_his_server_list(user, semaphore)
        return user
      end

    else
      return nil
    end
  end


  # Controlla se esiste gia' un utente con il nome
  # passato come parametro
  def authenticate(user)

    u = User.first(:username => user)

    if u.nil?
      return false
    end
    
    return true
  end


  # Controlla la legittimita' della richiesta
  # di logout
  def logout(user)

    if user.nil?
      return false
    end

    return true   
  end
  
end
