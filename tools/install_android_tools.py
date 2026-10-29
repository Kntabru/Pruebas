"""Install pinned Debian apksigner jars under a supplied directory, with SHA-256 verification."""
from pathlib import Path
import argparse,hashlib,subprocess,urllib.request
p=argparse.ArgumentParser();p.add_argument('destination',type=Path);a=p.parse_args();a.destination.mkdir(parents=True,exist_ok=True)
packages={'apksigner_35.0.2-1_all.deb':'5525a18d6a4cbb5025c2f74def51fa170b9eefdb98e3be18bb3d5207ed857797','libapksig-java_35.0.2-1_all.deb':'231c0f14ff5362b62bf92cdfdfbad6338f45f8c2e612dc4c1c96b542160ffe2f'}
for name,digest in packages.items():
 path=a.destination/name
 if not path.exists():
  with urllib.request.urlopen('https://deb.debian.org/debian/pool/main/a/android-platform-tools-apksig/'+name,timeout=60) as response:path.write_bytes(response.read())
 if hashlib.sha256(path.read_bytes()).hexdigest()!=digest:raise SystemExit('Checksum mismatch: '+name)
 subprocess.run(['dpkg-deb','-x',str(path),str(a.destination)],check=True)
print('Verified apksigner jars:',a.destination/'usr/share/java')
