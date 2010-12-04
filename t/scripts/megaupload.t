use strict;
use warnings;
no  warnings qw(once redefine);
use Test::More;
use Test::Deep qw(cmp_deeply str methods);
use Data::Section::Simple qw(get_data_section);
use Coro;

use Warg::Interface::Code;
use Warg::Downloader;
use Warg::Mech;

our $next_response;

sub next_response ($) { $next_response = $_[0] }

*LWP::UserAgent::simple_request = sub {
    my ($self, $request, $content_cb) = @_;

    $request = $self->prepare_request($request);

    note '[MockLWP] ' . $request->method . ' ' . $request->uri;

    my $data = get_data_section($next_response);

    require HTTP::Response;

    my $res = HTTP::Response->parse($data);
    $res->request($request);

    foreach my $h ($self->handlers('response_data', $res)) {
        $h->{callback}->($res, $self, $h, $res->content);
    }

    if (ref $content_cb eq 'CODE') {
        $content_cb->($res->content, $res, undef); # XXX no protocol
    }

    $self->run_handlers(response_done => $res);

    return $res;
};

my $mech = Warg::Mech->new;
$mech->add_handler(
    request_preprepare => sub { cede },
);

my $interface = Warg::Interface::Code->new(
    say => sub { shift; note @_ },
    ask => sub { shift; note @_; return 'RSX2' }
);

my $downloader = Warg::Downloader->from_script(
    'scripts/megaupload.pl', (
        interface => $interface,
        log_level => 'emerg',
        mech      => $mech,
    )
);
isa_ok $downloader, 'Warg::Downloader';

next_response 'RESPONSE #1';

$downloader->work_sync('http://www.megaupload.com/?d=PLI3TEGV');

cede; # resume working; go GET http://www.megaupload.com/?d=PLI3TEGV

cmp_deeply $downloader->mech->response, methods(
    base => str 'http://www.megaupload.com/?d=PLI3TEGV'
), '$downloader->mech->response';
is $downloader->filename, 'lena.tif', '$downloader->filename';

# TODO test captcha

done_testing;

__DATA__

@@ REQUEST #1
GET http://www.megaupload.com/?d=PLI3TEGV
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8
Accept-Encoding: identity
User-Agent: Mozilla/5.0 (Windows; U; Windows NT 6.1; ja; rv:1.9.2.6) Gecko/20100625 Firefox/3.6.6


@@ RESPONSE #1
HTTP/1.1 200 OK
Cache-Control: no-store, no-cache, must-revalidate
Cache-Control: post-check=0, pre-check=0
Connection: close
Date: Sat, 04 Dec 2010 17:15:57 GMT
Pragma: no-cache
Server: Apache
Vary: Accept-Encoding
Content-Type: text/html; charset=UTF-8
Expires: Sat, 4 Dec 2010 17:15:57 GMT
Last-Modified: Sat, 4 Dec 2010 17:15:57 GMT
Client-Date: Sat, 04 Dec 2010 17:16:37 GMT
Client-Peer: 174.140.154.20:80
Client-Response-Num: 1
Client-Transfer-Encoding: chunked
Link: <css/style.css.php?lang=en>; /="/"; rel="stylesheet"; type="text/css"
Link: <css/b_pages.css>; /="/"; rel="stylesheet"; type="text/css"
Link: <css/download.css.php?lang=en>; /="/"; rel="stylesheet"; type="text/css"
Link: <http://wwwstatic.megaupload.com/images/icon.ico>; rel="icon"; type="image/x-icon"
Link: <http://wwwstatic.megaupload.com/images/icon.ico>; rel="shortcut icon"; type="image/x-icon"
Title: MEGAUPLOAD - The leading online storage and file delivery service
X-UA-Compatible: IE=EmulateIE8

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="X-UA-Compatible" content="IE=EmulateIE8" /> 
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<title>MEGAUPLOAD - The leading online storage and file delivery service</title>
<link rel="stylesheet" type="text/css" href="css/style.css.php?lang=en" />
<link rel="stylesheet" type="text/css" href="css/b_pages.css" />
<link rel="stylesheet" type="text/css" href="css/download.css.php?lang=en" />
<link rel="icon" href="http://wwwstatic.megaupload.com/images/icon.ico" type="image/x-icon">
<link rel="shortcut icon" href="http://wwwstatic.megaupload.com/images/icon.ico" type="image/x-icon">
<script type="text/javascript" src="http://wwwstatic.megaupload.com/js/onhover.js" ></script>
<script type="text/javascript" src="http://wwwstatic.megaupload.com/js/preload.js" ></script>
<script type="text/javascript" src="http://wwwstatic.megaupload.com/js/swfobject2.js"></script>
<script type="text/javascript" src="http://wwwstatic.megaupload.com/js/jquery-1.4.2.min.js"></script>
<script type="text/javascript" src="http://wwwstatic.megaupload.com/js/lang.js"></script>
<script type="text/javascript"> 

function startpreload()
{      


langImages['en']=new Array();
langImages['en']['top']=newImage("http://wwwstatic.megaupload.com/images/lang/en_a.gif");
langImages['en']['middle']=newImage("http://wwwstatic.megaupload.com/images/lang/en.png");			langImages['ru']=new Array();
langImages['ru']['top']=newImage("http://wwwstatic.megaupload.com/images/lang/ru_a.gif");
langImages['ru']['middle']=newImage("http://wwwstatic.megaupload.com/images/lang/ru.png");			langImages['cn']=new Array();
langImages['cn']['top']=newImage("http://wwwstatic.megaupload.com/images/lang/cn_a.gif");
langImages['cn']['middle']=newImage("http://wwwstatic.megaupload.com/images/lang/cn.png");			langImages['ct']=new Array();
langImages['ct']['top']=newImage("http://wwwstatic.megaupload.com/images/lang/ct_a.gif");
langImages['ct']['middle']=newImage("http://wwwstatic.megaupload.com/images/lang/ct.png");			langImages['de']=new Array();
langImages['de']['top']=newImage("http://wwwstatic.megaupload.com/images/lang/de_a.gif");
langImages['de']['middle']=newImage("http://wwwstatic.megaupload.com/images/lang/de.png");			langImages['dk']=new Array();
langImages['dk']['top']=newImage("http://wwwstatic.megaupload.com/images/lang/dk_a.gif");
langImages['dk']['middle']=newImage("http://wwwstatic.megaupload.com/images/lang/dk.png");			langImages['es']=new Array();
langImages['es']['top']=newImage("http://wwwstatic.megaupload.com/images/lang/es_a.gif");
langImages['es']['middle']=newImage("http://wwwstatic.megaupload.com/images/lang/es.png");			langImages['fi']=new Array();
langImages['fi']['top']=newImage("http://wwwstatic.megaupload.com/images/lang/fi_a.gif");
langImages['fi']['middle']=newImage("http://wwwstatic.megaupload.com/images/lang/fi.png");			langImages['fr']=new Array();
langImages['fr']['top']=newImage("http://wwwstatic.megaupload.com/images/lang/fr_a.gif");
langImages['fr']['middle']=newImage("http://wwwstatic.megaupload.com/images/lang/fr.png");			langImages['it']=new Array();
langImages['it']['top']=newImage("http://wwwstatic.megaupload.com/images/lang/it_a.gif");
langImages['it']['middle']=newImage("http://wwwstatic.megaupload.com/images/lang/it.png");			langImages['jp']=new Array();
langImages['jp']['top']=newImage("http://wwwstatic.megaupload.com/images/lang/jp_a.gif");
langImages['jp']['middle']=newImage("http://wwwstatic.megaupload.com/images/lang/jp.png");			langImages['kr']=new Array();
langImages['kr']['top']=newImage("http://wwwstatic.megaupload.com/images/lang/kr_a.gif");
langImages['kr']['middle']=newImage("http://wwwstatic.megaupload.com/images/lang/kr.png");			langImages['nl']=new Array();
langImages['nl']['top']=newImage("http://wwwstatic.megaupload.com/images/lang/nl_a.gif");
langImages['nl']['middle']=newImage("http://wwwstatic.megaupload.com/images/lang/nl.png");			langImages['pt']=new Array();
langImages['pt']['top']=newImage("http://wwwstatic.megaupload.com/images/lang/pt_a.gif");
langImages['pt']['middle']=newImage("http://wwwstatic.megaupload.com/images/lang/pt.png");			langImages['sa']=new Array();
langImages['sa']['top']=newImage("http://wwwstatic.megaupload.com/images/lang/sa_a.gif");
langImages['sa']['middle']=newImage("http://wwwstatic.megaupload.com/images/lang/sa.png");			langImages['se']=new Array();
langImages['se']['top']=newImage("http://wwwstatic.megaupload.com/images/lang/se_a.gif");
langImages['se']['middle']=newImage("http://wwwstatic.megaupload.com/images/lang/se.png");			langImages['tr']=new Array();
langImages['tr']['top']=newImage("http://wwwstatic.megaupload.com/images/lang/tr_a.gif");
langImages['tr']['middle']=newImage("http://wwwstatic.megaupload.com/images/lang/tr.png");			langImages['vn']=new Array();
langImages['vn']['top']=newImage("http://wwwstatic.megaupload.com/images/lang/vn_a.gif");
langImages['vn']['middle']=newImage("http://wwwstatic.megaupload.com/images/lang/vn.png");			langImages['pl']=new Array();
langImages['pl']['top']=newImage("http://wwwstatic.megaupload.com/images/lang/pl_a.gif");
langImages['pl']['middle']=newImage("http://wwwstatic.megaupload.com/images/lang/pl.png");

document.getElementById('langSelectionSP').style.display='';

	preloadimages(
"http://wwwstatic.megaupload.com/images/en/but_dnld_premium_o.gif",
"http://wwwstatic.megaupload.com/images/en/but_dnld_premium.gif",
"http://wwwstatic.megaupload.com/images/en/but_dnld_regular_o.gif",
"http://wwwstatic.megaupload.com/images/en/but_dnld_regular.gif",
"images/en/down_button1o.gif",
"images/en/down_button1.gif",
"http://wwwstatic.megaupload.com/images/en/down_button2o.gif",
"http://wwwstatic.megaupload.com/images/en/down_button2.gif",
"http://wwwstatic.megaupload.com/images/en/down_button3o.gif",
"http://wwwstatic.megaupload.com/images/en/down_button3.gif",
"http://wwwstatic.megaupload.com/images/en/menu_01.gif",
"http://wwwstatic.megaupload.com/images/en/menuo_01.gif",
"http://wwwstatic.megaupload.com/images/en/menu_01b.gif",
"http://wwwstatic.megaupload.com/images/en/menuo_01b.gif",
"http://wwwstatic.megaupload.com/images/en/menu_02.gif",
"http://wwwstatic.megaupload.com/images/en/menuo_02.gif",
"http://wwwstatic.megaupload.com/images/en/menu_03.gif",
"http://wwwstatic.megaupload.com/images/en/menuo_03.gif",
"http://wwwstatic.megaupload.com/images/en/menu_04.gif",
"http://wwwstatic.megaupload.com/images/en/menuo_04.gif",
"http://wwwstatic.megaupload.com/images/en/menu_05.gif",
"http://wwwstatic.megaupload.com/images/en/menuo_05.gif",
"http://wwwstatic.megaupload.com/images/en/menu_06.gif",
"http://wwwstatic.megaupload.com/images/en/menuo_06.gif",
"http://wwwstatic.megaupload.com/images/en/menu_07.gif",
"http://wwwstatic.megaupload.com/images/en/menuo_07.gif",
"http://wwwstatic.megaupload.com/images/en/b_menu_01.png",
"http://wwwstatic.megaupload.com/images/en/b_menu_02.png",
"http://wwwstatic.megaupload.com/images/en/b_menu_03.png",
"http://wwwstatic.megaupload.com/images/en/b_menu_04.png",
"http://wwwstatic.megaupload.com/images/en/b_menu_05.png",
"http://wwwstatic.megaupload.com/images/en/b_menuo_01.png",
"http://wwwstatic.megaupload.com/images/en/b_menuo_02.png",
"http://wwwstatic.megaupload.com/images/en/b_menuo_03.png",
"http://wwwstatic.megaupload.com/images/en/b_menuo_04.png",
"http://wwwstatic.megaupload.com/images/en/b_menuo_05.png"
	);

}
</script>


<script type="text/javascript">
var gaJsHost = (("https:" == document.location.protocol) ? "https://ssl." : "http://www.");
document.write(unescape("%3Cscript src='" + gaJsHost + "google-analytics.com/ga.js' type='text/javascript'%3E%3C/script%3E"));
</script>
<script type="text/javascript">
try {
var pageTracker = _gat._getTracker("UA-6383685-1");
pageTracker._trackPageview();
} catch(err) {}</script>



</head>





<body class="color3 bottoms download">
<table width="100%" border="0" cellspacing="0" cellpadding="0">
  <tr>
    <td align="left" valign="top" >&nbsp;</td>
    <td width="987" height="79" align="center" valign="top" >
    
    <div class="top_nw_block">
    
    <div class="head_div">  
      
        <script type="text/javascript">


function signout()
{
  document.getElementById('logoutfrm').submit();
}



function urlencode(str) 
{
  return escape(str).replace('+', '%2B').replace('%20', '+').replace('*', '%2A').replace('/', '%2F').replace('@', '%40');
}

function urldecode(str) 
{
  return unescape(str.replace('+', ' '));
}

 
function xClientWidth()
{
  var v=0,d=document,w=window;
  if((!d.compatMode || d.compatMode == 'CSS1Compat') && !w.opera && d.documentElement && d.documentElement.clientWidth)
    {v=d.documentElement.clientWidth;}
  else if(d.body && d.body.clientWidth)
    {v=d.body.clientWidth;}
  else if(xDef(w.innerWidth,w.innerHeight,d.height)) {
    v=w.innerWidth;
    if(d.height>w.innerHeight) v-=16;
  }
  return v;
}
 
function xClientHeight()
{
  var v=0,d=document,w=window;
  if((!d.compatMode || d.compatMode == 'CSS1Compat') && d.documentElement && d.documentElement.clientHeight)
    {v=d.documentElement.clientHeight;}
  else if(d.body && d.body.clientHeight)
    {v=d.body.clientHeight;}
  else if(xDef(w.innerWidth,w.innerHeight,d.width)) {
    v=w.innerHeight;
    if(d.width>w.innerWidth) v-=16;
  }
  return v;
}


function swfIn(id)            
{

	document.getElementById(id).height = 400;

}
function swfOut(id)            
{
	document.getElementById(id).height = 30;
}


function newImage(src) {
	var res = new Image();
	res.src = src;
	return res;
}
var langImages=new Array();

</script>


<div class="logo"><a href="/"><img src="http://wwwstatic.megaupload.com/images/logo.gif" alt="Megaupload" border="0" /></a></div>

<div class="lang_div" style="width:166px; height:32px;"><a id="langSelectionSP" class="lng_en_a" onclick="langSelection.turn()" style="display:none;"></a></div>



	  


<div id="top_user_info" class="top_usr_nw_fr">


<div id="topswf"></div> 

<div style="display:none; padding-right:10px; padding-top:1px;" id="topnonflash">
<TABLE>
<TR>
	<TD><a href="?c=login" style="text-decoration:none;">Login</a></TD>
	<TD width="12" align="center">-</TD>
	<TD><a href="?c=signup"  style="text-decoration:none;">Register</a></TD>
</TR>
</TABLE>
</div>


<script type="text/javascript">

if (hasFlash)
{
	var flashvars = {};	   
	
		flashvars.logintxt = "Login";
	flashvars.registertxt = "Register";
		flashvars.useSystemFont = "0";
	flashvars.size = "17";
	flashvars.loginAct = "?c=login%26next%3Dd%253DPLI3TEGV";
	flashvars.registerAct = "?c=signup";
	flashvars.userAct = "?c=account";
	flashvars.signoutAct = "javascript:signout();";
	flashvars.myaccounttxt = "My Account";
	flashvars.accountAct = "?c=account";
	
	var params = {};
	flashvars.id = "topswf";
	params.wmode = "transparent";
	params.allowscriptaccess = "always";
	
	swfobject.embedSWF("http://wwwstatic.megaupload.com/flash/mu_top.swf", "topswf", "494", "29", "0", false, flashvars, params);
	
}
else
{
  document.getElementById('topnonflash').style.display='';
}





</script>
<FORM method="POST" id="logoutfrm"><input type="hidden" name="logout" value="1"></FORM>


</div>
                
       <div class="clear"></div>
    </div>     
       
    
    <div class="menu_div">    
     
<div class="forms_div2"><a href="?c=signup" class="butt_1_fr"></a></div><div class="forms_div2"><a href="?c=premium" class="butt_2"></a></div>
<div class="forms_div2"><a href="?c=rewards" class="butt_3"></a></div>
<div class="forms_div2"><a href="?c=top100" class="butt_4"></a></div>
<div class="forms_div2"><a href="?c=tools" class="butt_5"></a></div>
<div class="forms_div2"><a href="?c=support" class="butt_6"></a></div>
<div class="forms_div2"><a href="?c=faq" class="butt_7"></a></div>

     <div class="clear" >    </div> 
    </div>    
    </div>    </td>
    <td align="left" valign="top" >&nbsp; </td>
  </tr>
  <tr>
    <td align="left" valign="top" class="black_l_bg1"><div class="black_l_bg2"></div></td>
    <td align="left" valign="top">
     
     <div class="rew_main_bg1">
      <div class="rew_main_bg2">
       <div class="rew_main_bg3">
        <div class="rew_main_bg4">
		         
           <div class="down_top_bl1">
		  
            <div class="down_txt_pad1">
             <span class="down_txt1">File name:</span> <span class="down_txt2">lena.tif</span><br />
             <strong>File description:</strong> lena.tif<br />
             <strong>File size:</strong> 768.14 KB<br />

			             </div>
            
            <div class="down_txt_pad2">
             <span class="down_txt3">Download link:</span> <a href="http://www.megaupload.com/?d=PLI3TEGV" class="down_txt2">http://www.megaupload.com/?d=PLI3TEGV</a>
            </div>
            
            <div class="clear"></div>
           
           </div>
		   
		   
           <div class="down_table_pad">
            <div class="down_table_tab"></div>
            <div class="down_table_bg">
            <div class="down_table_pad2">
            <table cellpadding="0" cellspacing="0">
             <tbody>
              <tr>
	           <td class="table_div_rb" width="332"><span class="prem_td_pad">High-speed download with <a href="http://static.megaupload.com/megamanager.exe" class="red_link" style="font-weight:bold;">Mega Manager</a></span></td>
	           <td class="table_div_rb" align="center" width="154" ><img src="http://wwwstatic.megaupload.com/images/prem_y.gif" alt="" border="0" width="18" height="18"></td>
	           <td class="table_div_b" align="center" width="153" ><img src="http://wwwstatic.megaupload.com/images/prem_n.gif" alt="" border="0" width="18" height="18"></td>
              </tr>
              <tr>
	           <td class="table_div_rb" ><span class="prem_td_pad">Download speed priority</span></td>
	           <td class="table_div_rb" align="center"><b>Highest</b></td>
	           <td class="table_div_b" align="center" >Lowest</td>
              </tr>
              <tr>
	           <td class="table_div_rb"><span class="prem_td_pad">Maximum parallel downloads</span></td>
	           <td class="table_div_rb" align="center"><b>Unlimited</b></td>
	           <td class="table_div_b" align="center">1</td>
              </tr>
              <tr>
	           <td class="table_div_rb"><span class="prem_td_pad">Download limit per 24 hours</span></td>
	           <td class="table_div_rb" align="center"><b>Unlimited</b></td>
	           <td class="table_div_b" align="center">Very limited</td>
              </tr>
              <tr>
	           <td class="table_div_rb"><span class="prem_td_pad">Advertising</span></td>
	           <td class="table_div_rb" align="center"><b>Little</b></td>
	           <td class="table_div_b" align="center">Maximum</td>
              </tr>
              <tr>
	           <td class="table_div_rb"><span class="prem_td_pad">Waiting time before each download begins</span></td>
	           <td align="center" class="table_div_rb"><strong>None</strong></td>
	           <td class="table_div_b" align="center">45 seconds</td>
              </tr>
              <tr>
	           <td class="table_div_r"><span class="prem_td_pad">Support for download accelerators</span></td>
	           <td class="table_div_rb" align="center" width="154" ><img src="http://wwwstatic.megaupload.com/images/prem_y.gif" alt="" border="0" width="18" height="18"></td>
	           <td class="table_div_b" align="center" width="153" ><img src="http://wwwstatic.megaupload.com/images/prem_n.gif" alt="" border="0" width="18" height="18"></td>
              </tr>
              <tr>
             </tbody>
            </table>
            </div>
            </div>
           </div>
		   
           <div class="down_butt_bg">
            <div class="down_butt_bg2">
              
			<div class="down_butt_pad1">
               <a href="?c=premium" class="down_butt2"></a>
              </div>

            </div>
            <div class="down_butt_bg3">

			<div class="down_butt_pad1" style="display:none;" id="downloadlink"><a href="http://www641.megaupload.com/files/bcd4b8bb243d6b67383659961e2d21b8/lena.tif" class="down_butt1"></a></div>

			  <div id="downloadcounter" style="padding-top:22px;">
			  <TABLE width="322" style="font-family;arial; font-size:12px;">
			  <TR>
				<TD align="center">Please wait</TD>
			  </TR>
			  <TR>
			 	<TD align="center" valign="middle" height="50" ><div id="countdown" style="font-size:24px; font-weight:bold; font-family:arial;">&nbsp;</div></TD>
			  </TR>
			  <TR>
			 	<TD align="center">seconds</TD>
			  </TR>
			  </TABLE>
			  </div>

			  <script type="text/javascript">
			  count=45; 				
			  function countdown() 
			  {
			  	if (count > 0)
				{
				  count--;
				  if(count == 0)
				  {
				    document.getElementById('downloadlink').style.display = '';
					document.getElementById('downloadcounter').style.display = 'none';
				  }
				  if(count > 0)
				  {
				    document.getElementById("countdown").innerHTML = count;
					setTimeout('countdown()',1000);
				  }
				}
			  }
			  countdown();
			  </script>
              
            </div>
           </div>
           <div class="clear"></div>
		   

		    
        </div>
       </div>
      </div>
     </div>
 
    </td>
    <td align="left" valign="top" class="black_r_bg1"><div class="black_r_bg2"></div></td>
  </tr>
  <tr>
   <td class="mn_bott_td1">&nbsp;</td>
   <td class="mn_bott_td2"> 
   
    <div class="mn_bott_bg1">
     <div class="mn_bott_bg2">
     
      <table width="100%" border="0" cellspacing="0" cellpadding="0">
       <tr>
        <td class="mn_bott_td3">
         <div class="foot_bg1"></div>        </td>
        <td class="mn_bott_td4">&nbsp;</td>
        <td class="mn_bott_td5">
         <div class="forms_div2"><a href="http://www.megaclick.com" target="_blank" class="f_butt_1"></a></div>
<div class="forms_div2"><a href="?c=abuse" class="f_butt_2"></a></div>
<div class="forms_div2"><a href="?c=contact" class="f_butt_3"></a></div>
<div class="forms_div2"><a href="?c=privacy" class="f_butt_4"></a></div>
<div class="forms_div2"><a href="?c=terms" class="f_butt_5"></a></div>


<iframe id="synchframe1" src="http://www.megavideo.com/?synch=becb92db068b52bdf6a7b6e12c5fe6f47a2de34a942887ca775e9161752b46b618baeb961d" style="position:absolute;left:-1000px;top:0px;visibility:hidden;"></iframe>
<iframe id="synchframe2" src="http://www.megalive.com/?synch=becb92db068b52bdf6a7b6e12c5fe6f47a2de34a942887ca775e9161752b46b618baeb961d" style="position:absolute;left:-1000px;top:0px;visibility:hidden;"></iframe>



        </td>
       </tr>
      </table>
     </div>
    </div>   </td>
   <td class="mn_bott_td6">&nbsp;</td>
  </tr>
</table>
<script type="text/javascript">
startpreload();
</script>

<script type="text/javascript" language="javascript1.2"><!--
EXs=screen;EXw=EXs.width;navigator.appName!="Netscape"?
EXb=EXs.colorDepth:EXb=EXs.pixelDepth;//-->
</script><script type="text/javascript"><!--
navigator.javaEnabled()==1?EXjv="y":EXjv="n";
EXd=document;EXw?"":EXw="na";EXb?"":EXb="na";
EXd.write("<img src=\"http://nht-2.extreme-dm.com",
"/n2.g?login=kimble&amp;pid=main&amp;",
"jv="+EXjv+"&amp;j=y&amp;srw="+EXw+"&amp;srb="+EXb+"&amp;",
"l="+escape(EXd.referrer)+"\" height=1 width=1>");//-->
</script><noscript><img height="1" width="1" alt=""
src="http://nht-2.extreme-dm.com/n2.g?login=kimble&amp;pid=main&amp;j=n&amp;jv=n"/>
</noscript>

</body>
</html>

