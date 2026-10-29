"""Reassemble the recovered single-file Android asset without changing its contents."""
from pathlib import Path
import hashlib
import json
import re

root = Path(__file__).resolve().parents[1]
text = (root / 'index.html').read_bytes().decode('utf-8')
def inline(match):
    tag, name = match.group(1), match.group(2)
    content = (root / name).read_bytes().decode('utf-8')
    return '<script>' + content + '</script>' if tag == 'script' else '<style>' + content + '</style>'
text = re.sub(r'<(script) src="(js/[^"]+)"></script>|<(link) rel="stylesheet" href="(css/palabreo.css)">',
              lambda m: inline(m) if m.group(1) else '<style>' + (root / m.group(4)).read_bytes().decode('utf-8') + '</style>', text)
data = text.encode('utf-8')
out = root / 'dist' / 'assets' / 'Palabra.html'
out.parent.mkdir(parents=True, exist_ok=True)
out.write_bytes(data)
expected = json.loads((root / 'RECOVERY-MAP.json').read_text())['source_html_sha256']
actual = hashlib.sha256(data).hexdigest()
print(json.dumps({'output': str(out), 'sha256': actual, 'matches_recovered_original': actual == expected}))
