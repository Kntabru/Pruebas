"""Browser recovery checks. All non-local requests are blocked; no backend writes."""
from pathlib import Path
from functools import partial
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
import threading, json
from playwright.sync_api import sync_playwright
ROOT = Path(__file__).resolve().parents[1]
class Handler(SimpleHTTPRequestHandler):
    def log_message(self, *args): pass
server = ThreadingHTTPServer(('127.0.0.1', 0), partial(Handler, directory=str(ROOT)))
threading.Thread(target=server.serve_forever, daemon=True).start()
base = f'http://127.0.0.1:{server.server_port}'
results = []
try:
 with sync_playwright() as pw:
  browser = pw.chromium.launch(executable_path='/usr/bin/chromium', args=['--no-sandbox'])
  for entry in ['/index.html', '/dist/assets/Palabra.html']:
   context = browser.new_context(viewport={'width':390,'height':844})
   blocked=[]; errors=[]
   def route(r):
    if r.request.url.startswith(base+'/'): r.continue_()
    else: blocked.append(r.request.url.split('?')[0]);r.abort()
   context.route('**/*', route)
   page=context.new_page();page.on('pageerror',lambda e: errors.append(str(e)))
   page.goto(base+entry);page.wait_for_selector('#keyboard button')
   assert page.title()=='Palabreo'
   assert page.locator('#board').locator(':scope > *').count()==30
   def state():return page.evaluate("JSON.parse(localStorage.getItem('palabra-v1'))")
   def typeword(word):
    for c in word:page.locator(f'#keyboard button[data-key="{c}"]').click()
    page.locator('#keyboard button[data-key="ENTER"]').click()
   # Invalid word consumes no attempt.
   typeword('ZZZZZ');assert len(state()['game']['guesses'])==0
   assert 'No conozco' in page.locator('#message').inner_text()
   # Partial input and progress survive reload; answer is read only from this test's local state.
   answer=state()['game']['answer'];page.locator(f'#keyboard button[data-key="{answer[0]}"]').click()
   page.reload();assert state()['game']['current']==answer[0]
   page.locator('#keyboard button[data-key="BACKSPACE"]').click()
   typeword(answer);assert state()['game']['finished'] and state()['totalStats']['wins']==1
   assert page.locator('#board .correct').count()==5
   page.locator('#share-result').click();assert answer not in page.locator('#share-output').input_value()
   page.locator('#share-close').click()
   page.locator('#next-game').click();assert not state()['game']['finished']
   # Theme and palette persist locally.
   before=page.locator('html').get_attribute('data-theme');page.locator('#theme-toggle').click()
   assert page.locator('html').get_attribute('data-theme')!=before
   page.reload();assert page.locator('html').get_attribute('data-theme')!=before
   page.locator('#options-open').click()
   page.locator('#clue-color-correct').evaluate("e=>{e.value='#123456';e.dispatchEvent(new Event('input',{bubbles:true}));}")
   page.locator('#options-close').click();page.reload()
   assert '#123456' in page.evaluate("localStorage.getItem('palabreo-clue-colors-v1')")
   # Win in each remaining mode using real keyboard UI.
   for mode in ['hard','accents']:
    page.locator('#free-mode-open').click();page.locator(f'[data-free-mode="{mode}"]').click()
    assert state()['freeMode']==mode
    if mode=='accents':assert page.locator('#keyboard button[data-key="Á"]').count()==1
    typeword(state()['game']['answer']);assert state()['game']['finished']
    assert state()['statsByMode'][mode]['wins']==1
    page.locator('#next-game').click()
   # Loss after six dictionary-valid incorrect guesses.
   answer=state()['game']['answer']
   other=page.evaluate('accentAnswers.find(w=>w!==JSON.parse(localStorage.getItem("palabra-v1")).game.answer)')
   for _ in range(6):typeword(other)
   assert state()['game']['finished'] and len(state()['game']['guesses'])==6
   assert state()['statsByMode']['accents']['losses']==1
   assert not errors,errors
   results.append({'entry':entry,'passed':['load','30 tiles','invalid word','partial input persistence','normal victory and clues','share without answer','new round','theme persistence','palette persistence','hard victory','accents keyboard and victory','six-attempt loss'],'page_errors':errors,'blocked_external_requests':blocked})
   context.close()
  browser.close()
finally:server.shutdown()
(ROOT/'validation/browser-results.json').write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(results,ensure_ascii=False,indent=2))
