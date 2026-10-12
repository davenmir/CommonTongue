"""Download embedded libraries into CommonTongue/Libs for local dev and tests.

Mirrors the externals in .pkgmeta so local runs and packaged builds use the
same library versions. Keep ACE3_TAG in sync with .pkgmeta.
"""

import io
import shutil
import sys
import urllib.request
import zipfile
from pathlib import Path

ACE3_TAG = "Release-r1403"
ACE3_URL = f"https://github.com/WoWUIDev/Ace3/archive/refs/tags/{ACE3_TAG}.zip"

ROOT = Path(__file__).resolve().parent.parent
DEST = ROOT / "CommonTongue" / "Libs" / "Ace3"
STAMP = DEST / ".tag"


def main() -> int:
    if STAMP.exists() and STAMP.read_text().strip() == ACE3_TAG:
        print(f"Ace3 {ACE3_TAG} already present")
        return 0

    print(f"Downloading Ace3 {ACE3_TAG}")
    with urllib.request.urlopen(ACE3_URL) as resp:
        data = resp.read()

    if DEST.exists():
        shutil.rmtree(DEST)
    DEST.mkdir(parents=True)

    with zipfile.ZipFile(io.BytesIO(data)) as zf:
        prefix = zf.namelist()[0].split("/")[0] + "/"
        for name in zf.namelist():
            rel = name[len(prefix):]
            if not rel or name.endswith("/"):
                continue
            target = DEST / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(zf.read(name))

    STAMP.write_text(ACE3_TAG)
    print(f"Installed into {DEST.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
