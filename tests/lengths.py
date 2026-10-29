"""Real-browser 3x3 free-play matrix, persistence, legacy migration, and packet contract checks.
No live backend operations; every non-local request is blocked.
"""
from pathlib import Path
from functools import partial
from http.server import ThreadingHTTPServer,SimpleHTTPRequestHandler
import json,threading
from playwright.sync_api import sync_playwright
ROOT=Path(__file__).resolve().parents[1]
class Handler(SimpleHTTPRequestHandler):
 def log_message(self,*args):pass
server=ThreadingHTTPServer(('127.0.0.1',0),partial(Handler,directory=str(ROOT)))
threading.Thread(target=server.serve_forever,daemon=True).start();base=f'http://127.0.0.1:{server.server_port}'
results=[];blocked=[];errors=[]
try:
 with sync_playwright() as pw:
  browser=pw.chromium.launch(executable_path='/usr/bin/chromium',args=['--no-sandbox'])
  for entry in ['/index.html','/dist/assets/Palabra.html']:
   context=browser.new_context(viewport={'width':320,'height':800})
   def route(r):
    if r.request.url.startswith(base+'/'):r.continue_()
    else:blocked.append(r.request.url.split('?')[0]);r.abort()
   context.route('**/*',route);page=context.new_page();page.on('pageerror',lambda e:errors.append(str(e)))
   page.on('dialog',lambda d:d.accept())
   page.goto(base+entry);page.wait_for_selector('#keyboard button')
   state=lambda:page.evaluate("JSON.parse(localStorage.getItem('palabra-v1'))")
   def guess(w):
    for c in w:page.locator(f'#keyboard button[data-key="{c}"]').click()
    page.locator('#keyboard button[data-key="ENTER"]').click()
   for n in [5,6,7]:
    page.locator('#free-length').select_option(str(n))
    for mode in ['normal','hard','accents']:
     page.locator('#free-mode-open').click();page.locator(f'[data-free-mode="{mode}"]').click()
     assert state()['game']['wordLength']==n and state()['freeMode']==mode
     assert page.locator('#board').locator(':scope > *').count()==6*n
     assert page.evaluate('document.documentElement.scrollWidth<=window.innerWidth'),f'Horizontal overflow {n} {mode}'
     # Incomplete words and overlong input never consume attempts or overflow the board.
     guess('A'*(n-1));assert state()['game']['guesses']==[]
     page.locator('#keyboard button[data-key="A"]').click();page.locator('#keyboard button[data-key="A"]').click()
     assert len(state()['game']['current'])==n
     for _ in range(n):page.locator('#keyboard button[data-key="BACKSPACE"]').click()
     answer=state()['game']['answer']
     if mode=='accents' and n>5:
      # Ensure a real accented solution is exercised, using the game's saved-state restoration.
      accented=page.evaluate(f"PalabreoLongWords[{n}].accents.answers.find(w=>/[ÁÉÍÓÚ]/.test(w))")
      page.evaluate('(w)=>{const s=JSON.parse(localStorage.getItem("palabra-v1"));s.game.answer=w;localStorage.setItem("palabra-v1",JSON.stringify(s));}',accented)
      page.reload();answer=state()['game']['answer'];assert answer==accented
     page.locator(f'#keyboard button[data-key="{answer[0]}"]').click()
     # Delete a tile, fill its gap, then confirm persisted progress.
     page.locator('#board button').first.click();assert state()['game']['current']==''
     page.locator(f'#keyboard button[data-key="{answer[0]}"]').click();page.reload();assert state()['game']['current']==answer[0]
     page.locator('#keyboard button[data-key="BACKSPACE"]').click();guess(answer)
     assert state()['game']['finished'] and page.locator('#board .correct').count()==n
     page.locator('#share-result').click();shared=page.locator('#share-output').input_value()
     assert f'{n} letras' in shared and '🟩'*n in shared and answer not in shared
     page.locator('#share-close').click();page.locator('#next-game').click()
     # Six incorrect, dictionary-valid attempts cause a loss. Test hard-mode restrictions separately.
     if mode!='hard':
      other=page.evaluate("[...activeDictionary()].find(w=>w!==answer)")
      for _ in range(6):guess(other)
      assert state()['game']['finished'] and len(state()['game']['guesses'])==6
      page.locator('#next-game').click()
     results.append({'entry':entry,'length':n,'mode':mode,'win_and_persistence':True,'share_width':n,'loss_checked':mode!='hard','mobile_width':320})
   assert page.evaluate("score('CASASA','CASITA')")==['correct','correct','correct','absent','absent','correct']
   assert page.evaluate("hardModeError('CAMINAR',[{word:'CAMINOS',result:['absent','absent','absent','absent','absent','absent','correct']}])").startswith('Mantén la S')
   assert page.evaluate("hardModeError('CASITA',[{word:'CASASA',result:score('CASASA','CASITA')}])")==''
   # A 7-letter free game survives visiting global and an old 5-letter league.
   old=state()['game']
   packet={'id':'local-test','league_id':None,'word_length':7,'slot':1,'daily_words':5,'date':'2026-10-29','guesses':[],'status':'playing','started_at':'2026-10-29T12:00:00Z','server_time':'2026-10-29T12:00:00Z'}
   page.evaluate('(p)=>PalabreoGame.load(p)',packet)
   assert page.locator('#board').locator(':scope > *').count()==30
   assert page.locator('#free-length-control').is_hidden()
   page.evaluate('PalabreoGame.leave()');assert state()['game']==old
   packet['league_id']='old-league';del packet['word_length']
   page.evaluate('(p)=>PalabreoGame.load(p)',packet)
   assert page.locator('#board').locator(':scope > *').count()==30
   page.evaluate('PalabreoGame.leave()');assert state()['game']==old
   for n in [6,7]:
    packet['word_length']=n
    page.evaluate('(p)=>PalabreoGame.load(p)',packet)
    assert page.locator('#board').locator(':scope > *').count()==6*n
    page.evaluate('PalabreoGame.leave()')
   # Restore a v2/1.19 saved game and its statistics without discarding it.
   legacy={'freeVersion':2,'freeMode':'normal','statsByMode':state()['statsByMode'],'totalStats':state()['totalStats'],'game':{'mode':'normal','answer':'AMIGO','guesses':[],'current':'A','finished':False,'previous':'AMIGO','startedAt':None,'elapsed':0}}
   page.evaluate('(s)=>localStorage.setItem("palabra-v1",JSON.stringify(s))',legacy);page.reload()
   assert state()['freeLength']==5 and state()['game']['answer']=='AMIGO' and state()['game']['current']=='A'
   assert state()['totalStats']==legacy['totalStats']
   context.close()
  browser.close()
 assert not errors,errors
 assert not blocked,blocked
finally:server.shutdown()
(ROOT/'validation/lengths-results.json').write_text(json.dumps({'matrix':results,'additional_checks':['duplicate scoring','hard clue at position 7','return to free play','global forced to 5','legacy league defaults to 5','6/7 packet rendering only (no backend test)','v2 saved-game/statistics migration'],'page_errors':errors,'blocked_requests':blocked},ensure_ascii=False,indent=2)+'\n')
print(f'{len(results)} combinations passed (two builds x three lengths x three modes); additional compatibility checks passed. No external requests.')
