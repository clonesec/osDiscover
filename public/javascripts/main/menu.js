var timeout         = 200;
var closetimer		= 0;
var ddmenuitem      = 0;
function ddm_open(){
	ddm_canceltimer();
	ddm_close();
	ddmenuitem = $(this).find('ul').eq(0).css('visibility', 'visible');
}
function ddm_close(){if(ddmenuitem) ddmenuitem.css('visibility', 'hidden');}

function ddm_timer(){closetimer = window.setTimeout(ddm_close, timeout);}

function ddm_canceltimer(){
	if(closetimer){
		window.clearTimeout(closetimer);
		closetimer = null;
	}
}
$(document).ready(function(){
	$('#ddm > li').bind('mouseover', ddm_open);
	$('#ddm > li').bind('mouseout',  ddm_timer);
	$(".no_menu_link").click(function(event){
		event.preventDefault();
	});
});
document.onclick = ddm_close;

