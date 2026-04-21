import ast
import unittest
from pathlib import Path


SOURCE_PATH = Path(__file__).resolve().parent.parent / "pingfighter.py"


def _load_source():
    return SOURCE_PATH.read_text(encoding="utf-8-sig")


def _parse_module():
    return ast.parse(_load_source())


def _get_runtime_skill_pool_entry(skill_id: str):
    module = _parse_module()
    for node in module.body:
        if not isinstance(node, ast.Assign):
            continue
        for target in node.targets:
            if isinstance(target, ast.Name) and target.id == "RUNTIME_SKILL_POOL":
                for key_node, value_node in zip(node.value.keys, node.value.values):
                    if isinstance(key_node, ast.Constant) and key_node.value == skill_id:
                        return ast.literal_eval(value_node)
    raise AssertionError(f"Could not find runtime skill entry for {skill_id}")


def _load_runtime_skill_helpers():
    source = _load_source()
    module = ast.parse(source)
    wanted = {
        "get_runtime_skill_level",
        "get_runtime_skill_bonus",
        "get_runtime_skill_description",
        "get_effective_item_spawn_multiplier",
    }
    chunks = []
    for node in module.body:
        if isinstance(node, ast.FunctionDef) and node.name in wanted:
            chunks.append(ast.get_source_segment(source, node))

    namespace = {
        "runtime_skill_levels": {},
        "transcendent_crown_skill_bonus": 0,
        "sage_ring_perk_bonus": 0,
        "_viper_ignition_aura_active": False,
        "_VIPER_IGNITION_PERK_LEVEL_BONUS": 2,
    }
    exec("\n\n".join(chunks), namespace)
    return namespace


class TestItemLuckCap(unittest.TestCase):
    def test_item_luck_lv5_description_matches_runtime_cap(self):
        item_luck = _get_runtime_skill_pool_entry("item_luck")
        self.assertEqual(
            item_luck["descriptions"][5],
            "아이템 스폰 대기 70% 감소 (최대)",
        )

    def test_item_luck_dynamic_description_stays_capped_above_lv5(self):
        helpers = _load_runtime_skill_helpers()
        item_luck = _get_runtime_skill_pool_entry("item_luck")
        self.assertEqual(
            helpers["get_runtime_skill_description"]("item_luck", item_luck, 6),
            "아이템 스폰 대기 70% 감소 (최대)",
        )

    def test_item_luck_spawn_multiplier_clamps_at_thirty_percent(self):
        helpers = _load_runtime_skill_helpers()
        helpers["runtime_skill_levels"]["item_luck"] = 5
        self.assertEqual(
            helpers["get_effective_item_spawn_multiplier"](),
            0.30,
        )


if __name__ == "__main__":
    unittest.main()
