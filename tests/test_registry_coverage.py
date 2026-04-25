from pathlib import Path
from contextlib import contextmanager
import re
import shutil
import tempfile

from tools.registry_coverage import build_report, format_issues


PROJECT_ROOT = Path(__file__).resolve().parents[1]
REGISTRY_SOURCE_FILES = (
    "items.py",
    "pingfighter.py",
    "gacha.py",
    "legendary_items.py",
    "item_effects/bazooka.py",
    "item_effects/ak47.py",
    "item_effects/net_gun.py",
    "item_effects/bowling_trap.py",
)


def _copy_registry_sources(target_root: Path) -> Path:
    for relative in REGISTRY_SOURCE_FILES:
        source = PROJECT_ROOT / relative
        target = target_root / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
    return target_root


@contextmanager
def _temporary_registry_root():
    tmp_parent = PROJECT_ROOT / ".tmp"
    tmp_parent.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(
        prefix="registry_coverage_",
        dir=tmp_parent,
    ) as tmp_dir:
        yield _copy_registry_sources(Path(tmp_dir))


def _issue_codes(report):
    return {issue.code for issue in report.issues}


def test_registry_coverage_has_no_errors():
    report = build_report(PROJECT_ROOT)

    assert not report.errors, format_issues(report.errors, include_info=True)


def test_registry_coverage_has_no_default_warnings():
    report = build_report(PROJECT_ROOT)

    assert not report.warnings, format_issues(report.warnings, include_info=True)


def test_online_passive_classification_uses_shared_helper():
    report = build_report(PROJECT_ROOT)
    warning_codes = {issue.code for issue in report.warnings}

    assert "CAPTURE_PASSIVE_NAMES_MISSING" not in warning_codes
    assert "ONLINE_PASSIVE_HELPER_NOT_USED" not in warning_codes


def test_mini_skill_icon_registry_is_active():
    report = build_report(PROJECT_ROOT)

    assert report.counts["skills.mini_registry_ids"] >= 45
    assert report.counts["skills.smasher_orb_registry_ids"] >= 9
    assert report.counts["skills.viper_orb_registry_ids"] >= 11
    assert report.counts["skills.soldier_orb_registry_ids"] >= 9
    assert report.counts["skills.optimus_icon_registry_ids"] >= 9
    assert report.counts["skills.blacksmith_icon_registry_ids"] >= 1
    assert report.counts["skills.blacksmith_bespoke_registry_ids"] >= 1


def test_icon_schema_registry_fields_are_complete():
    report = build_report(PROJECT_ROOT)

    assert report.counts["skills.icon_schema_registry_ids"] == 39
    assert report.counts["skills.icon_schema_slot_occupancy_fields"] == 39
    assert report.counts["skills.icon_schema_cleanup_policy_fields"] == 39
    assert report.counts["skills.icon_schema_cooldown_reduction_fields"] == 39
    assert report.counts["skills.soldier_shared_swap_cleanup_policy_ids"] == 6


def test_optimus_is_the_only_cooldown_reduction_schema_opt_out():
    report = build_report(PROJECT_ROOT)

    assert report.counts["skills.optimus_cooldown_reduction_ineligible_ids"] == 9
    assert report.counts["skills.non_optimus_cooldown_reduction_ineligible_ids"] == 0


def test_soldier_mixed_slot_static_safety_checks_are_active():
    report = build_report(PROJECT_ROOT)

    assert report.counts["skills.soldier_firearm_cooldown_sync_targets"] == 4
    assert report.counts["skills.soldier_firearm_cooldown_helper_attr_syncs"] == 4
    assert report.counts["skills.soldier_firearm_cooldown_fire_path_syncs"] == 4
    assert report.counts["skills.soldier_equipped_pop_sites"] == 1
    assert report.counts["skills.soldier_equipped_pop_cleanup_guarded_sites"] == 1
    assert report.counts["skills.academy_swap_calls"] == 3
    assert report.counts["skills.academy_swap_return_guarded_calls"] == 1
    assert report.counts["skills.academy_swap_prechecked_calls"] == 2


def test_soldier_firearm_cooldown_sync_regression_is_reported():
    with _temporary_registry_root() as root:
        path = root / "pingfighter.py"
        source = path.read_text(encoding="utf-8")
        target = '''_apply_soldier_firearm_cooldown_frames(
                            "net_gun",
                            net_gun,
                            apply_reduction=permanent_firearm_selected,
                        )'''
        assert target in source
        path.write_text(
            source.replace(
                target,
                '''_bypassed_soldier_firearm_cooldown_frames(
                            "net_gun",
                            net_gun,
                            apply_reduction=permanent_firearm_selected,
                        )''',
                1,
            ),
            encoding="utf-8",
        )

        report = build_report(root)

    assert "SOLDIER_FIREARM_FIRE_PATH_COOLDOWN_SYNC_MISSING" in _issue_codes(report)


def test_soldier_equipped_direct_pop_regression_is_reported():
    with _temporary_registry_root() as root:
        path = root / "pingfighter.py"
        source = path.read_text(encoding="utf-8")
        path.write_text(
            source
            + "\n\ndef _bad_soldier_pop_for_registry_test():\n"
            + "    return _soldier_equipped_skills.pop()\n",
            encoding="utf-8",
        )

        report = build_report(root)

    assert "SOLDIER_EQUIPPED_DIRECT_POP" in _issue_codes(report)


def test_soldier_academy_swap_return_guard_regression_is_reported():
    with _temporary_registry_root() as root:
        path = root / "pingfighter.py"
        source = path.read_text(encoding="utf-8")
        target = '''if not swap_soldier_skill(old_skill_name, new_skill_name):
            return False'''
        assert target in source
        path.write_text(
            source.replace(
                target,
                "swap_soldier_skill(old_skill_name, new_skill_name)",
                1,
            ),
            encoding="utf-8",
        )

        report = build_report(root)

    assert "ACADEMY_SWAP_RETURN_UNCHECKED" in _issue_codes(report)


def test_soldier_shared_swap_cleanup_policy_regression_is_reported():
    with _temporary_registry_root() as root:
        path = root / "pingfighter.py"
        source = path.read_text(encoding="utf-8")
        mutated, count = re.subn(
            r'("net_gun": \{.*?"cleanup_policy": )"shared_swap"',
            r'\1"perk_id_lookup"',
            source,
            count=1,
            flags=re.DOTALL,
        )
        assert count == 1
        path.write_text(
            mutated,
            encoding="utf-8",
        )

        report = build_report(root)

    assert "SOLDIER_SHARED_SWAP_CLEANUP_POLICY_MISSING" in _issue_codes(report)


def test_blacksmith_bespoke_icon_path_is_registry_family():
    report = build_report(PROJECT_ROOT)
    blacksmith_infos = [
        issue
        for issue in report.infos
        if issue.code == "BLACKSMITH_BESPOKE_ICON_PATH"
    ]

    assert blacksmith_infos
    assert "hammer_shock" in blacksmith_infos[0].names
