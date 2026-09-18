"""Import the service under a name Python can actually spell.

The script is installed as `firefox-start-page-wanderer`, and its source keeps
that name so the unit, the binary and the file all match. Hyphens make it
un-importable, hence this shim: `from _load import wanderer`.
"""

import importlib.util
import pathlib

_path = pathlib.Path(__file__).resolve().with_name("firefox-start-page-wanderer.py")
_spec = importlib.util.spec_from_file_location("wanderer_service", _path)
assert _spec is not None and _spec.loader is not None, f"cannot load {_path}"
wanderer = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(wanderer)
