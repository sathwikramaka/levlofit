"""Superseded by review_package.py (per-claim reviewer package). Kept so old instructions still work: runs the package."""
import importlib.util
from pathlib import Path

_s = importlib.util.spec_from_file_location("review_package", Path(__file__).resolve().parent / "review_package.py")
_m = importlib.util.module_from_spec(_s)
_s.loader.exec_module(_m)

if __name__ == "__main__":
    _m.main()
