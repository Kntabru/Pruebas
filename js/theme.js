
(()=>{
 const media=window.matchMedia('(prefers-color-scheme: dark)');let choice=null;
 try{const saved=localStorage.getItem('palabreo-theme');if(saved==='light'||saved==='dark')choice=saved;}catch{}
 function applyTheme(theme){
  const dark=theme==='dark';document.documentElement.dataset.theme=theme;document.documentElement.style.colorScheme=theme;
  document.querySelector('meta[name="theme-color"]').content=dark?'#142019':'#f7f8f2';
  const button=document.getElementById('theme-toggle');if(button){button.setAttribute('aria-pressed',String(dark));button.setAttribute('aria-label',dark?'Activar modo claro':'Activar modo oscuro');button.title=dark?'Activar modo claro':'Activar modo oscuro';}
  try{if(window.PalabreoAppearance)window.PalabreoAppearance.setDarkTheme(dark);}catch{}
 }
 applyTheme(choice??(media.matches?'dark':'light'));
 document.addEventListener('DOMContentLoaded',()=>{applyTheme(choice??(media.matches?'dark':'light'));document.getElementById('theme-toggle').addEventListener('click',()=>{choice=document.documentElement.dataset.theme==='dark'?'light':'dark';try{localStorage.setItem('palabreo-theme',choice);}catch{}applyTheme(choice);});});
 const systemChanged=()=>{if(!choice)applyTheme(media.matches?'dark':'light');};
 if(media.addEventListener)media.addEventListener('change',systemChanged);else media.addListener(systemChanged);
})();
