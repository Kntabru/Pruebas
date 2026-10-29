"""Browser -> intercepted local RPC transport -> real local PostgreSQL migrated functions.
Never connects to Supabase. Auth/profile/social display are test doubles; game RPCs are real.
"""
from pathlib import Path
from functools import partial
from http.server import ThreadingHTTPServer,SimpleHTTPRequestHandler
import json,threading,subprocess
from playwright.sync_api import sync_playwright
ROOT=Path(__file__).resolve().parents[1]
PSQL='/workspace/server-validation/postgresql/usr/lib/postgresql/17/bin/psql'
base=[PSQL,'-X','-q','-A','-t','-v','ON_ERROR_STOP=1','-h','/workspace/server-validation/socket','-U','agent','-d','palabreo_test']
user='33333333-3333-4333-8333-333333333333'
def query(s,uid=None):
 prefix=f"SET ROLE authenticated;SET request.jwt.claim.sub='{uid}';" if uid else 'SET ROLE postgres;'
 r=subprocess.run(base+['-c',prefix+s],capture_output=True,text=True)
 if r.returncode:raise RuntimeError(r.stderr)
 return r.stdout.strip()
def literal(v):
 if v is None:return 'NULL'
 if isinstance(v,bool):return str(v).lower()
 if isinstance(v,(int,float)):return str(v)
 return "'"+str(v).replace("'","''")+"'"
query("DELETE FROM public.leagues WHERE owner_id='"+user+"' AND name LIKE 'Browser test %'")
class Handler(SimpleHTTPRequestHandler):
 def log_message(self,*args):pass
server=ThreadingHTTPServer(('127.0.0.1',0),partial(Handler,directory=str(ROOT)))
threading.Thread(target=server.serve_forever,daemon=True).start();origin=f'http://127.0.0.1:{server.server_port}'
rpcs=[];errors=[];blocked=[];results=[]
try:
 with sync_playwright() as pw:
  browser=pw.chromium.launch(executable_path='/usr/bin/chromium',args=['--no-sandbox'])
  context=browser.new_context(viewport={'width':390,'height':844})
  context.add_init_script("localStorage.setItem('palabreo-auth-v1',JSON.stringify({access_token:'LOCAL-TEST-NOT-A-REAL-TOKEN',refresh_token:'LOCAL',expires_at:4102444800,user:{id:'"+user+"',email:'local@example.invalid'}}));")
  allowed={'palabreo_create_league','palabreo_create_league_v120','palabreo_leagues','palabreo_day','palabreo_open_round','palabreo_guess','palabreo_set_league_words','palabreo_report_word'}
  def route(r):
   url=r.request.url
   if url.startswith(origin+'/'):r.continue_();return
   if url=='https://nqtzfuaxmqulbqjdoznz.supabase.co/auth/v1/user':
    r.fulfill(status=200,content_type='application/json',body=json.dumps({'id':user,'email':'local@example.invalid'}));return
   if url.startswith('https://nqtzfuaxmqulbqjdoznz.supabase.co/rest/v1/'):
    if '/rpc/' not in url:data=[{'alias':'Local browser tester'}]
    else:
     name=url.rsplit('/',1)[-1];args=r.request.post_data_json or {}
     if name in allowed:
      try:
       text=query('SELECT public.'+name+'('+','.join(k+'=>'+literal(v) for k,v in args.items())+')',user)
       data=json.loads(text) if text.startswith(('[','{')) else text
       rpcs.append(name)
      except RuntimeError as e:
       r.fulfill(status=400,content_type='application/json',body=json.dumps({'code':'P0001','message':str(e)}));return
     elif name=='palabreo_league_activity':data={'events':[],'has_more':False}
     elif name=='palabreo_global_day_leader':data={'date':'2026-10-29','points':0,'leaders':[],'tie_count':0}
     else:data=[]
    r.fulfill(status=200,content_type='application/json',body=json.dumps(data));return
   blocked.append(url);r.abort()
  context.route('**/*',route);page=context.new_page();page.on('pageerror',lambda e:errors.append(str(e)));page.on('dialog',lambda d:d.accept())
  page.goto(origin+'/index.html');page.wait_for_selector('#keyboard button');page.locator('#free-length').select_option('7')
  for mode in ['5','6','7','random']:
   page.locator('#leagues-open').click();page.locator('#create-league-open').click()
   page.locator('#league-name').fill('Browser test '+mode);page.locator('#league-daily-words').select_option('3');page.locator('#league-length-mode').select_option(mode)
   page.locator('#create-league-form button').click()
   button=page.locator('.league-card-open').filter(has_text='Browser test '+mode)
   button.wait_for();button.click();page.locator('#daily-cards button').first.wait_for();page.locator('#daily-cards button').first.click()
   page.wait_for_function('PalabreoGame.active()!==null')
   packet=page.evaluate('PalabreoGame.active()');n=packet['word_length']
   assert n in [5,6,7] and (mode=='random' or n==int(mode))
   assert page.locator('#board').locator(':scope > *').count()==6*n
   assert page.locator('#free-length-control').is_hidden()
   answer=query("SELECT answer FROM palabreo_private.solutions WHERE challenge_id="+literal(packet['challenge_id']))
   for c in answer:page.locator(f'#keyboard button[data-key="{c}"]').click()
   page.locator('#keyboard button[data-key="ENTER"]').click();page.wait_for_function("PalabreoGame.active().status==='won'")
   assert page.locator('#board .correct').count()==n
   page.locator('#share-result').click();assert '🟩'*n in page.locator('#share-output').input_value();page.locator('#share-close').click()
   page.locator('#return-free').click();assert page.locator('#board').locator(':scope > *').count()==42
   results.append({'league_mode':mode,'round_length':n,'created_opened_and_won_through_ui':True})
  page.locator('#competition-open').click();page.locator('#daily-cards button').first.wait_for();page.locator('#daily-cards button').first.click();page.wait_for_function('PalabreoGame.active()!==null')
  assert page.locator('#board').locator(':scope > *').count()==30 and page.evaluate('PalabreoGame.active().word_length')==5
  page.locator('#return-free').click()
  # Restore actual legacy member; league configuration still appears as immutable five-letter.
  context.close();browser.close()
 assert not errors,errors
 assert not blocked,blocked
finally:server.shutdown()
report={'results':results,'global_five_checked':True,'rpc_calls_to_local_database':rpcs,'page_errors':errors,'blocked_requests':blocked,'live_supabase_contacted':False,'limitations':'Synthetic auth/profile/social responses; game create/day/open/guess use real migrated local SQL. No Android device test.'}
(ROOT/'validation/competitions-browser-results.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(report,ensure_ascii=False,indent=2))
