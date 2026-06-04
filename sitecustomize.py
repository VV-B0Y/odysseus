"""Runtime compatibility helpers for the Based code rebrand.

Python imports this module automatically on startup when the repository root is
on ``sys.path``. Mirror legacy ``ODYSSEUS_*`` environment variables into their
``BASEDCODE_*`` names so existing deployments keep working while the new brand
is the canonical interface.
"""

from __future__ import annotations

import os


for key, value in tuple(os.environ.items()):
    if not key.startswith("ODYSSEUS_"):
        continue
    new_key = "BASEDCODE_" + key[len("ODYSSEUS_") :]
    os.environ.setdefault(new_key, value)
