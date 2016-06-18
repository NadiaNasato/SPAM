function callLogin(name)
{
    //alert("login at url: "+ myServerUrl+'login'+"  MyName:"+name);
    $.ajax({
        type: 'POST',
        url:  myServerUrl+'login',
        data: {
            username:name
        },
        contentType: 'application/x-www-form-urlencoded',
        success: function() {
            loginLocale();
        },
        error: function(request, status, error){
            myServerUrl="/";
            myName =null;
            $.cookie(cookieMyName, null);
            $.cookie(cookieMyServ, null);  
            reportErr("errore login",request, status, error);
        }
    });
}
function callLogout()
{
    $.ajax({
        type: 'POST',
        url:  myServerUrl+'logout',
        contentType: 'application/x-www-form-urlencoded',
        success: function() {
            logoutLocale();
        },
        error: function(request, status, error){
            myServerUrl="/";
            myName =null;
            $.cookie(cookieMyName, null);
            $.cookie(cookieMyServ, null);  
            reportErr("errore logout",request, status, error);             
        }
    });
}
/**
 *metodo indipendente che viene chiamato dal timer per creare i polling post.
 */
function mkpposts()
{
    
    var pcount = 0;//indice dell'array
    //alert("ppost at url: "+ myServerUrl+'search/30/recent');
    $.ajax({
        type: 'GET',
        url: myServerUrl+'search/30/recent',
        dataType: "xml",
        contentType: 'application/x-www-form-urlencoded',
        success: function(xml) {
            $(xml).find('post').each(function(){
                countpposts++;
                var arl = $(this).find('article');
                var msg; 
                msg=arl.text();                
                //varie info
                var name = arl.attr("about");           
                var date = arl.attr("content");
                var aff = $(this).find('affinity').text();

                var tu = getTypeUrl(arl);//get type and url from article
                var asso = getAssoc(arl);//get associazioni tipo like dislike .. from article
                pposts[pcount] = new Ppost(countpposts,name,date,msg,tu[0],tu[1],asso,aff);  
                pcount++;               
            });
        } ,
        error: function(request, status, error){
            clearInterval(pollingrobot);
            reportErr("errore pollingpost",request, status, error);
            
        }
    });
}
/**
 *Invio post
 *@author Nadia
 *modificato da Tong
 */
function callNewPost(message)
{
    var url= myServerUrl+"post";
    //**********invia post nel caso di reply**********************
    if(post_cache != null)
    {
        url= myServerUrl+"replyto";      
        var about=post_cache.split("/");        
        // alert(url +"  "+" \nserver:"+about[1]+" \nuser:"+about[2]+" \npost:"+about[3] +" \nbody: " + message);
        $.ajax({
            type: 'POST',
            url: url,
            data: {
                serverID:about[1],
                userID: about[2],
                postID:about[3],
                article:message
            },
            contentType: "application/x-www-form-urlencoded",
            success: function() {
                $("#envelope").show("bounce", {}, 100);
                var url = myServerUrl+'search/'+1+'/author/'+myServerChoice+myName;
                callSearchThePost(url,"crt");
            } ,
            error: function(request, status, error){
                reportErr("errore reply to",request, status, error);
            }
        });      
    }
    //*************invia post nel caso di spam**************************
    else
    {
        // alert(url +"  "+ "body: " + message);
        $.ajax({
            type: 'POST',
            url: url,
            data: {
                article:message
            },
            contentType: "application/x-www-form-urlencoded",
            success: function() {
                $("#envelope").hide("slide", {}, 500);
                $("#envelope").show("bounce", {}, 200)
                // alert("mnid:"+countmposts);
                var url = myServerUrl+'search/'+1+'/author/'+myServerChoice+myName;
                callSearchThePost(url,"crt");
            //reportSuc("post spam inviato");
            } ,
            error: function(request, status, error){
                reportErr("errore new post",request, status, error);
            }
        });
    }
        
}
//richiesta per search post
function callSearchPosts(url)
{
    //alert(url);
    $.blockUI({
        message: '<h1 id="msgBlock"><img src="images/attesa.gif" /> Please hold on a sec ...</h1>'
    });
   
    $.ajax({
        type: 'GET',
        url: url,
        dataType: 'xml',
        contentType: 'application/x-www-form-urlencoded',
        success: function(xml) {
            xmlToMidposts(xml);            
            $('#msgBlock').animate({
                opacity: 0.25   
            }, 1000, function() {
                $.unblockUI();
            });
        },
        error: function(request, status, error){
            $.unblockUI();            
            reportErr("search post failed",request, status, error); 
        },
        complete: function(request, status, error){
            $('#msgBlock').animate({
                opacity: 0.25   
            }, 1000, function() {
                $.unblockUI();
            });           
        }
                                                
    });
}
//richiesta per search un post
function callSearchThePost(url,type)
{
    //  alert(url);
    $.ajax({
        type: 'GET',
        url: url,
        dataType: 'xml',
        contentType: 'application/x-www-form-urlencoded',
        success: function(xml) {
            xmlToOneMidpost(xml);      
            if(type == "crt")
            {
                $("#mpost"+countmposts).show("bounce", {}, 200);
                  $("#mpost"+countmposts).css("background-color","#FFEBCD"); 
                
            }
            else
                {
                     $("#mpost"+countmposts).show("shake", {}, 100);
                     $("#mpost"+countmposts).css("background-color","#F5F5F5");   
                }
               
        },
        error: function(request, status, error){         
            reportErr("search post failed",request, status, error); 
        }                                              
    });
}
function callSetLike(post,ico,about,pref)
{    
    var ids=about.split("/");
    //alert(myServerUrl+"setlike" + " \nserver:"+ids[1]+" \nuser:"+ids[2]+ " \npost:" +ids[3]+ " \npref: "+ pref );
    $.ajax({
        type: "POST",
        contentType: "application/x-www-form-urlencoded; charset=UTF-8",
        scriptCharset: "utf-8" ,
        url:myServerUrl+"setlike", 
        data: {
            serverID:ids[1],
            userID:ids[2],
            postID:ids[3],
            value:pref
        },
        success: function(msg){     
            if(ico=="like")
                setLikeLocale(post);
            else if(ico=="dislike")
                setDislikeLocale(post);
            else
                alert("ajax ok, err client setlike");
        } ,        
        error: function(request, status, error){
            reportErr("set like failed",request, status, error);          
        }
    });
}
function callRespam(about)
{
    var abtArray=about.split("/");
    //alert(myServerUrl+"respam" + " \nserver:"+abtArray[1]+" \nuser:"+abtArray[2]+ " \npost:" +abtArray[3]);
    $.ajax({
        type: "POST",
        contentType: "application/x-www-form-urlencoded; charset=UTF-8",
        scriptCharset: "utf-8" ,
        url:myServerUrl+"respam",        
        data: {
            serverID:abtArray[1],
            userID:abtArray[2],
            postID:abtArray[3]
        },
        success: function(){  
            $("#envelope").hide("slide", {}, 500);
            $("#envelope").show("drop", {}, 500);
            var url = myServerUrl+'search/'+1+'/author/'+myServerChoice+myName;
            callSearchThePost(url,"crt");
        } ,
        error: function(request, status, error){
            reportErr("respam failed",request, status, error);
        }
    });
}
function callGetTesauri()
{
    $.ajax({
        type: 'GET',
        url: myServerUrl+'thesaurus',
        dataType: 'xml',
        contentType: "application/x-www-form-urlencoded; charset=UTF-8",
        scriptCharset: "utf-8" ,
        success: function(xml) {
            loadTesauri(xml);
        } ,
        error: function(request, status, error){
            reportErr("get tesauro failed",request, status, error);       
        }
    });
}
function callAddTerm(pa,fi)
{
    //    alert( " url: "+myServerUrl+"addterm \n"
    //        +"parentterm: "+pa+"; term: "+fi );
    $.ajax({
        type: "POST",
        contentType: "application/x-www-form-urlencoded; charset=UTF-8",
        scriptCharset: "utf-8" ,
        url:myServerUrl+"addterm", 
        data: {
            parentterm:pa,
            term:fi
        },
        success: function(msg){    
            $("#treeview").remove();        
            callGetTesauri();
        } ,        
        error: function(request, status, error){
            reportErr("add term failed",request, status, error);
          
        }
    });
}
/**
 * @author Nadia
 * modificato da Tong
 */
function postServers(serverList,b)
{
    if(postSeverSemaphore)
    {
        postSeverSemaphore = false;
        $.ajax({
            type: 'POST',
            url: myServerUrl+'servers',
            data: {
                servers:serverList
            },
            contentType: "application/x-www-form-urlencoded; charset=UTF-8",
            scriptCharset: "utf-8" ,
            success: function() {
                changeServButton(b);
            //postSeverSemaphore = true;
            } ,
            error: function(request, status, error){
                reportErr("modified server failed",request, status, error);
            // postSeverSemaphore = true;
            //callServerList();
            },
            complete: function(){
                postSeverSemaphore = true;
            }
        });
    }
   
    else
        reportWait("  give me more time to think and I'll do it better ...   ");
}
/**
 * @author Nadia
 */
function callServerList()
{
    $.ajax({
        type: "GET",
        url: myServerUrl+"servers",
        dataType: "xml",
        success: function(xml) {
            loadServers(xml);
        } ,
        error: function(request, status, error){
            reportErr("get server list failed",request, status, error);
        }
    });
}
/**
 * @author Nadia
 */
function callGetFollowing()
{
    $.ajax({
        type: "GET",
        url: myServerUrl+"followers",
        dataType: "xml",
        success: function(xml) {
            loadFollowing(xml);
        },
        error: function(request, status, error){
            reportErr("get following failed",request, status, error);          
        }
    });
}
/**
 * @author Nadia
 * modificato da Tong
 */
function callSetFollow(sID, uID, val)
{
    //    alert( " url: "+myServerUrl+"setfollow \n"
    //        +"server: "+sID+" term: "+uID +  " val: "+val );
    $.ajax({
        type: 'POST',
        url:myServerUrl+"setfollow",
        data: {
            serverID:sID,
            userID:uID,
            value:val
        },
        contentType: "application/x-www-form-urlencoded; charset=UTF-8",
        scriptCharset: "utf-8" ,
        success: function() {
            //reportSuc("set follow effettuato");
            if(val == 1)//add utente alla lista di following
                addFollowToList(sID+"/"+uID) ;
            else if(val == 0)//cancella utente nella lista di following
            {
                $(".ls_flw").find(".user").each(function(){
                    if($(this).text()==sID+"/"+uID)
                    {
                        $(this).parent().hide();
                        $(this).parent().removeClass("ls_flw");
                    }
                });
            }            
        },
        error: function(request, status, error){
            reportErr("set following failed",request, status, error); 
        }
    });
}
