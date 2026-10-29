// La clave publishable es pública. Nunca incluir claves secret/service_role aquí.
const PALABREO_SUPABASE_URL='https://nqtzfuaxmqulbqjdoznz.supabase.co';
const PALABREO_SUPABASE_KEY='sb_publishable_MmUT117n4Lx02W7VMXAHxw_t2CuKRpw';
function createAuthClient({fetchImpl=globalThis.fetch.bind(globalThis),storage,url=PALABREO_SUPABASE_URL,key=PALABREO_SUPABASE_KEY}={}){
 if(storage===undefined){try{storage=globalThis.localStorage;}catch{storage=null;}}
 const native=globalThis.PalabreoReminders;
 const sessionKey='palabreo-auth-v1';let session=null,refreshPromise=null;
 try{const saved=JSON.parse(storage?.getItem(sessionKey));if(saved&&typeof saved.access_token==='string'&&typeof saved.refresh_token==='string')session=saved;}catch{}
 try{if(native){const saved=JSON.parse(native.savedSession());if(saved?.access_token)session=saved;else if(session)native.saveSession(JSON.stringify(session));}}catch{}
 function remember(data,nativeWrite=true){session=data?.access_token?{access_token:data.access_token,refresh_token:data.refresh_token,expires_at:data.expires_at??Math.floor(Date.now()/1000)+(data.expires_in??3600),user:data.user}:null;try{if(session)storage?.setItem(sessionKey,JSON.stringify(session));else storage?.removeItem(sessionKey);}catch{}if(nativeWrite)try{native?.saveSession(JSON.stringify(session));}catch{}return session;}
 function errorText(data,status){
  const code=data?.error_code??data?.code;
  const known={invalid_credentials:'El correo o la contraseña no son correctos.',email_not_confirmed:'Confirma tu correo antes de entrar.',email_address_not_authorized:'El servicio de correo aún no puede enviar a esta dirección. Contacta con quien administra Palabreo.',otp_expired:'El código no es válido o ha caducado. Solicita otro.',over_email_send_rate_limit:'Has pedido demasiados correos. Espera un poco antes de intentarlo de nuevo.',over_request_rate_limit:'Demasiados intentos. Espera un poco antes de continuar.',user_already_exists:'Ya existe una cuenta con este correo.',weak_password:'La contraseña no cumple los requisitos. Usa una más larga y difícil de adivinar.',signup_disabled:'El registro está desactivado en este momento.',same_password:'Elige una contraseña diferente de la anterior.'};
  return known[code]??(status===429?'Demasiados intentos. Espera un poco.':status>=500?'El servicio no está disponible. Inténtalo más tarde.':'No se ha podido completar la operación. Comprueba los datos e inténtalo de nuevo.');
 }
 async function request(path,{method='POST',body,token}={}){
  const controller=new AbortController();const timeout=setTimeout(()=>controller.abort(),15000);
  try{
   const response=await fetchImpl(url+'/auth/v1/'+path,{method,headers:{apikey:key,'Content-Type':'application/json',...(token?{Authorization:'Bearer '+token}:{})},...(body!==undefined?{body:JSON.stringify(body)}:{}),signal:controller.signal,credentials:'omit',cache:'no-store'});
   const data=await response.json().catch(()=>({}));
   if(!response.ok){const error=new Error(errorText(data,response.status));error.status=response.status;throw error;}
   return data;
  }catch(error){if(error.status)throw error;throw new Error(error.name==='AbortError'?'La conexión ha tardado demasiado. Inténtalo de nuevo.':'No se ha podido conectar. Comprueba tu conexión a internet.');}finally{clearTimeout(timeout);}
 }
 async function nativeToken(){if(!refreshPromise){refreshPromise=new Promise((resolve,reject)=>{const requestId=crypto.randomUUID();const listener=event=>{if(event.detail.requestId!==requestId)return;cleanup();if(event.detail.error)reject(new Error(event.detail.error));else resolve(remember(event.detail.session,false));};const timeout=setTimeout(()=>{cleanup();reject(new Error('La conexión ha tardado demasiado. Inténtalo de nuevo.'));},25000);const cleanup=()=>{clearTimeout(timeout);globalThis.removeEventListener('palabreo-native-token',listener);};globalThis.addEventListener('palabreo-native-token',listener);try{native.requestAccessToken(requestId);}catch(error){cleanup();reject(error);}}).finally(()=>{refreshPromise=null;});}return refreshPromise;}
 async function refresh(){if(!session)return null;if(!refreshPromise){const token=session.refresh_token;refreshPromise=request('token?grant_type=refresh_token',{body:{refresh_token:token}}).then(remember).catch(error=>{if(error.status===400||error.status===401)remember(null);throw error;}).finally(()=>{refreshPromise=null;});}return refreshPromise;}
 async function accessToken(){if(native){await nativeToken();return session?.access_token;}if(!session)return null;if(session.expires_at<=Math.floor(Date.now()/1000)+60)await refresh();return session?.access_token;}
 return {
  getSession:()=>session,
  signIn:async(email,password)=>remember(await request('token?grant_type=password',{body:{email:email.trim(),password}})),
  signUp:async(email,password)=>{const data=await request('signup',{body:{email:email.trim(),password}});if(data.access_token)remember(data);return data;},
  verify:async(email,token,type='signup')=>remember(await request('verify',{body:{email:email.trim(),token:token.trim(),type}})),
  resend:email=>request('resend',{body:{type:'signup',email:email.trim()}}),
  recover:email=>request('recover',{body:{email:email.trim()}}),
  updatePassword:async password=>{const token=await accessToken();if(!token)throw new Error('Verifica primero el código recibido por correo.');const user=await request('user',{method:'PUT',token,body:{password}});remember({...session,user});return user;},
  restore:async()=>{if(!session)return null;try{const token=await accessToken();const user=await request('user',{method:'GET',token});return remember({...session,user});}catch(error){if(error.status===401||error.status===403)remember(null);throw error;}},
  signOut:async()=>{let remote=true;try{const token=await accessToken();if(token)await request('logout',{token});}catch{remote=false;}finally{remember(null);}return remote;},
  accessToken
 };
}

function initPalabreoAuth(){
 const auth=createAuthClient();window.PalabreoAuth=auth;const panel=document.querySelector('#account-dialog');const form=document.querySelector('#account-form');const status=document.querySelector('#account-status');const email=document.querySelector('#account-email');const password=document.querySelector('#account-password');const repeat=document.querySelector('#account-repeat');const code=document.querySelector('#account-code');const submit=document.querySelector('#account-submit');let mode='login',busy=false,recoveryVerified=false;
 function say(text,error=false){status.textContent=text;status.classList.toggle('error',error);}
 function modeUI(next){mode=next;say('');const verification=next==='verify'||next==='recovery-code';const hasPassword=['login','signup','new-password'].includes(next);email.closest('label').hidden=next==='new-password';email.required=next!=='new-password';password.closest('label').hidden=!hasPassword;password.required=hasPassword;password.minLength=next==='login'?1:8;password.autocomplete=next==='login'?'current-password':'new-password';repeat.closest('label').hidden=!['signup','new-password'].includes(next);repeat.required=['signup','new-password'].includes(next);code.closest('label').hidden=!verification;code.required=verification;
  document.querySelector('#account-mode-title').textContent={login:'Vuelve a tu cuenta',signup:'Crea tu cuenta',verify:'Confirma tu correo',recover:'Recupera tu contraseña','recovery-code':'Introduce tu código','new-password':'Elige otra contraseña'}[next];
  submit.textContent={login:'Entrar',signup:'Crear cuenta',verify:'Confirmar correo',recover:'Enviar código','recovery-code':'Verificar código','new-password':'Guardar contraseña'}[next];
  document.querySelector('#account-resend').hidden=next!=='verify';document.querySelector('#account-recover').hidden=next!=='login';document.querySelector('#account-tabs').hidden=['recover','recovery-code','new-password'].includes(next);
  document.querySelector('#account-email-note').hidden=!verification;password.value='';repeat.value='';code.value='';
  for(const tab of document.querySelectorAll('[data-account-mode]'))tab.setAttribute('aria-pressed',String(tab.dataset.accountMode===next));
 }
 function accountLabel(label){const button=document.querySelector('#account-open');button.setAttribute('aria-label',label);button.title=label;}
 function renderAccount(){const user=auth.getSession()?.user;const signed=!!user;document.querySelector('#account-signed-in').hidden=!signed;form.hidden=signed;document.querySelector('#account-email-display').textContent=user?.email??'';accountLabel(signed?'Mi cuenta':'Entrar / Registrarme');if(!signed)recoveryVerified=false;window.dispatchEvent(new CustomEvent('palabreo-auth-changed',{detail:{signed}}));}
 async function perform(fn){if(busy)return;busy=true;submit.disabled=true;for(const b of panel.querySelectorAll('button'))b.disabled=true;say('Conectando…');try{await fn();}catch(error){say(error.message,true);}finally{busy=false;for(const b of panel.querySelectorAll('button'))b.disabled=false;}}
 document.querySelector('#account-open').onclick=()=>{renderAccount();if(!auth.getSession())modeUI('login');panel.showModal();};document.querySelector('#account-close').onclick=()=>panel.close();
 for(const tab of document.querySelectorAll('[data-account-mode]'))tab.onclick=()=>modeUI(tab.dataset.accountMode);
 document.querySelector('#account-recover').onclick=()=>modeUI('recover');document.querySelector('#account-back').onclick=()=>modeUI('login');
 document.querySelector('#account-resend').onclick=()=>perform(async()=>{await auth.resend(email.value);say('Si hay una cuenta pendiente, recibirás un nuevo correo.');});
 form.onsubmit=e=>{e.preventDefault();perform(async()=>{
  if(['signup','new-password'].includes(mode)&&password.value!==repeat.value)throw new Error('Las contraseñas no coinciden.');
  if(mode==='login'){await auth.signIn(email.value,password.value);password.value='';renderAccount();say('Has iniciado sesión. El modo libre conserva sus estadísticas locales.');}
  else if(mode==='signup'){await auth.signUp(email.value,password.value);password.value='';repeat.value='';if(auth.getSession()){renderAccount();say('Cuenta creada. Ya has iniciado sesión.');}else{modeUI('verify');say('Revisa tu correo. Introduce aquí el código de confirmación. Si recibes un enlace, puedes confirmarlo y volver a Entrar.');}}
  else if(mode==='verify'){await auth.verify(email.value,code.value);code.value='';renderAccount();say('Correo confirmado. Ya has iniciado sesión.');}
  else if(mode==='recover'){await auth.recover(email.value);modeUI('recovery-code');say('Si el correo está registrado, recibirás un código para cambiar la contraseña.');}
  else if(mode==='recovery-code'){await auth.verify(email.value,code.value,'recovery');recoveryVerified=true;modeUI('new-password');say('Código verificado. Escribe tu nueva contraseña.');}
  else if(mode==='new-password'){if(!recoveryVerified)throw new Error('Verifica primero el código recibido.');await auth.updatePassword(password.value);password.value='';repeat.value='';recoveryVerified=false;renderAccount();say('Contraseña actualizada.');}
 });};
 document.querySelector('#account-logout').onclick=()=>perform(async()=>{const remote=await auth.signOut();renderAccount();modeUI('login');say(remote?'Has cerrado la sesión.':'Sesión borrada de este dispositivo. No se ha podido confirmar el cierre en el servidor.');});
 panel.addEventListener('close',()=>{password.value='';repeat.value='';code.value='';});
 // No se almacenan contraseñas. Una sesión que no pueda validarse no se presenta como conectada.
 renderAccount();if(auth.getSession()){accountLabel('Comprobar cuenta');auth.restore().then(renderAccount).catch(error=>{accountLabel(auth.getSession()?'Cuenta sin conexión':'Entrar / Registrarme');say(error.message,true);});}
}
initPalabreoAuth();
