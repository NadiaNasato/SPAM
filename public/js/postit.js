



/************************************************************************/
/***********************CREATION**for**posts*****************************/
/************************************************************************/


/************metodo che interpreta xml e crea mid post*********************/
function xmlToMidposts(xml){
    
    $(".midpost").fadeOut("slow",function(){
        $(this).remove();
    });
    
    dia=0;//diametro per il midpost
    incrementoDidia=60;//il valore del incremento del diametro supposto
    ref=1;//soglia dei numeri del post, dopo il qualche il diametro si incrementa
    countTmp=0;//count post visualizzazi
    numTotaleDiPostsDaMostrare = $(xml).find('post').length;
    zindex = $(xml).find('post').length;
    if(numTotaleDiPostsDaMostrare<8)//numero di post del primo livello
    {
        incrementoDidia=90;
    }
    else if(numTotaleDiPostsDaMostrare<16)//numero di post del secondo livello
    {
        incrementoDidia=70;
    }
    else if(numTotaleDiPostsDaMostrare < 32)//numero di post del terzo livello
    {
        incrementoDidia=45;
    }
       

    $(xml).find('post').each(function(){
        countmposts++;
        var arl = $(this).find('article');
        var msg; 
        msg=arl.text();  
        //  msg=toPostText(arl.text().toString());
        //varie info
        var name = arl.attr("about");
        var date = arl.attr("content");
        var aff = $(this).find('affinity').text();

        var tu = getTypeUrl(arl);
        var asso = getAssoc(arl);

        if(name!=undefined && date != undefined)
        {
               
            createMidPost(countmposts,name,date,msg,tu[0],tu[1],asso,aff);
        }
            
    });
    
}

function xmlToOneMidpost(xml){      
        
    var arl = $(xml).find('article');
    var msg; 
    msg=arl.text();              
    //varie info
    var name = arl.attr("about");
    var date = arl.attr("content");
    var aff = 1;

    var tu = getTypeUrl(arl);
    var asso = getAssoc(arl);

    if(name!=undefined && date != undefined)
    {
        countmposts++;
        createOneMidPost(countmposts,name,date,msg,tu[0],tu[1],asso,aff);
    }
 
}

/**
 *show a recent post
 *@param i id post
 *@name author
 *@date date time
 *@msg messaggio
 *@type video image  others ""
 *@url "" in the other case
 *@assoc dati associati affinita like dislike altri commenti
 */
function createPollingPost(i,abt,date,msg,type,url,asso,aff)
{
    var abtArray=abt.split("/");
    var name = abtArray[1]+"/"+abtArray[2];
    //prima di mettere un nuovo ppost caccia giu' tutti i polling post
    $(".ppost").animate({
        top: '+=100'
    },1500, function(ui) {
        var y = $(this).css("top");
        var id =$(this).attr("id");
        if(y>"565px")
        {
            $(this).fadeOut("slow",function(){
                $(this).remove();
            });
        }
    });
    
    //convertisco info in asso
    var assoArray = asso.split(";");
    //trovo la mia preferenza, se ho fatto like o dislike
    var mypref="";
    switch(assoArray[0])
    {
        case "-1":
            mypref="dislike";
            break;
        case "1":
            mypref="like";
            break;
        default:
            mypref="";
    }
    //segnalo gli stati dei messaggi
    var st="<ul>";
    for(var j=3;j<assoArray.length;j++)
    {
        st += "<li>"+assoArray[j]+"</li>";
    }
    st += "</ul>";
    
    
    //formare il post             
    var tmpid = "ppost"+i;
    var post = "<div class='postdiv ppost "+mypref+"'"+" id='"+tmpid+"' title='"+type+"'>"; 
    post +=  stringNDM(name,date,msg);                
     
    if(type=="video")
    {
        post +=  stringVidUNM(url,name,msg,assoArray[1],assoArray[2],st,aff);            
    }           
    else if(type=="image")
    {
        post += stringImgUNM(url,name,msg,assoArray[1],assoArray[2],st,aff);   
    } 
    else if(type=="audio")
    {
        post += stringAudUNM(url,name,msg,assoArray[1],assoArray[2],st,aff);
    } 
    else
        post += stringText(assoArray[1],assoArray[2],st,aff);   
    post  +="<div class='postAbout'>"+abt+"<div></div>"//close root           
       
    $("#left").append(post);
    //associa le icone
    addPostIcons(tmpid);
    //associa eventi e funzioni
    addPostFun(tmpid);
    //override draggable 
    //se il ppost e' stato trascinato
    // non sta piu' in fila con gli altri ppost
    $("#ppost"+i).draggable({
        containment: "#container",
        drag: function() {
            if($(this).hasClass("ppost"))
            {
                $(this).removeClass("ppost");
            }     
        }
    });
    //setta la posizione. non funziona bene in firefox 3.6
    //    $("#ppost"+i).position({
    //        my: "left top",
    //        at: "left top",
    //        of: "#left",
    //        offset: "10 10",
    //        collision: "fit"
    //    });
    var param= $("#left").width();
    var offset = $("#left").offset();
    var top = offset.top+12;
    var left = offset.left+param/19;
    $("#ppost"+i).css({
        'top' : top, 
        'left' : left
    }); 
    $("#ppost"+i).delay(1000).fadeIn(3000);
}
/**
 *show a recent post
 *@param i id post
 *@name author
 *@date date time
 *@msg messaggio
 *@type video image  others ""
 *@url "" in the other case
 *@assoc dati associati affinita like dislike altri commenti
 */
function createMidPost(i,abt,date,msg,type,url,asso,aff)
{
    var abtArray=abt.split("/");
    var name = abtArray[1]+"/"+abtArray[2];
    //convertisco aossiciazioni in array
    var assoArray = asso.split(";");
    //trovo la mia preferenza, se ho fatto like o dislike
    var mypref="";
    switch(assoArray[0])
    {
        case "-1":
            mypref="dislike";
            break;
        case "1":
            mypref="like";
            break;
        default:
            mypref="";
    }
    //segnalo gli stati dei messaggi
    var st="<ul>";
    for(var j=3;j<assoArray.length;j++)
    {
        st += "<li>"+assoArray[j]+"</li>";
    }
    st += "</ul>";
    //formulo il postdiv
    var tmpid = "mpost"+i;
    var post = "<div class='postdiv midpost "+mypref+"' id='"+tmpid+"' title='"+type+"'>";    
    post +=  stringNDM(name,date,msg);                
     
    if(type=="video")
    {
        post +=  stringVidUNM(url,name,msg,assoArray[1],assoArray[2],st,aff);            
    }           
    else if(type=="image")
    {
        post += stringImgUNM(url,name,msg,assoArray[1],assoArray[2],st,aff);   
    } 
    else if(type=="audio")
    {
        post += stringAudUNM(url,name,msg,assoArray[1],assoArray[2],st,aff);
    } 
    else{
        post += stringText(assoArray[1],assoArray[2],st,aff);
    }
    post  +="<div class='postAbout'>"+abt+"<div></div>"//close root              
    $("#mid").append(post);

    addPostIcons(tmpid);    
    addPostFun(tmpid);  
    //calcola l'offset a partire dal suo diametro 
    var ofst = calcolaMidPostPosition(i);
    $("#"+tmpid).position({
        my: "center",
        at: "center",
        of: "#mid",
        offset: ofst,
        collision: "fit"
    });  
    $("#"+tmpid).css("z-index",numTotaleDiPostsDaMostrare);
    numTotaleDiPostsDaMostrare--;

}
function createOneMidPost(i,abt,date,msg,type,url,asso,aff)
{
    var abtArray=abt.split("/");
    var name = abtArray[1]+"/"+abtArray[2];
    //convertisco aossiciazioni in array
    var assoArray = asso.split(";");
    //trovo la mia preferenza, se ho fatto like o dislike
    var mypref="";
    switch(assoArray[0])
    {
        case "-1":
            mypref="dislike";
            break;
        case "1":
            mypref="like";
            break;
        default:
            mypref="";
    }
    //segnalo gli stati dei messaggi
    var st="<ul>";
    for(var j=3;j<assoArray.length;j++)
    {
        st += "<li>"+assoArray[j]+"</li>";
    }
    st += "</ul>";
    //formulo il postdiv
    var tmpid = "mpost"+i;
    var post = "<div class='postdiv midpost "+mypref+"' id='"+tmpid+"' title='"+type+"'>";    
    post +=  stringNDM(name,date,msg);                
     
    if(type=="video")
    {
        post +=  stringVidUNM(url,name,msg,assoArray[1],assoArray[2],st,aff);            
    }           
    else if(type=="image")
    {
        post += stringImgUNM(url,name,msg,assoArray[1],assoArray[2],st,aff);   
    } 
    else if(type=="audio")
    {
        post += stringAudUNM(url,name,msg,assoArray[1],assoArray[2],st,aff);
    } 
    else{
        post += stringText(assoArray[1],assoArray[2],st,aff);
    }
    post  +="<div class='postAbout'>"+abt+"<div></div>"//close root              
    $("#mid").append(post);

    addPostIcons(tmpid);    
    addPostFun(tmpid);  
    //calcola l'offset a partire dal suo diametro 
    var ofst = calcolaMidPostPosition(i);
    $("#"+tmpid).position({
        my: "center",
        at: "center",
        of: "#mid",
        offset: ofst,
        collision: "fit"
    });  
    zindex++;
     $("#"+tmpid).css({'z-index' : zindex, 'display' : 'none'}); 
}


function stringNDM(name,date,msg)
{
    var rlt ="<div class='postUser'>"+name+":</div>"
    +"<div class='postDate'>"+date+"</div>"
    +"<br/><div class='postTxt'>"+msg+"</div>" ;
    return rlt;
}
function stringVidUNM(url,name,msg,lk,dk,st,aff)
{
    var ur;    
    var i = url.indexOf("&", 0);
    if(i !=-1)
        ur = url.substring(0, i);
    else 
        ur=url;
    
    ur = urlToV(ur);
    var rlt ="<div class='postRich'>"//op postRich
                    
    +"<div class='postIframe'>"//op iframe
    +"<iframe  width='300px' height='230px' src='"+ur+"' />"
    +"</div>"//close iframe
                       
    +"<div class='postReplies ui-widget-content ui-corner-all'>"//op reply menu                  
    +"<div> "+name+" : "+"</div>"
    +"<div> "+msg+"</div>"
    +"<hr/>"
    +"<div><span class='ctlk'>"+lk+"</span> like, <span class='ctdk'>"+dk+"</span> dislike. affinity:"+aff+"</div>"
    +"<hr/>"
    +st
    +"</div>"//close reply menu
    +"</div>"//close postRich
    return rlt;
}
function stringImgUNM(ur,name,msg,lk,dk,st,aff)
{
    var rlt ="<div class='postRich'>"//op postRich
                    
    +"<div class='postIframe'>"//op iframe
    +"<img class='postImg' src='"+ur+"' alt='image not load' />"
    +"</div>"//close iframe
                       
    +"<div class='postReplies ui-widget-content ui-corner-all'>"//op reply menu                   
    +"<div> "+name+" : "+"</div>"
    +"<div> "+msg+"</div>"
    +"<hr/>"
    +"<div><span class='ctlk'>"+lk+"</span> like, <span class='ctdk'>"+dk+"</span> dislike. affinity:"+aff+"</div>"
    +"<hr/>"
    +st
    +"</div>"//close reply menu
    +"</div>"//close postRich

    return rlt;
}
function stringAudUNM(ur,name,msg,lk,dk,st,aff)
{
    var rlt ="<div class='postRich'>"//op postRich
                    

    + "<embed class='postAud'  src = 'http://www.google.com/reader/ui/3523697345-audio-player.swf' flashvars = 'audioUrl="+ur+"' quality='best' type='application/x-shockwave-flash' pluginspage='http://www.macromedia.com/go/getflashplayer' />"

                       
    +"<div class='postReplies ui-widget-content ui-corner-all'>"                  
    +"<div><span class='ctlk'>"+lk+"</span> like, <span class='ctdk'>"+dk+"</span> dislike. affinity:"+aff+"</div>"
    +"<hr/>"
    +st
    +"</div>"//close reply menu
    +"</div>"//close postRich

    return rlt;
}
function stringText(lk,dk,st,aff)
{  
    var rlt = "<div class='postRich'>"//op postRich
    +"<div class='postReplies ui-widget-content ui-corner-all'>"//op reply menu                  
    +"<div><span class='ctlk'>"+lk+"</span> like, <span class='ctdk'>"+dk+"</span> dislike. affinity:"+aff+"</div>"
    +"<hr/>"
    +st
    +"</div>"//close reply menu;
    +"</div>"//close postRich
    return rlt;
}

            
/******************************************************************************************/            
/*********************************Le incone sui post **************************************/
/******************************************************************************************/
function addPostIcons(id)
{ 
    var targ ="#"+ id;
  
    $(targ).append(
        //close icon
        "<span class='ui-icon ui-icon-close icoClose' />"
        //lampadina icon
        + "<span class='ui-icon ui-icon-lightbulb icoTools' title='ToolsBar' />"
        //commenti icon
        + "<span class='ui-icon ui-icon-comment icoComment' title='View Comments' />"
                    
        +"<div class='ui-state-default postBar'>"
        +"<span class='ui-icon ui-icon-plus icoLike' title='like' ></span>"
        +"<span class='ui-icon ui-icon-minus icoDislike' title='dislike' ></span>"
        +"<span class='ui-icon ui-icon-mail-closed icoReply' title='reply' ></span>"
        +"<span class='ui-icon ui-icon-signal-diag icoFollow' title='follow' ></span>"
        +"</div>"//close post bar
        );

    if( $(targ).attr("title")=="video")
        $(targ).append("<span class='ui-icon ui-icon-video icoEnlarge' title='video' />");
    else if( $(targ).attr("title")=="image")
        $(targ).append("<span class='ui-icon ui-icon-image icoEnlarge' title='image' />");
    else if( $(targ).attr("title")=="audio")
        $(targ).append("<span class='ui-icon ui-icon-volume-on icoEnlarge' title='audio' />");
    if( $(targ).hasClass("like"))
    {
        $(targ).find(".icoLike").hide();
        $(targ).find(".icoDislike").attr("title","neutral");
    }
      
    else if( $(targ).hasClass("dislike"))
    {
        $(targ).find(".icoDislike").hide();
        $(targ).find(".icoLike").attr("title","neutral");
    }
       
}
            
/******************************************************************************************/            
/******************************Le funzioni sui post ***************************************/
/******************************************************************************************/
function addPostFun(id)
{
    var targ ="#"+ id;
    $(targ).draggable({
        containment: "#container",
        scroll: true ,
        stop: function() {            
            var y = $(this).css("top");
            y =  Math.floor(y.substring(0,y.length-2));
            var x = $(this).css("left");
            x =  Math.floor(x.substring(0,x.length-2));
            if(x<"65" && y>"600")
            {
                $(this).fadeOut("slow",function(){
                    $(this).remove();
                });
            }
        }
    });
                          
    /**click post*/
    $(targ).click(function() {  
        $(".postdiv").removeClass("postFade");
        $(".postdiv").addClass("postFade");
        $(this).removeClass("postFade");
        zindex++;
        $(this).css("z-index", zindex);
    });     

    $(targ).bind("dblclick",function(e){
        if(!$(e.target).hasClass("midterm"))
        {
            var p = $(this);
            resizePost(p,"dc");
        } 
    });
    $(targ).find(".icoClose").bind("click",function(){
        options = {
            to: {
                width: 200, 
                height: 60
            }
        };
        $(this).parent().hide( "fold", options, 1000);
    });
    $(targ).find(".icoTools").bind("click",function(){
        var p =  $(this).parent().find(".postBar");
        if(p.is(":visible"))
            p.hide("slow");
        else
            p.show("slow");
    });
    $(targ).find(".icoEnlarge").bind("click",function(){
        var p = $(this).parent();
        resizePost(p,"ic");
    });

    /**click post toolbar icons**/
    $(targ).find(".icoLike").bind("click",function(){
        if(myName!=null)
        {
            var toolbar = $(this).parent();
            var post = toolbar.parent();
            var about = post.find(".postAbout").text(); 
        
            if(post.hasClass("dislike"))//manda neutro
            {
                callSetLike(post,"like",about,"0");
            }        
            else//manda like
            {
                callSetLike(post,"like",about,"1");     
            }
            
        }
        else{
            $( "#dialogLogin" ).dialog( "open" );
        }
    });
    $(targ).find(".icoDislike").bind("click",function(){      
        if(myName!=null)
        {
            var toolbar = $(this).parent();
            var post = toolbar.parent();
            var about = post.find(".postAbout").text(); 
        
            if(post.hasClass("like"))//mando neotro
            {
                callSetLike(post,"dislike",about,"0");
            }   
            else
            {    
                callSetLike(post,"dislike",about,"-1");
            }
            
        }
        else{
            $( "#dialogLogin" ).dialog( "open" );
        }
    });
    $(targ).find(".icoReply").bind("click",function(){
        if(myName!=null)
        {
            var toolbar = $(this).parent();
            var post = toolbar.parent();
            var about = post.find(".postAbout").text(); 
            post_cache =  about;
            $( "#dialogSpam" ).dialog( "open" );
        }
        else{
            $( "#dialogLogin" ).dialog( "open" );
        }
    });
    $(targ).find(".icoFollow").bind("click",function(){
        if(myName!=null)
        {
            var toolbar = $(this).parent();
            var post = toolbar.parent();
            var about = post.find(".postAbout").text(); 
            var abtArray=about.split("/");
             
            var canFollow=true;
            $(".ls_flw").find(".user").each(function(){
                if($(this).text()==abtArray[1]+"/"+abtArray[2])
                {
                    canFollow=false;
                    alert("Already in your following list :)");
                }
            });   
            if(abtArray[1]+"/"+abtArray[2]==  myServerChoice+ myName )
            {
                canFollow=false;
                alert("you can't follow yourself :)");
            }
                
            if(canFollow)
                callSetFollow(abtArray[1],abtArray[2],"1");
               
        }
        else{
            $( "#dialogLogin" ).dialog( "open" );
        }
        
    });
    $(targ).find(".icoComment").bind("click",function(){
        var post = $(this).parent();  
        var rpl = post.find(".postReplies");
        if(rpl.is(":visible"))
            rpl.hide("blind","slow");
        else
            rpl.show("blind","slow");
    });
    $(targ).find(".postReplies").bind("mouseover",function(){
        var rich = $(this).parent();
        var root =rich.parent();
        root.draggable("disable");

    });
    $(targ).find(".postReplies").bind("mouseout",function(){
        var rich = $(this).parent();
        var root =rich.parent();
        root.draggable("enable");
    });          
    $(targ).find(".linkpost").bind("dblclick",function(){
        var link = $(this).text();
        var url = myServerUrl+'post'+link;
        callSearchThePost(url,"get");
    });   
    var orig = $(targ).find(".postTxt").text();
    var modif = toPostText(orig);
    $(targ).find(".postTxt").html(modif);
    $(targ).find(".midterm").bind("dblclick",function(){
        var  url = myServerUrl+'search/'+15+'/related/'+$(this).text();
        callSearchPosts(url);
    });
    
}
/************************************************************************/
/***********************Fun & Utilities**********************************/
/************************************************************************/


/*
     * allarga e ristringi il post
     * @param p riferimento al post
     */
function resizePost(p,daDove)
{
    p.find(".postBar").hide("slow");
    var passvideo = true; 
    if(p.attr('title')=='video'&&daDove=="dc")
        passvideo = false;
    //allarga
    if(!p.hasClass("boderShow") && passvideo)
    {
            
        p.animate({              
            width: '310px',
            height: '273px'
        }, 1000, function() {
            p.addClass("ui-corner-all");
            p.addClass("boderShow");
            p.find(".postUser").css({
                'font-size':'17px',
                "font-family":"sans-serif"
            });
            p.find(".postDate").show();
            p.css("overflow","visible");
            p.find(".postRich").show();
            if(p.attr("title")=="video"||p.attr("title")=="image")
            {
               
                p.find(".postTxt").hide();
                
            }
               
            else
                p.find(".postTxt").css({
                    "font-size":"20px",
                    "margin-top":"5px"
                });
                
            p.find(".icoComment").show();
        });
                      
    }
    else//restringi
        p.animate({              
            width: '130px',
            height: '50px'
        }, 1000, function() {
            // Animation complete.
            p.removeClass("ui-corner-all");
            p.removeClass("boderShow");
            p.find(".postUser").css({
                "font-size":"12px",
                "font-family":"cursive"
            });
            p.find(".postDate").hide();
            p.find(".postTxt").show();
            p.find(".postRich").hide();
            //if(p.attr("title")=="video"||p.attr("title")=="image"||p.attr("title")=="audio")
            //{
            p.css("overflow","hidden");
                
            //}
            p.find(".postTxt").css({
                "font-size":"13px",
                "margin-top":"-20px"
            });
               
            p.find(".icoComment").hide();
        }); 
   
}
/**
     *i id intero del post
     */
function calcolaMidPostPosition(i)
{
   
    if(countTmp >= ref)
    {
        dia += incrementoDidia; 
        countTmp=0;
        ref *= 2;
        if(dia>=240)
            dia =240;
    }
    countTmp++;
    //caclolo dei operatori
    var op1 = "";
    var op2 = "";
    i %=4;
    switch(i)
    {
        case 1:
           
            op1 = "-";
            
            break;
        case 2:
            op2 = "-";
            break;
        case 3: {
            
            op1 = "-";
            op2 = "-"
        }
        break;
    }
    
    //calcolo delle coordinate
    var x = Math.floor(Math.random()*dia);
    var y = Math.floor(Math.sqrt(Math.pow(dia,2)-Math.pow(x,2)));
                
    //formula la risposta
    var ofst = op1+x+ " "+op2+y;
    
    return ofst;
}


//convertire l'url youtube all'url video
/**
     *@author Enrico
     *modificato da Tong
     */
function urlToV(u)
{
    var rlt = "url not compatible";  
    rlt = u.replace("/watch?v=","/embed/");
    return rlt;
}
function getTypeFromUrl(url)
{
    var type = "text";
    if(url!=""){
        var ld = url.lastIndexOf(".");
        var tipo = url.substring(ld+1, url.length);
        tipo = tipo.toUpperCase();
        if(tipo=="JPG" || tipo=="JPEG" || tipo=="GIF" ||tipo=="PNG"||tipo=="BMP")
            type = "image";
        else if(tipo=="MP3" || tipo=="WAV" || tipo=="WMA"|| tipo=="MID"|| tipo=="AU")
            type = "audio";
        else if(url.indexOf("www.youtube.com") != -1)
            type = "video";
    }    
    return type;
}
function getTypeUrl(article)
{
    var tu=new Array(); 
    tu[0]="text";       
    tu[1]="";
    
    var sary= article.find('span');                    
    var i,  url;
    for(i=0;i<sary.length;i++){
        var tmp = sary[i];
        if($(tmp).attr("resource") == "video")
        {                     
            url =$(tmp).attr("src");
            tu[0]="video";       
            tu[1]=url;
            break;
                        
        }
        else if($(tmp).attr("resource") == "image")
        {
            url =$(tmp).attr("src");
            tu[0]="image";       
            tu[1]=url;
            break;
                        
        }
        else if($(tmp).attr("resource") == "audio")
        {
           
            url =$(tmp).attr("src");
            tu[0]="audio";       
            tu[1]=url;
            break;
                        
        }
    }
    //in caso del post mal formattato, torna tutto in default
    if(tu[1]==undefined)
    {
        tu[0]="text";       
        tu[1]="";
    }
    return tu;
}
function getAssoc(article)
{
    var myop = 0;
    var likes = 0;
    var dislikes = 0;
    var rps = "";
    var rpof ="";
    var rsof ="";
    if(article != "")
        article.find('span').each(function(){
            if($(this).attr("resource") == "/"+myServerChoice+myName)
            {
                if($(this).attr("rev") == "tweb:like")
                    myop=1;
                else if($(this).attr("rev") == "tweb:dislike")
                    myop=-1;
            }           
            else if($(this).attr("property")=="tweb:countLike")
                likes=$(this).attr("content");
            else if($(this).attr("property")=="tweb:countDisLike")
                dislikes=$(this).attr("content");
            else if($(this).attr("rel")=="sioc:has_reply")
                rps +=";<span class='linkpost'>" +$(this).attr("resource")+"</span> has replied.";
            else if($(this).attr("rel")=="sioc:reply_of")
                rpof =";this post is reply of : <span class='linkpost'>" +$(this).attr("resource")+"</span>";
            else if($(this).attr("rel")=="tweb:respamOf")
                rsof +=";this post is respam of : <span class='linkpost'>" +$(this).attr("resource")+"</span>";
        });
    var rlt = myop+";"+likes+";"+dislikes+rpof+rsof+rps;
    return rlt;
}

/******memento******/
function Ppost(countpposts,name,date,msg,type,url,asso,affinity)                
{
    this.count = countpposts;
    this.name = name;
    this.date = date;
    this.msg=msg;
    this.type=type;
    this.url=url;
    this.asso=asso;
    this.aff=affinity;
}
function setLikeLocale(post)
{
    if(post.hasClass("dislike"))//manda neutro
    {
        post.removeClass("dislike");
        post.find(".icoDislike").show();
        post.find(".icoDislike").attr("title","dislike");
        var ndl2 = parseInt(post.find(".ctdk").text())-1;              
        post.find(".ctdk").text(ndl2);
        post.find(".icoLike").attr("title","like");
    }        
    else//manda like
    {
        post.find(".icoDislike").attr("title","neutral");
        var ndl1 = parseInt(post.find(".ctlk").text())+1;              
        post.find(".ctlk").text(ndl1);
        post.addClass("like");
        post.find(".icoLike").hide();
                    
    }
}
function setDislikeLocale(post)
{
    if(post.hasClass("like"))//mando neutro
    {
        post.removeClass("like");
        post.find(".icoLike").show();
        post.find(".icoLike").attr("title","like");
        $(this).attr("title","dislike");
        var ndd2 = parseInt(post.find(".ctlk").text())-1;              
        post.find(".ctlk").text(ndd2);
        post.find(".icoDislike").attr("title","dislike");
    }   
    else
    {
        post.find(".icoLike").attr("title","neutral");
        var ndd1 = parseInt(post.find(".ctdk").text())+1;              
        post.find(".ctdk").text(ndd1);
        post.addClass("dislike");
        post.find(".icoDislike").hide();         
    }
            
}
//arrichimento del contenuto del post
function toPostText(text)
{
    var rlt ="";
    if(text != null && text != undefined)
    {
        var splited = text.split("#");
        // rlt = hashsplited[0];
        var i = 0;
        for(i;i<splited.length;i++)
        {
            if(i == 0)      
                rlt = splited[i];
            else{
                if($.trim(splited[i]) != "")
                    rlt += " #<span class='midterm'>"+ arricString(splited[i]);
                else
                    rlt += "#";
                   
            }
        }
    }
    return rlt;
}
function arricString(s)
{
    var trovato=false;
    var rlt = "";
    s = s.replace(/\n/g," ");
    var spltd = s.split(" ");    
    var j = 0;
    var temp;
    for(j=0;j<spltd.length;j++)
    {
        temp=spltd[j];
        if(trovato)
        {
            rlt +=" " + temp;
        }     
        if(temp != "" && !trovato)
        {
            
            trovato = true;
            rlt = temp+"</span>";
        }                   
    }
    return rlt;
}