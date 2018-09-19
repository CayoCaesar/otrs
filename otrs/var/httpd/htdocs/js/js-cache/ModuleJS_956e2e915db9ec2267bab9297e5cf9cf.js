"use strict";var Core=Core||{};Core.Agent=Core.Agent||{};Core.Agent.Login=(function(TargetNS){TargetNS.Init=function(){var LoginFailed=Core.Config.Get('LoginFailed');if(!Core.Agent.SupportedBrowser){$('#LoginBox').hide();$('#OldBrowser').show();return;}
Core.Form.EnableForm($('#LoginBox form, #PasswordBox form'));if($('#User').val()&&$('#User').val().length){$('#Password').focus();}
else{$('#User').focus();}
$('#LostPassword, #BackToLogin').click(function(){$('#LoginBox, #PasswordBox').toggle();return false;});$('#TimeZoneOffset').val((new Date()).getTimezoneOffset());if(typeof LoginFailed!=='undefined'&&parseInt(LoginFailed,10)===1){Core.UI.Animate($('#LoginBox'),'Shake');}
if($('#LoginBox').hasClass('PreLogin')){$('#LoginBox form').submit();}
if(window.OTRSAdblockDisabled===undefined&&!localStorage.getItem("UserDontShowAdBlockWarning")&&!$('#LoginBox').hasClass('PreLogin')){$('#LoginBox')
.prepend('<div class="ErrorBox" style="display: none;"><span>'+Core.Language.Translate("Are you using a browser plugin like AdBlock or AdBlockPlus? This can cause several issues and we highly recommend you to add an exception for this domain.")+' <i class="fa fa-long-arrow-right"></i> <a href="#" id="HideAdBlockMessage">'+Core.Language.Translate("Do not show this warning again.")+'</a></span></div>')
.find('#HideAdBlockMessage')
.on('click',function(){localStorage.setItem('UserDontShowAdBlockWarning',1);$(this).closest('.ErrorBox').fadeOut('slow',function(){$(this).remove();});return false;})
.closest('.ErrorBox')
.fadeIn('slow');}
$('#LoginButton').click(function(){localStorage.removeItem('Availability');return true;});};Core.Init.RegisterNamespace(TargetNS,'APP_MODULE');return TargetNS;}(Core.Agent.Login||{}));

