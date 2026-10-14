/* BMTH notification bell; in-app only, no push permission needed. */
import {createClient} from 'https://esm.sh/@supabase/supabase-js@2';
const client=createClient('https://hfmnoiaiyrchxrxprsav.supabase.co','sb_publishable_0HS5ItAQ76mtGqkEQ387Lw_Adirp2Ml');
const css=document.createElement('style');css.textContent=`
.bmth-bell{position:fixed;right:18px;top:96px;z-index:900;background:#271421;color:#ffe6ed;border:1px solid #ac4665;border-radius:14px;padding:10px 13px;font:600 14px system-ui;box-shadow:0 8px 24px #0008;cursor:pointer}
.bmth-bell-count{display:inline-block;background:#d03951;border-radius:20px;min-width:19px;text-align:center;margin-left:5px}
.bmth-bell-panel{position:fixed;right:15px;top:146px;z-index:901;width:min(360px,calc(100vw - 30px));max-height:min(65vh,550px);overflow:auto;background:#19121e;border:1px solid #8a4760;border-radius:14px;box-shadow:0 12px 40px #000b;padding:16px;color:#f9e9f0;font:14px system-ui}
.bmth-bell-panel a{display:block;color:#ffe0e9;text-decoration:none;border-bottom:1px solid #473040;padding:12px 4px}
.bmth-bell-panel a:hover{background:#32202d}
.bmth-bell-panel small{display:block;color:#b8a5b0}
.bmth-bell-panel button{background:#4b2435;border:1px solid #90516a;color:#fff;padding:7px;cursor:pointer;border-radius:8px}
@media(max-width:700px){.bmth-bell{top:76px;right:12px}.bmth-bell-panel{top:124px}}
`;document.head.append(css);
const {data:{user}}=await client.auth.getUser();
if(user){
 const bell=document.createElement('button');bell.className='bmth-bell';bell.type='button';bell.setAttribute('aria-label','Notificações');bell.textContent='♧ Avisos';
 const count=document.createElement('span');count.className='bmth-bell-count';count.hidden=true;bell.append(count);
 const panel=document.createElement('section');panel.className='bmth-bell-panel';panel.hidden=true;
 const heading=document.createElement('strong');heading.textContent='Notificações';
 const close=document.createElement('button');close.textContent='Fechar';close.style.float='right';close.onclick=()=>panel.hidden=true;
 const items=document.createElement('div');panel.append(heading,close,items);document.body.append(bell,panel);
 const refresh=async()=>{
  const {data,error}=await client.from('bmth_notifications').select('id,title,href,created_at,read_at').eq('recipient_id',user.id).order('created_at',{ascending:false}).limit(40);
  items.replaceChildren();if(error){items.textContent='Ative as notificações no Supabase com supabase/notifications.sql.';count.hidden=true;return}
  const unread=(data||[]).filter(n=>!n.read_at).length;count.hidden=!unread;count.textContent=String(unread);
  if(!data?.length)items.textContent='Nenhuma notificação por enquanto.';
  for(const n of data||[]){const a=document.createElement('a');a.href=n.href.startsWith('./')?n.href:'./comunidade.html';a.textContent=(n.read_at?'':'● ')+n.title;const date=document.createElement('small');date.textContent=new Date(n.created_at).toLocaleString('pt-BR');a.append(date);a.addEventListener('click',()=>{if(!n.read_at)client.from('bmth_notifications').update({read_at:new Date().toISOString()}).eq('id',n.id).eq('recipient_id',user.id).then(()=>{})});items.append(a)}
 };
 bell.onclick=async()=>{panel.hidden=!panel.hidden;if(!panel.hidden)await refresh()};
 await refresh();document.addEventListener('visibilitychange',()=>{if(!document.hidden)refresh()});
}
