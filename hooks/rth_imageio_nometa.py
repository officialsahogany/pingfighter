"""
PyInstaller runtime hook to avoid imageio importlib.metadata lookup errors.

Some packaged environments lack .dist-info metadata, causing imageio to raise:
`No package metadata was found for imageio`.
We disable metadata lookup before imageio is ever imported.
"""

import os

# Tell imageio to skip importlib.metadata discovery.
os.environ.setdefault("IMAGEIO_NO_IMPORTLIB_METADATA", "1")
