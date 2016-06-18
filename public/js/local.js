/*****
 *METODI LOCALI:
 *
 *
 */
/********************************************************************/
/**************Login  & Lognout locali*******************************/
/********************************************************************/
function loginButton(name)
{
    if(name != "")
    {
        $("#login").find(".ui-button-text").text("log out: " +name);
        $("#login").find(".ui-button-icon-primary").removeClass("ui-icon-locked");
        $("#login").find(".ui-button-icon-primary").addClass("ui-icon-unlocked");
    }
   
    else
    {
        $("#login").find(".ui-button-text").text("login");
        $("#login").find(".ui-button-icon-primary").removeClass("ui-icon-unlocked");
        $("#login").find(".ui-button-icon-primary").addClass("ui-icon-locked");
    }
    
}

function loginLocale()
{
    needShow=false;
    $.cookie(cookieMyName, myName);
    $.cookie(cookieMyServ, myServerChoice);
    loginButton(myServerChoice+myName);
    preloadServers();//Nadia
    callServerList();//Nadia
    callGetFollowing();//Nadia
    callGetTesauri();
    pollingrobot = window.setInterval(timedCount, 10000);

    if(!$("#accordion").is(":visible"))//mostra le liste
        $("#accordion").show("blind","slow"); 
}
function logoutLocale()
{
    clearInterval(pollingrobot);
    myName=null;
    myServerUrl="/";
    $(".server").remove();
    $(".ls_flw").remove();
    $("#treeview").remove();
    $(".postdiv").fadeOut("slow", function(){
        $(this).remove();
    });
//    $(".postdiv").hide("bounce", {}, 200,function(){
//        $(".postdiv").remove();
//    });
    if($("#accordion").is(":visible"))//nasconde le liste
        $("#accordion").hide("blind","slow");          
    loginButton("");//aggiorna login button    
    $.cookie(cookieMyName, null);
    $.cookie(cookieMyServ, null);    

}
/********************************************************************/
/***********la lettura per il testo del spam*************************/
/********************************************************************/
/**
 *@author Nadia
 *modificato da Tong
 */
function readSpam(post)
{   
    var postorig = post;
    post = post.replace(/&/g," and ");
    var words=post.split(" ");
    for (var i=0; i<words.length; i++) {
        // Se la parola inizia con # ...
        if (words[i].match(/^#(\w+)/i)!=null) {

            var term1=words[i].substring(1, words[i].length);
            var re = new RegExp(words[i]);
            var path1="";
            // Cerco se e' una parola presente nel tesauro
            for (var j=0; j<categories.length; j++) {
                if (categories[j].term.match(term1)!=null) {
                    path1=categories[j].path.toString();
                }
            }

            // Se appartiene al tesauro condiviso, il suo path comincia con tweb:/...
            if (path1.indexOf("tweb")!=-1) {
                // Rimuovo 'tweb:' e acquisisco il resto, che diventa il valore dell'
                // attributo 'about'
                path1=path1.substring(5, path1.length);
                // Aggiungo gli span relativi
                post=post.replace(re, "<span rel='sioc:topic'>#<span typeof=\"skos:Concept\" about=\""+path1+"\" rel=\"skos:inScheme\" resource=\"http://vitali.web.cs.unibo.it/TechWeb11/thesaurus\">"+term1+"</span></span>");
            } // Se appartiene al tesauro esteso, il suo path comincia con ltw1114:/...
            else if (path1.indexOf("ltw")!=-1) {
                // Rimuovo 'ltw1114:'
                path1=path1.substring(5,path1.length);
                post=post.replace(re, "<span rel='sioc:topic'>#<span typeof=\"skos:Concept\" about=\""+path1+"\" rel=\"skos:inScheme\" resource=\"http://ltw1114.web.cs.unibo.it/thesaurus\">"+term1+"</span></span>");
            } // Se non appartiene al tesauro, e' una semplice tag con metadati generali
            else {
                post=post.replace(re, "<span rel='sioc:topic'>#<span typeof='ctag:Tag' property='ctag:label'>"+term1+"</span></span>");
            }
        }
    }
    //***********controlla url e type******************
    var tmpUrl = $("#npUrl").val();
    tmpUrl=$.trim(tmpUrl);
    var tp = getTypeFromUrl(tmpUrl);
    if(tp == "audio")
    {
        post = post + "<span resource ='audio' src ='"+tmpUrl+"' />";
    }        
    else if(tp == "video")
    {
        var ind =  tmpUrl.indexOf("&", 0);
        if(ind !=-1)
            tmpUrl =  tmpUrl.substring(0, ind);
        post = post + "<span resource ='video' src ='"+tmpUrl+"' />";
    }
        
    else if(tp == "image")
        post = post + "<span resource ='image' src ='"+tmpUrl+"' />";
    else
        // post = post+" " +tmpUrl;
        post = post + " <a href='"+tmpUrl+"'>"+tmpUrl+"</a> ";
    //**********impacchetta l'article**********************
    var message="<article>"+post+"</article>";
    return message;
}

/********************************************************************/
/**************la finestra la ricerca********************************/
/********************************************************************/
/**
 * @author Enrico, modificato da Tong e Nadia
 */
function useTag(e){
    if (e.keyCode == 13) {
        e.preventDefault();
    } 
    $("#npTextArea").focus();        
    var phrase = $('#npTextArea').val();
    var lastChar = phrase.charAt(phrase.length-1);
    if(lastChar == "#")
        $('#npTextArea').val($('#npTextArea').val() + $('#npTag').val() + " ");
    else 
        $('#npTextArea').val($('#npTextArea').val() + " #" + $('#npTag').val() + " ");
    $("#npTag").val("");     
}

/**
 * @author Enrico, modificato da Tong
 */
function control(){
    $("#rsTag").autocomplete(availableTags);
}
/**
 * @author Enrico
 */
function suggerisci(azione){
    $('#campoRicerca').html('');
    $('#campoRicerca').append(azione);
    $("#hash").css("display", "none");
    $("#oggetto").css("display", "inline");
}
/**
 * @author Enrico
 */
function mostra(azione2){
    $('#campoRicerca').html('');
    $('#campoRicerca').append(azione2);
    $("#hash").css("display", "block");
    $("#oggetto").css("display", "none");
}
/**
* @author Enrico
*/
function nascondi(azione3){
    $('#campoRicerca').html('');
    $('#campoRicerca').append(azione3);
    $("#hash").css("display", "none");
    $("#oggetto").css("display", "none");
}
/**
* @author Enrico
*/
$(function() {
    $("#slider").slider({
        value:10,
        min: 5,
        max: 30,
        step: 1,
        slide: function(event, ui) {
            //$("#all").attr("checked",false);
            //$("#mun").attr("checked",true);
            $("#amount").val(ui.value);
            if(document.getElementById("num").checked != true)
            document.getElementById("num").checked = true; 
        }
    });
    $("#amount").val($("#slider").slider("value"));
});
/**
* @author Enrico
*/
function checkkk()  { 
    alert(111);
   document.getElementById("num").checked = true; 
 }

/********************************************************************/
/**************Lista di Server e Following***************************/
/********************************************************************/
/**
* @author Nadia 
* modificato da Tong
*/
function preloadServers(){
    $.get("server.xml", null, function (data) {
        $(data).find('servers server').each(function () {
            $("#servers").append("<button class=\"server\" id=\""+$(this).attr('serverID').toString()+"\">"+$(this).attr('serverID').toString()+"</button>");
        });
        // Di default, tutti i server non ancora stati aggiunti
        $(".server").button({
            icons: {
                primary: "ui-icon-circle-plus"
            }
        });
        $(".server").fadeTo('fast', 0.5);
        $( ".server" ).click(function() {
            var dele = false;
            var attr = $(this).attr('id');
            if ($(this).hasClass("selectedServ")) {            
                dele = true;
            }
            // Crea la lista di server da sovrascrivere, includendo
            // solo quelli selezionati e fa POST
            var xmlDoc = "<servers>"
            $('.selectedServ').each(function () {
                if($(this).attr('id') != attr)
                xmlDoc += '<server serverID="'+$(this).attr('id')+'" />';
            });
            if(!dele)
                xmlDoc += '<server serverID="'+attr+'" />';
            xmlDoc += "</servers>";         
            // alert(xmlDoc);
            postServers(xmlDoc.toString(),$(this));
        });
    });
    
}
/**
* @author Nadia 
*/
function loadServers(data) {     
    $(".server").button({
        icons: {
            primary: "ui-icon-circle-plus"
        }
    });
    $(".server").fadeTo('fast', 0.5);
    // Parso la lista di server e per ogni server, abilito il pulsante
    // per rimuoverlo
    $(data).find('servers server').each(function () {

        var id = $(this).attr('serverID');
        $('#'+id).button({
            icons: {
                primary: "ui-icon-circle-minus"
            }
        });
        $('#'+id).fadeTo('fast', 1);
        $('#'+id).addClass("selectedServ");
    });

}
/**
 * @author Nadia 
 * modificato da Tong
 */
function changeServButton(b)
{
    if ($(b).hasClass("selectedServ")) {            
        $(b).button({
            icons: {
                primary: "ui-icon-circle-plus"
            }
        });
        $(b).removeClass("selectedServ");
        $(b).fadeTo('fast', 0.5);
    } else {
        $(b).button({
            icons: {
                primary: "ui-icon-circle-minus"
            }
        });
        $(b).addClass("selectedServ");
        $(b).fadeTo('fast', 1);
    }
}
/**
* @author Nadia 
*/
function loadFollowing(data) {     
    $(data).find('followers follower').each(function () {
        var id =$(this).attr("id");
        addFollowToList(id);
        if(!needShow)
            needShow=true;
    });    
    if(needShow)
    {
        url = myServerUrl+'search/'+15+'/following';          
        callSearchPosts(url);
    }
}
/**
* @author Tong
*/
function addFollowToList(flw)
{
    $("#tabs-1").append("<div class='ls_flw'><span class='ui-icon ui-icon-scissors  detachflw' title='unfollow'></span> <div class='user'>"+flw+"</div> </div>");
    $(".detachflw").parent().find(".user").dblclick(function(){           
        var url = myServerUrl+'search/'+15+'/author/'+flw;                  
        callSearchPosts(url);
    });
    $(".detachflw").click(function(){           
        var userId = $(this).parent().find(".user").text(); 
        var splited = userId.split("/");
        callSetFollow(splited[0], splited[1],"0");
    });
    $(".detachflw").removeClass("detachflw");
}
/************************************************************/
/**********************Lista tesauri*************************/
/************************************************************/
/**
* @author Nadia 
*/
function Tesauro() {
    this.term="";
    this.path="";
}
/**
*lettura tesauri*
*
* @author Nadia 
* @author Tong
*/
function loadTesauri(rdfXml)
{
    $("#tesauriList").append("<ul id='treeview' /></ul>");
 
    availableFathers = new Array();
    availableTags = new Array();
    categories = new Array();

    // Inserisco i tag delle macrocategorie
    t = new Tesauro();
    t['term']= "sport";
    t['path']= "tweb:/sport";
    categories.push(t);
    availableTags.push(t.term.toString());

    t = new Tesauro();
    t['term']= "musica";
    t['path']= "tweb:/musica";
    categories.push(t);
    availableTags.push(t.term.toString());

    t = new Tesauro();
    t['term']= "letteratura";
    t['path']= "tweb:/letteratura";
    categories.push(t);
    availableTags.push(t.term.toString());

    t = new Tesauro();
    t['term']= "informatica";
    t['path']= "tweb:/informatica";
    categories.push(t);
    availableTags.push(t.term.toString());

    var rdf;
    rdf = $.rdf()
    .load(rdfXml)
    .prefix('skos', 'http://www.w3.org/2004/02/skos/core#')
    .prefix('rdf', 'http://www.w3.org/1999/02/22-rdf-syntax-ns#')
    .prefix('tweb', 'http://vitali.web.cs.unibo.it/TechWeb11/thesaurus')
    rdf
    .where('?resource skos:prefLabel ?lab')
    .where('?subclass skos:broader ?resource')
    .where('?subclass skos:prefLabel ?label')
    .each(function () {
        t = new Tesauro();
        t['term']= this.label.value;
        t['path']= this.subclass.value;
        categories.push(t);
        availableTags.push(this.label.value.toString());

        $("#treeview").not(":has(ul[id='ul_"+this.lab.value+"'])")
        .append("<li id="+this.lab+" class = 'closed' ><img src='/images/folder-closed.gif' /><span class='tFindable'>" + this.lab.value + "</span><ul id='ul_"+ this.lab.value + "'></ul></li>");
        var strg = this.resource.value.toString();
        var splt = strg.split("/");
        if(splt.length>=3){
            availableFathers.push(this.label.value.toString());
            $("<li id="+this.label+" class='tAddable closed'><img class='canImgFile' src='/images/folder-closed.gif' /><span class='tFindable'>" + this.label.value + "</span><ul id='ul_"+ this.label.value + "'></ul></li>")
            .appendTo("ul[id='ul_"+this.lab.value+"']");       
        }      
        else
            $("<li id="+this.label+" class = 'closed' ><img src='/images/folder-closed.gif' /><span class='tFindable'>" + this.label.value + "</span><ul id='ul_"+ this.label.value + "'></ul></li>")
            .appendTo("ul[id='ul_"+this.lab.value+"']");

    });  
    $("ul:empty").parent().removeClass("closed");
    $("ul:empty").parent().find("img").each(function(){
        if($(this).hasClass("canImgFile"))
        {
            $(this).attr("src","/images/file.gif");
        }
    });
   
    $("ul:empty").remove();
    $("#treeview").treeview({
        control: "#treecontrol",
        persist: "cookie",
        cookieId: "treeview-black"
    });
    
    $(".tFindable").each(function(){
        var padre =  $(this).text();
        //availableFathers.push(padre); 
        $(this).bind("dblclick",function(){
            var rlt = $(this).text();
            var url = myServerUrl+'search/'+10+'/related/'+ rlt;
            callSearchPosts(url);
        });
    });
  
    $( "#rsTag" ).autocomplete({
        source: availableTags
    });
    $( "#npTag" ).autocomplete({
        source: availableTags
    });
    $( "#addTsrPadre" ).autocomplete({
        source:  availableFathers
    });
}

/************************************************************/
/**********************Utilities*************************/
/************************************************************/
function checkLength(field,maxlimit) 
{
   
    if ( field.value.length > maxlimit )
    {
        field.value = field.value.substring( 0, maxlimit );
    // alert( 'Textarea value can only be 255 characters in length.' );
    //return false;
    }
//  else
//  {
//    countfield.value = maxlimit - field.value.length;
//  }
}
function isAllow(targ)
{
    var allow = false;
    if(targ!==""&&targ.indexOf("/")==-1&&targ.indexOf("\\")==-1&&targ.indexOf("#")==-1&&targ.indexOf("&")==-1)
    {
        allow = true;
    }
                 
    return allow;
}
function reportErr(reason,request, status, error)
{
    if($( "#dialogErrAjax > div" ).length)
        $( "#dialogErrAjax > div" ).remove();
    $( "#dialogErrAjax" ).append("<div>"+reason+" ...<div>");
    $( "#dialogErrAjax > div" ).append("il server comunica, \nstato : "+status+" \nmessaggio: "+request.responseText
        +" \nerror: "+error);
    $( "#dialogErrAjax" ).dialog( "open" ); 
}
function reportSuc(reason)
{

    if($( "#dialogSucAjax > div" ).length)
        $( "#dialogSucAjax > div" ).remove();
    $( "#dialogSucAjax" ).append("<div>"+"<img src ='images/ok.gif' alt='img succeed'></img>"+reason+"<div>");
    $( "#dialogSucAjax" ).dialog( "open" ); 
}
function reportWait(reason)
{

    if($( "#dialogWait > div" ).length)
        $( "#dialogWait > div" ).remove();
    $( "#dialogWait" ).append("<div>"+"<img src ='images/wait.gif' alt='please wait ..'></img>"+reason+"<div>");
    $( "#dialogWait" ).dialog( "open" ); 
}
function timedCount()
{    
    if(myName !=null)
    {
        var temp;
        if(readppostContatore >= pposts.length)
        {
            mkpposts();//la nuova richiesta per i post recenti           
            readppostContatore=0;
            temp = pposts[readppostContatore];
            createPollingPost(temp.count,temp.name,temp.date,temp.msg,temp.type,temp.url,temp.asso,temp.aff);
            readppostContatore++;
        //clearInterval(ins);
        }   
        else
        {   //leggere l'array di post e creare il post         
            temp = pposts[readppostContatore];
            createPollingPost(temp.count,temp.name,temp.date,temp.msg,temp.type,temp.url,temp.asso,temp.aff);
            readppostContatore++;
        }
    } 
}


