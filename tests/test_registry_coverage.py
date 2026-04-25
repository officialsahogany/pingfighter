from pathlib import Path

from tools.registry_coverage import build_report, format_issues


PROJECT_ROOT = Path(__file__).resolve().parents[1]


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


def test_optimus_is_the_only_cooldown_reduction_schema_opt_out():
    report = build_report(PROJECT_ROOT)

    assert report.counts["skills.optimus_cooldown_reduction_ineligible_ids"] == 9
    assert report.counts["skills.non_optimus_cooldown_reduction_ineligible_ids"] == 0


def test_blacksmith_bespoke_icon_path_is_registry_family():
    report = build_report(PROJECT_ROOT)
    blacksmith_infos = [
        issue
        for issue in report.infos
        if issue.code == "BLACKSMITH_BESPOKE_ICON_PATH"
    ]

    assert blacksmith_infos
    assert "hammer_shock" in blacksmith_infos[0].names
