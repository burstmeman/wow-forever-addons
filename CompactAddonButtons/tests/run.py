"""Run this addon's specs through the shared Lua 5.1 suite."""
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / ".github/ci"))

from lua_tests import run_suite

# addon_spec loads the addon into the shared state. Later specs in this list
# continue from that state, so keep them in dependency order.
run_suite(
    Path(__file__).resolve().parents[1],
    specs=("addon_spec.lua", "localization_spec.lua"),
    once=("performance_spec.lua",),
)
