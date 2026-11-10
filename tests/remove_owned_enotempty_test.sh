#!/bin/bash
# 门禁覆盖：pack/orch/roots.py
# roots.remove_owned 删目录时被写进新文件（#369 同类：外置盘上访达往正在删的目录写 .DS_Store）：期望按规则手写——
#   rmdir 第一次报 ENOTEMPTY（期间冒出 .DS_Store）→ 重列再删、目录不在；一直有人写（5 次都冒）→ 照原样抛 ENOTEMPTY
set -u; H=$(cd "$(dirname "$0")/.." && pwd); T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
o=$(cd "$H" && python3 - "$T" <<'PY'
import errno, sys
from pathlib import Path
sys.path.insert(0, ".")
from pack.orch import roots
t = Path(sys.argv[1])
def run(name, dirty):
    e = t / name; (e / "sub").mkdir(parents=True); (e / "sub" / "x").write_bytes(b"x")
    orig, n = Path.rmdir, [0]
    def rmdir(self):
        if self == e and n[0] < dirty:
            n[0] += 1; (e / ".DS_Store").write_bytes(b"x"); raise OSError(errno.ENOTEMPTY, "Directory not empty", str(self))
        orig(self)
    Path.rmdir = rmdir
    try:
        roots.remove_owned(e); return "删净" if not e.exists() else "还在"
    except OSError as x:
        return "抛" + errno.errorcode.get(x.errno, "?")
    finally:
        Path.rmdir = orig
print(run("a", 1), run("b", 99))
PY
)
[ "$o" = "删净 抛ENOTEMPTY" ] && echo "通 冒一次重列删净、一直冒照抛（${o}）" && echo "remove_owned_enotempty 单测全过" || { echo "不通（${o}）"; exit 1; }
