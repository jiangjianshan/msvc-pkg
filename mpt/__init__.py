import os
from pathlib import Path

# Calculate the root directory path
ROOT_DIR = Path(__file__).parent.parent

# Export variable to make it available for import by other modules
__all__ = ['ROOT_DIR']
