"""Repackage recovered native binaries + editable web assets, sign and verify. No new key generation."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import sys
import zipfile
from android_manifest import inspect, set_version, set_version_name

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--signing-dir', required=True, type=Path, help='Private backup directory containing release.p12 and key-password.txt')
parser.add_argument('--apksigner-dir', required=True, type=Path, help='Directory containing apksigner and apksig jars')
parser.add_argument('--version-code', type=int, default=22)
parser.add_argument('--version-name', default='1.20')
args = parser.parse_args()
private = args.signing_dir.resolve()
if private == root or root in private.parents:
    raise SystemExit('Signing material must stay outside the Git repository')
for required in ['release.p12','key-password.txt']:
    if not (private/required).is_file():
        raise SystemExit('Falta la firma original recuperada: '+str(private/required)+'. Restaura el respaldo privado; NO se generará otra clave.')
if not list(args.apksigner_dir.glob('apksigner*.jar')) or not list(args.apksigner_dir.glob('apksig-*.jar')):
    raise SystemExit('Faltan las herramientas apksigner; ejecuta tools/install_android_tools.py.')
subprocess.run([sys.executable, str(root/'tools/build_html.py')], check=True)
reference = root/'android-reference'
output = root/'android-build'
output.mkdir(exist_ok=True)
unsigned = output/'Palabreo-unsigned.apk'
signed = output/f'Palabreo {args.version_name}.apk'
old_manifest = (reference/'AndroidManifest.xml').read_bytes()
manifest = set_version_name(set_version(old_manifest, args.version_code), args.version_name)
with zipfile.ZipFile(unsigned, 'w') as z:
    files = [('AndroidManifest.xml', manifest),
             ('res/drawable/ic_launcher.xml', (reference/'res/drawable/ic_launcher.xml').read_bytes()),
             ('res/drawable/ic_notification.xml', (reference/'res/drawable/ic_notification.xml').read_bytes()),
             ('resources.arsc', (reference/'resources.arsc').read_bytes()),
             ('assets/Palabra.html', (root/'dist/assets/Palabra.html').read_bytes()),
             ('classes.dex', (reference/'classes.dex').read_bytes())]
    for name, data in files:
        info = zipfile.ZipInfo(name, date_time=(2026,10,29,0,0,0))
        info.compress_type = zipfile.ZIP_STORED if name == 'resources.arsc' else zipfile.ZIP_DEFLATED
        info.external_attr = 0o100644 << 16
        # Android target 30+ requires an uncompressed, 4-byte-aligned resources.arsc.
        if info.compress_type == zipfile.ZIP_STORED:
            offset = z.fp.tell()+30+len(name.encode())
            padding = (-offset-4) % 4
            info.extra = struct.pack('<HH', 0xD935, padding)+b'\0'*padding
        z.writestr(info, data)
java = ['java', '-cp', str(args.apksigner_dir.resolve()/'*'), 'com.android.apksigner.ApkSignerTool']
subprocess.run(java+['sign', '--ks', str(private/'release.p12'), '--ks-type', 'PKCS12',
    '--ks-key-alias', 'palabreo-release', '--ks-pass', 'file:'+str(private/'key-password.txt'),
    '--v1-signing-enabled', 'false',
    '--v2-signing-enabled', 'true', '--v3-signing-enabled', 'true', '--v4-signing-enabled', 'false',
    '--out', str(signed), str(unsigned)], check=True)
verification = subprocess.run(java+['verify', '--verbose', '--print-certs', str(signed)], check=True, capture_output=True, text=True).stdout
expected_certificate = '8d1b1c337dfa5ba83e3f85e987d4785f5af9ad7f4ad1909c0b3dc431d67d3b5e'
if 'certificate SHA-256 digest: '+expected_certificate not in verification:
    signed.unlink(missing_ok=True)
    raise SystemExit('Firma inesperada. Restaura el respaldo original de esta recuperación; no usar otra clave.')
(output/'signature-verification.txt').write_text(verification)
print(verification)
with zipfile.ZipFile(signed) as z:
    assert z.testzip() is None
    assert set(z.namelist()) == {name for name,_ in files}, 'Unexpected/missing APK entry'
    for name, data in files:
        assert z.read(name) == data, 'APK content mismatch: '+name
    resource = z.getinfo('resources.arsc')
    with signed.open('rb') as f:
        f.seek(resource.header_offset)
        header = f.read(30)
    name_len, extra_len = struct.unpack_from('<HH', header, 26)
    assert resource.compress_type == 0 and (resource.header_offset+30+name_len+extra_len) % 4 == 0
    elements, _ = inspect(z.read('AndroidManifest.xml'))
report = {'apk': signed.name, 'sha256': hashlib.sha256(signed.read_bytes()).hexdigest(),
    'manifest': elements, 'native_dex_unchanged': True, 'web_asset_matches_build': True,
    'resources_stored_and_aligned_4_bytes': True, 'zip_crc_ok': True,
    'signature_verified_by_apksigner': True,
    'native_device_tested': False,
    'limitations': ['Native code is preserved DEX, not recompiled Java/Kotlin.', 'No Android device/emulator or live Supabase test.']}
(output/'verification.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if k != 'manifest'},indent=2))
