#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
PingFighter 아이템 검증 도구 (Item Validator)
==============================================
새 아이템 추가 시 필수 체크리스트를 자동으로 검증합니다.

사용법:
    python tools/item_validator.py                    # 전체 검증
    python tools/item_validator.py --item speedboots  # 특정 아이템만 검증
    python tools/item_validator.py --legendary        # 전설 아이템만 검증
    python tools/item_validator.py --passive          # 패시브 아이템만 검증
    python tools/item_validator.py --check            # 시스템 간 불일치만 확인
    python tools/item_validator.py --list             # 아이템 목록 출력
"""

import os
import re
import sys
import io
import argparse
from pathlib import Path
from typing import Dict, List, Set
from dataclasses import dataclass, field

# Windows 콘솔 UTF-8 출력 강제
if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace")

# 프로젝트 루트 경로
PROJECT_ROOT = Path(__file__).parent.parent
ITEMS_PY = PROJECT_ROOT / "items.py"
PINGFIGHTER_PY = PROJECT_ROOT / "pingfighter.py"
LEGENDARY_ITEMS_PY = PROJECT_ROOT / "legendary_items.py"
ICONS_DIR = PROJECT_ROOT / "items"


@dataclass
class ValidationResult:
    """검증 결과"""
    item_name: str
    passed: List[str] = field(default_factory=list)
    failed: List[str] = field(default_factory=list)
    warnings: List[str] = field(default_factory=list)

    @property
    def is_valid(self) -> bool:
        return len(self.failed) == 0


class ItemValidator:
    """PingFighter 아이템 시스템 검증기"""

    KNOWN_LEGENDARY = {
        "ragnarok_hammer", "hermes_shoes", "poseidon_trident",
        "angel_blessing", "sacred_laurel", "transcendent_crown", "odins_eye"
    }

    def __init__(self):
        self.items_src = ""
        self.pf_src = ""
        self.legend_src = ""
        self._load_files()

        # 파싱 결과
        self.item_types_names: Set[str] = set()
        self.unlocked_items: Set[str] = set()
        self.passive_dup_allowed: Set[str] = set()
        self.obtained_flags: Set[str] = set()
        self.update_items_passives: Set[str] = set()
        self.store_active_filter: Set[str] = set()
        self.korean_names: Set[str] = set()
        self.descriptions: Set[str] = set()
        self.icon_legendaries: Set[str] = set()
        self.roll_options: Set[str] = set()
        self.manager_items: Set[str] = set()
        self.store_passive_handled: Set[str] = set()

        self._parse_all()

    def _load_files(self):
        for attr, path in [("items_src", ITEMS_PY), ("pf_src", PINGFIGHTER_PY), ("legend_src", LEGENDARY_ITEMS_PY)]:
            try:
                with open(path, "r", encoding="utf-8") as f:
                    setattr(self, attr, f.read())
            except FileNotFoundError:
                if attr != "legend_src":
                    print(f"  파일 없음: {path}")
                    sys.exit(1)

    def _extract_names(self, text: str, pattern: str, flags=0) -> Set[str]:
        match = re.search(pattern, text, flags)
        if match:
            return set(re.findall(r'"([^"]+)"', match.group(1)))
        return set()

    def _parse_all(self):
        # --- items.py ---
        # ITEM_TYPES의 "name" 필드
        self.item_types_names = set(re.findall(r'"name"\s*:\s*"([^"]+)"', self.items_src))

        # unlocked_items
        self.unlocked_items = self._extract_names(
            self.items_src, r'unlocked_items\s*=\s*\{([^}]+)\}', re.DOTALL)

        # PASSIVE_DUPLICATE_ALLOWED
        self.passive_dup_allowed = self._extract_names(
            self.items_src, r'PASSIVE_DUPLICATE_ALLOWED\s*=\s*\{([^}]+)\}', re.DOTALL)

        # obtained 플래그
        self.obtained_flags = set(re.findall(r'^([a-z_]+)_obtained\s*=\s*False', self.items_src, re.MULTILINE))

        # update_items() 내 패시브 목록 (item_name in [...])
        for match in re.findall(r'if\s+item_name\s+in\s+\[([^\]]+)\]', self.items_src):
            names = re.findall(r'"([^"]+)"', match)
            if len(names) > 5:  # 패시브 목록은 보통 많은 아이템 포함
                self.update_items_passives.update(names)

        # --- pingfighter.py ---
        # store_active_item() 패시브 필터
        func_match = re.search(r'def\s+store_active_item.*?(?=\ndef\s)', self.pf_src, re.DOTALL)
        if func_match:
            block = func_match.group(0)[:8000]
            for m in re.findall(r'if\s+item_data\["name"\]\s+in\s+\[([^\]]+)\]', block):
                self.store_active_filter.update(re.findall(r'"([^"]+)"', m))

        # store_passive_item() 처리되는 아이템 목록
        func_match = re.search(r'def\s+store_passive_item.*?(?=\ndef\s)', self.pf_src, re.DOTALL)
        if func_match:
            block = func_match.group(0)
            self.store_passive_handled = set(
                re.findall(r'item_data\["name"\]\s*==\s*"([^"]+)"', block))

        # korean_names 딕셔너리
        for m in re.findall(r'korean_names\s*=\s*\{([^}]+)\}', self.pf_src, re.DOTALL):
            self.korean_names.update(re.findall(r'"([^"]+)"\s*:', m))

        # descriptions 딕셔너리
        for m in re.findall(r'descriptions\s*=\s*\{([^}]+)\}', self.pf_src, re.DOTALL):
            self.descriptions.update(re.findall(r'"([^"]+)"\s*:', m))

        # get_item_icon() 전설 아이템 목록
        for m in re.findall(r'if\s+item_name\s+in\s+\[([^\]]*(?:hermes_shoes|ragnarok_hammer)[^\]]*)\]', self.pf_src):
            self.icon_legendaries.update(re.findall(r'"([^"]+)"', m))

        # --- legendary_items.py ---
        # LEGENDARY_ROLL_OPTIONS 키
        self.roll_options = set(re.findall(r'"([a-z_]+)"\s*:\s*\[', self.legend_src))
        # LegendaryItemManager에 등록된 아이템
        self.manager_items = set(re.findall(r'self\.items\["([^"]+)"\]\s*=', self.legend_src))

    # --- 검증 ---

    def validate_item(self, name: str) -> ValidationResult:
        r = ValidationResult(name)
        is_p = name in self.update_items_passives
        is_l = name in self.KNOWN_LEGENDARY

        # 공통 체크
        self._check(r, name in self.item_types_names,
                     "items.py ITEM_TYPES 등록",
                     "items.py ITEM_TYPES에 등록 필요")
        self._check(r, name in self.unlocked_items,
                     "items.py unlocked_items 등록",
                     "items.py unlocked_items에 등록 필요")
        self._check(r, name in self.korean_names,
                     "get_item_name_korean() 한글 이름 등록",
                     "get_item_name_korean()에 한글 이름 추가 필요")
        self._check(r, name in self.descriptions,
                     "get_item_description() 설명 등록",
                     "get_item_description()에 설명 추가 필요")

        # 아이콘
        icon_exists = (ICONS_DIR / f"{name}.png").exists()
        if icon_exists:
            r.passed.append("✓ items/" + name + ".png 아이콘 존재")
        else:
            r.warnings.append("⚠ items/" + name + ".png 아이콘 없음")

        # 패시브/전설 전용
        if is_p or is_l:
            self._check(r, name in self.update_items_passives,
                         "update_items() 패시브 목록 등록",
                         "items.py update_items() 패시브 목록에 추가 필요")
            self._check(r, name in self.store_active_filter,
                         "store_active_item() 필터 등록",
                         "pingfighter.py store_active_item() 필터에 추가 필요")
            self._check(r, name in self.obtained_flags,
                         f"{name}_obtained 플래그 존재",
                         f"items.py에 {name}_obtained = False 추가 필요")
            self._check(r, name in self.store_passive_handled,
                         "store_passive_item() 처리 로직 존재",
                         "pingfighter.py store_passive_item()에 처리 블록 추가 필요")

        # 전설 전용
        if is_l:
            self._check(r, name in self.passive_dup_allowed,
                         "PASSIVE_DUPLICATE_ALLOWED 등록",
                         "items.py PASSIVE_DUPLICATE_ALLOWED에 추가 필요")
            self._check(r, name in self.icon_legendaries,
                         "get_item_icon() 전설 목록 등록",
                         "pingfighter.py get_item_icon() 전설 목록에 추가 필요")
            self._check(r, name in self.roll_options,
                         "LEGENDARY_ROLL_OPTIONS 등록",
                         "legendary_items.py LEGENDARY_ROLL_OPTIONS에 롤 옵션 추가 필요")
            self._check(r, name in self.manager_items,
                         "LegendaryItemManager에 등록",
                         "legendary_items.py LegendaryItemManager에 인스턴스 추가 필요")

        return r

    def _check(self, r: ValidationResult, condition: bool, pass_msg: str, fail_msg: str):
        if condition:
            r.passed.append("✓ " + pass_msg)
        else:
            r.failed.append("✗ " + fail_msg)

    def find_inconsistencies(self) -> Dict[str, List[str]]:
        """시스템 간 불일치 탐지"""
        issues: Dict[str, List[str]] = {}

        # 패시브 목록 vs store_active 필터
        diff1 = self.update_items_passives - self.store_active_filter
        diff2 = self.store_active_filter - self.update_items_passives
        if diff1 or diff2:
            msgs = []
            for n in diff1:
                msgs.append(f"  store_active_item 필터에 누락: {n}")
            for n in diff2:
                msgs.append(f"  update_items 패시브 목록에 누락: {n}")
            issues["패시브 목록 ↔ store_active 필터 불일치"] = msgs

        # unlocked_items 누락
        missing = self.item_types_names - self.unlocked_items
        if missing:
            issues["unlocked_items 누락"] = [f"  {n}" for n in sorted(missing)]

        # 한글 이름 누락
        missing = self.item_types_names - self.korean_names
        if missing:
            issues["한글 이름 누락"] = [f"  {n}" for n in sorted(missing)]

        # 설명 누락
        missing = self.item_types_names - self.descriptions
        if missing:
            issues["아이템 설명 누락"] = [f"  {n}" for n in sorted(missing)]

        # 전설 아이템 get_item_icon 누락
        missing = self.KNOWN_LEGENDARY - self.icon_legendaries
        if missing:
            issues["전설 get_item_icon 누락"] = [f"  {n}" for n in sorted(missing)]

        # 전설 아이템 PASSIVE_DUPLICATE_ALLOWED 누락
        missing = self.KNOWN_LEGENDARY - self.passive_dup_allowed
        if missing:
            issues["전설 PASSIVE_DUPLICATE_ALLOWED 누락"] = [f"  {n}" for n in sorted(missing)]

        return issues


# ── 출력 ──

def print_result(r: ValidationResult, verbose: bool = False):
    is_leg = r.item_name in ItemValidator.KNOWN_LEGENDARY
    tag = " [전설]" if is_leg else ""
    icon = "✅" if r.is_valid else "❌"

    print(f"\n{icon} {r.item_name}{tag}")
    print("-" * 50)

    if verbose or not r.is_valid:
        for m in r.passed:
            print(f"  {m}")
        for m in r.failed:
            print(f"  {m}")
        for m in r.warnings:
            print(f"  {m}")
    else:
        print(f"  통과: {len(r.passed)}, 실패: {len(r.failed)}, 경고: {len(r.warnings)}")


def main():
    parser = argparse.ArgumentParser(description="PingFighter 아이템 검증 도구")
    parser.add_argument("--item", "-i", help="특정 아이템만 검증")
    parser.add_argument("--legendary", "-l", action="store_true", help="전설 아이템만")
    parser.add_argument("--passive", "-p", action="store_true", help="패시브 아이템만")
    parser.add_argument("--check", "-c", action="store_true", help="불일치만 확인")
    parser.add_argument("--verbose", "-v", action="store_true", help="상세 출력")
    parser.add_argument("--list", action="store_true", help="아이템 목록 출력")
    args = parser.parse_args()

    print("=" * 60)
    print("  PingFighter 아이템 검증 도구")
    print("=" * 60)

    v = ItemValidator()

    # --list
    if args.list:
        all_n = sorted(v.item_types_names)
        leg = v.KNOWN_LEGENDARY
        pas = v.update_items_passives
        print(f"\n전체: {len(all_n)}개  |  전설: {len(leg)}개  |  패시브: {len(pas - leg)}개  |  액티브: {len(set(all_n) - pas)}개")
        print("\n[전설]")
        for n in sorted(leg):
            print(f"  {n}")
        print("\n[패시브]")
        for n in sorted(pas - leg):
            print(f"  {n}")
        print("\n[액티브]")
        for n in sorted(set(all_n) - pas):
            print(f"  {n}")
        return

    # --check
    if args.check:
        issues = v.find_inconsistencies()
        if not issues:
            print("\n✅ 불일치 없음!")
        else:
            for cat, msgs in issues.items():
                print(f"\n⚠  {cat}:")
                for m in msgs:
                    print(m)
        return

    # --item
    if args.item:
        r = v.validate_item(args.item)
        print_result(r, verbose=True)
        return

    # 대상 결정
    if args.legendary:
        targets = sorted(v.KNOWN_LEGENDARY)
    elif args.passive:
        targets = sorted(v.update_items_passives)
    else:
        targets = sorted(v.item_types_names)

    results = [v.validate_item(n) for n in targets]
    failed = [r for r in results if not r.is_valid]
    ok = [r for r in results if r.is_valid]

    if failed:
        print(f"\n--- 실패 ({len(failed)}개) ---")
        for r in failed:
            print_result(r, verbose=True)

    if args.verbose and ok:
        print(f"\n--- 통과 ({len(ok)}개) ---")
        for r in ok:
            print_result(r, verbose=True)

    # 요약
    print("\n" + "=" * 60)
    print(f"  전체: {len(results)}  |  ✅ 통과: {len(ok)}  |  ❌ 실패: {len(failed)}")
    print("=" * 60)

    # 전체 모드에서는 불일치도 표시
    if not (args.legendary or args.passive):
        issues = v.find_inconsistencies()
        if issues:
            print()
            for cat, msgs in issues.items():
                print(f"⚠  {cat}:")
                for m in msgs:
                    print(m)


if __name__ == "__main__":
    main()
