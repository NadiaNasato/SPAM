/* 
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */
$(function(){
    postSeverSemaphore = false;
    maxPostWords = 160;
    
    countmposts=1;//count numero di mposts
    countpposts=1;//count numero di pposts
    
    readppostContatore=0;//count numero di pposts periodicamente
    
    pposts=new Array();//cache di polling post
    post_cache=null;//cache dell' "about" del post
    
    cookieMyName="ltwlogin";
    cookieMyServ="ltwloginServer";    
    myName = $.cookie(cookieMyName);
    myServerChoice=$.cookie(cookieMyServ);    
    myServerUrl="/";
   
    /**********************************************************************************/
    /*************** BUTTONS of LOGIN AND HELP AddFollow Tesauri ******************/
    /*********************************************************************************/

    $("#login").button({
        icons: {
            primary: "ui-icon-locked"
        }
    });
    $("#login").bind("click",function(event){
        event.preventDefault();
        if($("#login").find(".ui-icon").hasClass("ui-icon-locked"))
        {
            $( "#dialogLogin" ).dialog( "open" );
        }   
        else
        {
            if($("#dialogAddFlw").dialog( "isOpen" ))
                $( "#dialogAddFlw" ).dialog( "close" );
            if($("#dialogAddTsr").dialog( "isOpen" ))
                $( "#dialogAddTsr" ).dialog( "close" );                 
            callLogout();
        }           
        return false;
    });
    $("#help").click(function() {    
        $( "#dialogHelp" ).dialog( "open" );
    } )
    $("#help").button({
        icons: {
            primary: "ui-icon-info"
        }
    });
    
    $("#addFlw").button({
        icons: {
            primary: "ui-icon-person"
        }
    });
    $("#addFlw").bind("click",function(event){
        event.preventDefault();
        $( "#dialogAddFlw" ).dialog( "open" );
    });
    $("#addTsr").button({
        icons: {
            primary: "ui-icon-tag"
        }
    });
    $("#addTsr").bind("click",function(event){
        event.preventDefault();
        $( "#dialogAddTsr" ).dialog( "open" );
    });
   
                
    /*********************************************************************/
    /*********************    Elementi Immagini    ***********************/
    /*********************************************************************/  

    $("#pin").bind("click",function(){
        if(myName!=null)
        {
            var lists = $("#accordion");
            if(lists.is(":visible"))
                lists.hide("blind","slow");
            else
                lists.show("blind","slow");
        }
        else{
            $( "#dialogLogin" ).dialog( "open" );
        }
        
    });
    $( "#envelope" ).hover(
        function () {
            $(this).attr("src", "images/envi1.png");
        }, 
        function () {
            $(this).attr("src", "images/envi2.png");
        }
        );
    $( "#envelope" ).droppable({
        accept: ".postdiv",
        activeClass:  "ui-state-active",
        drop: function( event, ui ) {
            options = {
                to: {
                    width: 200, 
                    height: 60
                }
            };
            ui.draggable.hide( "highlight", options, 1000);
            var about = ui.draggable.find(".postAbout").text(); 
            if(myName!=null)
            {
                callRespam(about);
            }
            else{
                $( "#dialogLogin" ).dialog( "open" );
            }         
        }
    });

    $("#envelope").click(function(){
        if(myName!=null)
        {
            $( "#dialogSpam" ).dialog( "open" );
        }
        else{
            $( "#dialogLogin" ).dialog( "open" );
        }
    });          
    $("#magnifier").bind("click",function(event){
        if(myName!=null)
        {
            event.preventDefault();
            $( "#dialogSearch" ).dialog( "open" );
        }
        else{
            $( "#dialogLogin" ).dialog( "open" );
        }
    });
    $("#magnifier").droppable({
        accept: ".postdiv",
        drop: function( event, ui ) {
            options = {
                to: {
                    width: 200, 
                    height: 60
                }
            };
            ui.draggable.hide( "highlight", options, 1000);
            var about = ui.draggable.find(".postAbout").text(); 
            if(myName!=null)
            {
                var abtArray=about.split("/");
                var aff = abtArray[1]+"/"+abtArray[2]+"/"+abtArray[3];
                var  url = myServerUrl+'search/'+10+'/affinity/'+aff;
                callSearchPosts(url);
            }
            else{
                $( "#dialogLogin" ).dialog( "open" );
            }         
        }
    });

    /**************************************************************/
    /*********   le liste Amici Server Tesauri   ******************/
    /**************************************************************/                
    $( "#accordion" ).accordion({   
        animated: 'bounceslide',
        fillSpace: true
       
    });                
    $("#tabs").tabs();

    /************************************************************************/
    /*************************** I  Dialog  *********************************/
    /************************************************************************/
    
    
    /**********************login***********************/
    $( "#dialogLogin" ).dialog({
        autoOpen: false,
        show: "blind",
        hide: "blind",
        width: "153",
        //minHeight: "221",
        draggable: false,
        resizable: false,
        position: [767,85],
        buttons: {
            "Ok": 
            function() {
                var name = $.trim($("#loginUser").val());
                if (name != "") {
                    if(isAllow(name)) 
                    {
                        myName = name;
                        myServerChoice=$("#loginServer").val()+"/";
                        if($("#loginServer").val() == "TangoWhiskey")
                            myServerUrl="/"+myServerChoice;
                    
                        callLogin(myName);
                        $("#loginUser").val("");
                        $( this ).dialog( "close" );  
                    }
                    else
                        alert("you can't login in that format");
                }
                else
                    alert("can login with username null");              
            },
            Cancel: function() {
                $( this ).dialog( "close" );
            }
        }
    });
    /*********************help********************/
    $( "#dialogHelp" ).dialog({
        autoOpen: false,
        width: "553",
        minHeight: "400",
        maxHeight: "400",
        show: "blind",
        hide: "blind"
    });
    $("#dialogHelp").tabs();
    /*********************search********************/
    /**
     * @author Enrico, modificato da Tong
     */
    $( "#dialogSearch" ).dialog({
        autoOpen: false,
        //minWidth: 390,
        width:400,
        modal:false,
        show: "blind",
        hide: "blind",
        buttons: {
            "OK": function() {
                var done = false;
                var numPost="all";
                var url =null;
                var choice = $("#radioForm input[type='radio']:checked").attr("id");
                var numChoice = $("#numPost input[type='radio']:checked").attr("id");
                if(numChoice != 'all')
                    numPost = $('#amount').val();
                if(choice == undefined)
                    alert("please make a choice");
                else{           
                    if(choice == 'autore'){
                        var autore = $.trim($("#oggetto").val());
                        var array = autore.split("/");
                        if(array.length==2&&autore.indexOf(" ")==-1)
                        {                            
                            if(array[0]!="" && array[1] !="")
                            {
                                url = myServerUrl+'search/'+numPost+'/author/'+autore;
                  
                                callSearchPosts(url);
                                done = true;
                            }    
                        } 
                    }
                    else if(choice == 'following'){
                        url = myServerUrl+'search/'+numPost+'/following';
          
                        callSearchPosts(url);
                        done = true;
                    }

                    else if(choice =='fulltext'){
                        var testo = $.trim($("#oggetto").val());
                        if(isAllow(testo))
                        {
                            testo = testo.replace(/ /g,"%20");
                            url = myServerUrl+'search/'+numPost+'/fulltext/'+testo;
              
                            callSearchPosts(url);
                            done = true;
                        }                      
                    }

                    else if(choice =='recent'){
                        var argomentor = $.trim($("#rsTag").val());
                        if(isAllow(argomentor))
                        {
                            url = myServerUrl+'search/'+numPost+'/recent/'+argomentor;
                       
                            callSearchPosts(url);
                            done = true;
                        }   
                    }
                    else if(choice =='related'){
                        
                        var argomentol = $.trim($("#rsTag").val());
                        if(isAllow(argomentol))
                        {
                            url = myServerUrl+'search/'+numPost+'/related/'+argomentol;
                            callSearchPosts(url);
                            done = true;
                        }
                        
                    }
                    else if(choice == 'affinity'){
                        var aff = $.trim($("#oggetto").val());
                        var array2 = aff.split("/");
                       
                        if(array2.length==3&&aff.indexOf(" ")==-1)
                        {                            
                            if(isAllow(array2[0])&&isAllow(array2[1])&&isAllow(array2[2]))
                            {
                                url = myServerUrl+'search/'+numPost+'/affinity/'+aff;
                                callSearchPosts(url);
                                done = true;
                            }    
                        }  
                       
                    }
                    if(done)
                    {
                        $("#oggetto").val("");
                        $("#rsTag").val("");
                        $(this).dialog('close');
                    }
                    else alert("Format not allowed");
                    
                }

                
            },//close ok
            Cancel: function() {
                $( this ).dialog( "close" );
            }
        },//close button
        close: function() {
        }
  
    });
    /******************new post******************/
    $( "#dialogSpam" ).dialog({
        autoOpen: false,
        // height: 800,
        width: 355,
        resizable: true,
        modal: true,
        show: "blind",
        hide: "blind",
        buttons: {
            "OK": function() {
                // Il testo semplice inserito dall'utente nella textarea
                var post = $.trim($("#npTextArea").val());
                if(post!="")
                {
                    post = readSpam(post);
                    //alert(post);
                    callNewPost(post);
                    $("#npTextArea").val("");
                    $("#npUrl").val("");
                    $( this ).dialog( "close" ); 
                }
                else
                    alert("You forgot to add some thoughts :)");
            },
            Cancel: function() {               
                $( this ).dialog( "close" );
            }
        },
        close: function() {
            post_cache=null;
        }
    });
    $("textarea").resizable({
        disabled: true
    });

    /*******add follow***********/
    $.get("server.xml", null, function (data) {
        $(data).find('servers server').each(function () {
            if($("#addFlwServer").find("option").attr("value") != $(this).attr('serverID').toString())
                $("#addFlwServer").append("<option value=\""+$(this).attr('serverID').toString()+"\">"+$(this).attr('serverID').toString()+"</option>");
        });
    });

    $( "#dialogAddFlw" ).dialog({
        autoOpen: false,
        show: "blind",
        hide: "blind",
        width: "153",
        draggable: true,
        resizable: false,
        position: [920,115],
        buttons: {
            "Ok": 
            function() {
                var name = $.trim($("#addFlwUser").val());
                if (name != "") {
                    var server=$("#addFlwServer").val();
                    var canFollow=true;
                    $(".ls_flw").find(".user").each(function(){
                        if($(this).text()==server+"/"+name)
                        {
                            canFollow=false;
                            alert("Already in your following list :)");
                        }
                    });     
                    if(server+"/"+name==  myServerChoice+ myName )
                    {
                        canFollow=false;
                        alert("You can't follow yourself, don't be a jerk :)");
                    }
                    if(!isAllow(name))
                    {
                        canFollow=false;
                        alert("Format not allowed");
                    }
                    if(canFollow)
                    {
                        callSetFollow(server,name, "1");
                        $("#addFlwUser").val("");
                        $( this ).dialog( "close" );  
                    }                 
                }
                else
                    alert("Please insert the nickname of a user :)");              
            },
            Cancel: function() {
                $( this ).dialog( "close" );
            }
        }
    });
    /*******add thesaurus***********/
    $( "#dialogAddTsr" ).dialog({
        autoOpen: false,
        show: "blind",
        hide: "blind",
        width: "153",
        draggable: true,
        resizable: false,
        position: [920,115],
        buttons: {
            "Ok": 
            function() {
                var fa = $.trim($("#addTsrPadre").val());
                var ch = $.trim($("#addTsrTerm").val());
                if (fa != ""&& ch!="") 
                {
                    // var esist = false;
                    var padreOK = false;
                    var figlioOK= true;
                    for (var j=0; j<categories.length; j++) {
                        //controllo se esiste padre ed e' aggiungibile
                        if (categories[j].term == fa && $("#"+fa+"").hasClass("tAddable")) 
                        {
                            
                            padreOK = true;
                        }    
                        if(categories[j].term == ch || !isAllow(ch))
                        {
                            figlioOK = false;
                        }                       
                    }                               
                    if(padreOK && figlioOK)
                    {
                        callAddTerm(fa,ch);   
                        $("#addTsrPadre").val("");
                        $("#addTsrTerm").val("");
                        $( this ).dialog( "close" );  
                    }          
                    else if(!padreOK)
                        alert("Father node not allowed");
                    else if(!figlioOK)
                        alert("The term is not allowed or maybe already in use");

                }
                else
                    alert("All fields are required :)");              
            },
            Cancel: function() {
                $( this ).dialog( "close" );
            }
        }
    });

    /*******ajax*****/
    $( "#dialogErrAjax" ).dialog({
        autoOpen: false,
        maxHeight: 450,       
        // width: "553",
        show: "blind",
        hide: "blind"
    });
    $( "#dialogSucAjax" ).dialog({
        autoOpen: false,
        show: "blind",
        hide: "blind"
    });
    $( "#dialogWait" ).dialog({
        autoOpen: false,
        show: "blind",
        hide: "blind"
    });
    
    /************************************************************************/
    /*************************** NewPostArea  *********************************/
    /************************************************************************/
    $("#npTextArea").bind("keydown",function(){
        var field = $(this);
        if (field.val().length > maxPostWords )
        {
            field.val(field.val().substring( 0, maxPostWords )); 
        }    

    });
    //    $("#npTextArea").bind("keypress",function(e){
    //        if(e.keyCode == 35) {//KEY '#'
    //            //e.preventDefault();
    //            $("#npTag").focus();
    //        }
    //    });
    $("#npTextArea").bind("keyup",function(){
        var field = $(this);
        if (field.val().length > maxPostWords  )
        {
            field.val(field.val().substring( 0, maxPostWords )); 
        }
    });
    
    $("#npTag").bind("keydown",function(e){
       
        //KEY ENTER
        if(e.keyCode == 13 && $('#npTag').val()!="" ) {
           
            useTag(e);
        }
    });
    $("#button_tag").bind("click", function(e) {
        useTag(e);
    });


    /*************************************************************************/
    /*******************login automatico in caso di avere i cookie************/
    /*************************************************************************/
    if( myName != null && myServerChoice!=null)
    {
        if(myServerChoice == "TangoWhiskey/")
            myServerUrl="/"+myServerChoice;
        callLogin( myName);  
    }
//  else
//  loginNotice = window.setInterval(function(){ $( "#login" ).effect( "bounce", {}, 200);}, 500);
    
//  alert("ciaooo");
       
}	
)
