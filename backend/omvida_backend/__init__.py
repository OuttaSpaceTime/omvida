"""Omvida's wiki service.

The wiki's parsing rules are the study repo's (its scripts/wiki package), so
the study checkout goes on the import path: OMVIDA_STUDY_CODE when set (the
test sandbox points OMVIDA_STUDY_DIR at fixture data, but the code is still the
real checkout's), else OMVIDA_STUDY_DIR, else ~/Code/study.
"""

import os
import sys
from pathlib import Path

_study = Path(os.environ.get("OMVIDA_STUDY_CODE") or os.environ.get("OMVIDA_STUDY_DIR")
              or Path.home() / "Code" / "study").expanduser()
if str(_study) not in sys.path:
    sys.path.insert(0, str(_study))
