"""Reproducible 6/7-letter selection: FrequencyWords ranking filtered through Spanish Hunspell."""
from pathlib import Path
import argparse,ctypes,hashlib,json,re,unicodedata
root=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--frequency',type=Path,required=True);p.add_argument('--hunspell-lib',required=True);p.add_argument('--hunspell-prefix',required=True);a=p.parse_args()
lib=ctypes.CDLL(a.hunspell_lib)
lib.Hunspell_create.argtypes=[ctypes.c_char_p,ctypes.c_char_p];lib.Hunspell_create.restype=ctypes.c_void_p
lib.Hunspell_spell.argtypes=[ctypes.c_void_p,ctypes.c_char_p];lib.Hunspell_spell.restype=ctypes.c_int
lib.Hunspell_destroy.argtypes=[ctypes.c_void_p]
h=lib.Hunspell_create((a.hunspell_prefix+'.aff').encode(),(a.hunspell_prefix+'.dic').encode())
if not h:raise SystemExit('Hunspell dictionary unavailable')
normal=lambda w:w.translate(str.maketrans('ÁÉÍÓÚÜ','AEIOUU'))
ranked={6:{'normal':{},'accents':{}},7:{'normal':{},'accents':{}}}
for line in a.frequency.read_text().splitlines():
 try:word,freq=line.rsplit(' ',1);freq=int(freq)
 except ValueError:continue
 word=unicodedata.normalize('NFC',word).lower()
 if len(word) not in ranked or not re.fullmatch('[a-zñáéíóúü]+',word):continue
 if not lib.Hunspell_spell(h,word.encode('utf-8')):continue
 accented=word.upper().replace('Ü','U')
 # The original keyboard distinguishes ÁÉÍÓÚ but not Ü; preserve its existing alphabet.
 # Words requiring Ü are excluded in Tildes, instead of accepting a wrong spelling.
 if 'ü' not in word:
  ranked[len(word)]['accents'][accented]=max(freq,ranked[len(word)]['accents'].get(accented,0))
 unaccented=normal(word.upper())
 ranked[len(word)]['normal'][unaccented]=max(freq,ranked[len(word)]['normal'].get(unaccented,0))
lib.Hunspell_destroy(h)
result={};summary={}
for n,modes in ranked.items():
 result[n]={};summary[n]={}
 for mode,items in modes.items():
  ranked_words=sorted(items,key=lambda w:(-items[w],w))
  if len(ranked_words)<10000:raise SystemExit(f'Not enough valid words: {n} {mode}: {len(ranked_words)}')
  accepted=ranked_words[:10000];solutions=accepted[:3000]
  result[n][mode]={'accepted':accepted,'answers':solutions}
  summary[n][mode]={'candidates':len(ranked_words),'accepted':len(accepted),'solutions':len(solutions)}
folder=root/'data';folder.mkdir(exist_ok=True)
(folder/'words-6-7.json').write_text(json.dumps(result,ensure_ascii=False,separators=(',',':'))+'\n')
(root/'js/words-6-7.js').write_text('// Derived dictionaries: MPL-2.0 and CC BY-SA 4.0. See DICTIONARY.md and licenses/.\nwindow.PalabreoLongWords='+json.dumps(result,ensure_ascii=False,separators=(',',':'))+';\n')
(folder/'selection.json').write_text(json.dumps({'frequency_sha256':hashlib.sha256(a.frequency.read_bytes()).hexdigest(),'frequency_commit':'525f9b560de45753a5ea01069454e72e9aa541c6','frequency_source':'https://github.com/hermitdave/FrequencyWords/blob/525f9b560de45753a5ea01069454e72e9aa541c6/content/2018/es/es_full.txt','hunspell_aff_sha256':hashlib.sha256(Path(a.hunspell_prefix+'.aff').read_bytes()).hexdigest(),'hunspell_dic_sha256':hashlib.sha256(Path(a.hunspell_prefix+'.dic').read_bytes()).hexdigest(),'counts':summary},ensure_ascii=False,indent=2)+'\n')
print(json.dumps(summary,indent=2))
