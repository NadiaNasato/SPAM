#!/usr/bin/ruby

$KCODE = 'u' if RUBY_VERSION < '1.9'

require File.join(File.dirname(__FILE__), 'model')

# ******************************************************************************
# **       Gestisce la lista dei server federati e le query sul tesauro       **
# ******************************************************************************
module ResourceManager
  include REXML

  @SKOS=RDF::Vocabulary.new("http://www.w3.org/2004/02/skos/core#")


  # Carica i Server federati nel database, leggendoli dal file xml
  def load_servers(filepath)

    f = File.open(filepath, "r:UTF-8")

    begin
      doc = Document.new f
      doc.elements.each("servers/server") do |s|
        doc2 = Document.new s.to_s
        Server.first_or_create(:serverID => doc2.to_s,
          :serverURL => s.attributes["serverURL"])
      end

    rescue
      return false
    end

    return true
  end


  # Carica il tesauro per future query
  def load_thesaurus(username)

    filepath = load_his_thesaurus(username)
    @skos = RDF::Vocabulary.new("http://www.w3.org/2004/02/skos/core#")
    repo = RDF::Repository.new
    semaphore = Mutex.new

    semaphore.synchronize {
      RDF::RDFXML::Reader.open(filepath) do |reader|
        reader.each_statement do |statement|
          repo.insert(statement)
        end
      end
    }

    return repo
  end


  # Trova il tesauro da caricare
  # Se esiste, carica quello personale
  def load_his_thesaurus(username)
    filepath = "resources/ltw1114-thesaurus-#{username}.xml"
    if File.exist?(filepath)
      return filepath
    else
      return "resources/ltw1114-thesaurus.xml"
    end
  end

  
  # Carica gli hashtag ammessi
  def load_admitted_tags(repo)

    tags = []

    q = repo.query(:predicate => @skos.prefLabel)
    q.each_statement do |statement|
      tags << statement.object.to_s
    end

    return tags
  end

  
  def get_server_id(node)
    sID = ""
    begin
      doc = Document.new node
      doc.elements.each("server") do |s|
        sID = s.attributes["serverID"]
      end
    rescue
      return nil
    end
    
    return sID.to_s
  end

  
  #Di default, la lista di ogni utente e' uguale a quella dei server federati
  def load_his_server_list(user, semaphore)

    servers = Server.all

    semaphore.synchronize {
      servers.each do |server|
        ServerList.first_or_create(:userID => user.userID,
          :serverID => server.serverID, :serverURL => server.serverURL)
      end
    }
  end

  
  # Crea una lista di server federati seguiti dall'utente
  # che fa la richiesta, in formato xml.
  def create_user_servers_list(userID, semaphore)

    root = Element.new "servers"

    semaphore.synchronize {
      list = ServerList.all(:userID => userID)
    
      list.each do |l|
        tmp = get_server_id(l.serverID.to_s)
        if not tmp.nil?
          root.add_element 'server', {"serverID" => tmp}
        end
      end
    }

    return root.to_s
  end


  # Sovrascrive la lista di server personale.
  # Prima effettua un controllo sull'esistenza dei server da aggiungere
  def load_new_user_servers_list(userID, bodyContent, semaphore)

    newlist = bodyContent

    begin
      doc = Document.new newlist
      doc.elements.each("servers/server") do |s|
        tmp = get_server_id(s.to_s)
        if Server.find_by_id(tmp).nil?
          return false
        end
      end

     semaphore.synchronize {   
        oldlist = ServerList.all(:userID => userID)
        oldlist.destroy
    
        doc.elements.each("servers/server") do |s|
          s_source = Server.find_by_id(get_server_id(s.to_s))
          ServerList.first_or_create(:userID => userID, :serverID =>  s_source.serverID,
            :serverURL => s_source.serverURL)
        end
    }

    rescue
      return false
    end

    return true
  end


  # Ricerca gli hashtag simili risalendo di un livello
  # l'albero del tesauro
  def get_related_terms(repo, term)
    
    # Il padre di "term"
    broader = ""
    broader_path = ""
    # I fratelli di "term"
    related_terms = []

    #Es: term="chitarra"
    q = repo.query(:predicate => @skos.narrower)
    q.each_statement do |statement|
      broader_path = statement.object.to_s
      nodes = broader_path.split('/')
      #Es: "tweb:/musica/strumenti/chitarra"
      if nodes.last == term
        #Es: "tweb:/musica/strumenti"
        path = statement.subject.to_s.split('/')
        broader = path.last
        break
      end
    end

    q = repo.query(:predicate => @skos.broader)
    q.each_statement do |statement|
      nodes = statement.object.to_s.split('/')
      if nodes.last == broader
        path = statement.subject.to_s.split('/')
        related_terms << path.last
      end
    end

    related_terms << broader
    return related_terms
  end


  # Calcola la somiglianza tra due post in base al numero
  # e al livello degli hashtag comuni.
  def calculate_affinity(tags_1, tags_2)

    how_much_related = 0

    curr_node1 = create_hashtag_tree(tags_1)
    curr_node2 = create_hashtag_tree(tags_2)

    how_much_related = explore(curr_node1, curr_node2, how_much_related)

    return how_much_related
  end


  # Struttura che serve per comparare
  # gli insiemi di hashtag di post diversi.
  def create_hashtag_tree(paths)
    
    root_node=Tree::TreeNode.new("ROOT", "tweb")

    paths.each do |path|
      nodes=path.split('/')
      create_tree(nodes, root_node)
    end

    return root_node
  end


  def create_tree(nodes, root_node)

    curr_node = root_node

    nodes.each do |n|
      childs = curr_node.children
      labels = []
      childs.each do |c|
        labels << c.name
      end
      if not labels.include?(n)
        tmp_node = Tree::TreeNode.new(n)
        curr_node << tmp_node
        curr_node = tmp_node
      else
        childs.each do |c|
          #Prosegue nel ramo giusto
          if c.name == n
            curr_node = c
          end
        end
      end
    end
  end


  def explore(curr_node1, curr_node2, how_much_related)

    children1 = curr_node1.children
    children2 = curr_node2.children
    labels1 = []

    children1.each do |child1|
      labels1 << child1.name
    end

    labels2 = []
    children2.each do |child2|
      labels2 << child2.name
    end

    h = curr_node1.node_depth + 1
    union = labels1 | labels2
    intersect = labels1 & labels2
    if union.length != 0
      how_much_related += (intersect.length.to_f / union.length.to_f) * h
    end

    children1.each do |child1|
      children2.each do |child2|
        #Continua l'esplorazione in profondita
        if (child1.name == child2.name)
          curr_node1 = child1
          curr_node2 = child2
          explore(curr_node1, curr_node2, how_much_related)
        end
      end
    end
    return how_much_related
  end


  # Aggiunge un termine nel tesauro personale
  def add_term(parent, child, repo, tags, username)

    # Esegue l'operazione se non è già presente quel tag e se
    # esiste il termine padre.
    if (not tags.include?(child)) and tags.include?(parent)

      path = ""
      filepath = "resources/ltw1114-thesaurus-#{username}.xml"
      if not File.exist?(filepath)
        load_new_thesaurus(username)
      end

      f = File.open(filepath, "r+:UTF-8")

      begin
        doc = Document.new f
        new_path = ""

        q = repo.query(:predicate => @skos.prefLabel)
        q.each_statement do |statement|
          terms = statement.subject.to_s.split('/')
          # Aggiorna il termine padre
          if terms.last == parent
            path = statement.subject.to_s
            doc.elements.each("rdf:RDF/rdf:Description") do |e|
              if e.attributes["rdf:about"] == path
                if path.include?('tweb')
                  new_path = "ltw"+path.slice(4, path.length)
                else
                  new_path = path
                end
                e.add_element 'skos:narrower', {"rdf:resource" => "#{new_path}/#{child}"}
              end
            end
          end
        end

        # Aggiunge un nuovo elemento
        root = doc.elements["rdf:RDF"]
        descr = root.add_element 'rdf:Description', {"rdf:about" => "#{new_path}/#{child}", "rdf:type" => "skos:Concept"}
        scheme = descr.add_element 'skos:inScheme', {"rdf:resource" => "ltw"}
        preflabel = descr.add_element 'skos:prefLabel'
        preflabel.text = child
        broader =  descr.add_element 'skos:broader', {"rdf:resource" => "#{path}"}
        
        # Memorizza su file
        doc.write(File.open(filepath, 'w+'), -1, false)

      rescue
        return false
      end

      return true

    else
      return false
    end
  end


  # Crea un nuovo file in cui salvare gli hashtag personali.
  def load_new_thesaurus(username)

    semaphore = Mutex.new
    to_copy = ""

    semaphore.synchronize {
      f1 = File.open("resources/ltw1114-thesaurus.xml", "r")
      f1.each_line do |line|
        to_copy += line 
      end
      f1.close
    }
    
    File.open("resources/ltw1114-thesaurus-#{username}.xml", "w+") {|f| f.write(to_copy) }
  end

end
