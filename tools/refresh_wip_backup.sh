#!/usr/bin/env bash
# WIP 백업 세트 갱신(이동 스냅샷 + C: 번들 + LFS 사이드카 + CURRENT 포인터).
#
# 실패 원자성 계약(코덱스 2026-07-14 리뷰 2회 반영):
#   0) 단일 실행 잠금(mkdir 원자성) + EXIT/INT/TERM 트랩 정리
#      + 현재 브랜치/HEAD 고정 검증(중간에 움직이면 중단)
#   1) 스냅샷 재생성 — git add 실패는 삼키지 않고 ref 갱신 전에 중단,
#      스냅샷 트리 파일 수가 HEAD 대비 급감하면(불완전 트리 방어) 중단,
#      snapshot^ == HEAD 불변식 검증
#   2) 번들을 임시 이름으로 생성 → verify 통과 후에만 최종 이름으로 이동
#   3) LFS 커버리지 — 스냅샷 참조 oid를 **전수 sha256 검증**(파일명 존재만으론
#      불충분: 잘린/불일치 파일 검출), 불량·미싱은 로컬 스토어에서
#      같은 디렉터리 임시 파일로 복사 → sha256 검증 → 원자 rename으로 치유,
#      최종 전수 재검증 통과 실패 시 CURRENT 미갱신
#   4) lfs_manifest_current.txt를 임시 파일로 쓰고 이동
#   5) CURRENT_BUNDLE.txt는 모든 단계 성공 후 **마지막에** 원자 교체
#
# 사용: bash tools/refresh_wip_backup.sh ["스냅샷 메시지 접미"]
set -euo pipefail

REPO=/d/main/bosspong
BACKUP_DIR=/c/Users/woduq/bosspong_backups
BRANCH=fix/plaza-lingpet-egg-full-roster-test
SNAP_REF=refs/heads/backup/wip-snapshot-current
LABEL="${1:-}"

cd "$REPO"
unset GIT_INDEX_FILE || true

# --- 0) 단일 실행 잠금 + 트랩 정리 + 브랜치/HEAD 고정 ---
LOCK_DIR="$BACKUP_DIR/.refresh_lock"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    echo "FATAL: 다른 refresh_wip_backup 실행이 잠금 보유 중($LOCK_DIR) — 중단" >&2
    exit 1
fi
TMP_INDEX=""
TMP_BUNDLE=""
TMP_MANIFEST=""
SNAP_OIDS=""
SIDE_TMP=""
cleanup() {
    rm -rf "$LOCK_DIR"
    [ -n "$TMP_INDEX" ] && rm -f "$TMP_INDEX"
    [ -n "$TMP_BUNDLE" ] && rm -f "$TMP_BUNDLE"
    [ -n "$TMP_MANIFEST" ] && rm -f "$TMP_MANIFEST"
    [ -n "$SNAP_OIDS" ] && rm -f "$SNAP_OIDS"
    [ -n "$SIDE_TMP" ] && rm -f "$SIDE_TMP"
}
trap cleanup EXIT INT TERM

CUR_BRANCH=$(git symbolic-ref --short HEAD)
if [ "$CUR_BRANCH" != "$BRANCH" ]; then
    echo "FATAL: 현재 브랜치($CUR_BRANCH) != 기대 브랜치($BRANCH) — 중단" >&2
    exit 1
fi
TIP=$(git rev-parse HEAD)

assert_tip_stable() {
    local now
    now=$(git rev-parse "refs/heads/$BRANCH")
    if [ "$now" != "$TIP" ]; then
        echo "FATAL: 실행 중 브랜치 tip이 이동($TIP -> $now) — 중단" >&2
        exit 1
    fi
}

# --- 1) 이동 스냅샷 재생성(임시 인덱스; 작업 인덱스/워크트리 비오염) ---
TMP_INDEX=$(mktemp)
export GIT_INDEX_FILE="$TMP_INDEX"
git read-tree HEAD
# git add 실패(LFS clean 훅, 권한, 디스크 등)는 절대 삼키지 않는다.
# mcp/.env.save는 gitignore 등재라 -A에 걸리지 않으며, 아래 ls-files로 강제 확인.
git add -A .
if [ "$(git ls-files --cached -- mcp/.env.save | wc -l)" -ne 0 ]; then
    echo "FATAL: mcp/.env.save가 스냅샷 트리에 포함됨 — 중단" >&2
    exit 1
fi
SNAP_COUNT=$(git ls-files --cached | wc -l)
SNAPTREE=$(git write-tree)
unset GIT_INDEX_FILE
HEAD_COUNT=$(git ls-tree -r --name-only HEAD | wc -l)
if [ "$SNAP_COUNT" -lt "$HEAD_COUNT" ]; then
    echo "FATAL: 스냅샷 트리 파일 수($SNAP_COUNT) < HEAD($HEAD_COUNT) — 불완전 트리 의심, 중단" >&2
    exit 1
fi
assert_tip_stable
SNAP=$(git commit-tree "$SNAPTREE" -p "$TIP" -m "backup: wip-snapshot-current $(date +%Y%m%d-%H%M)${LABEL:+ ($LABEL)}")
git update-ref "$SNAP_REF" "$SNAP"
if [ "$(git rev-parse "$SNAP_REF^")" != "$TIP" ]; then
    echo "FATAL: 스냅샷 불변식 위반(snapshot^ != HEAD)" >&2
    exit 1
fi
echo "snapshot=$SNAP (parent==HEAD OK, files=$SNAP_COUNT)"

# --- 2) 번들: 임시 생성 → verify → 최종 이동 ---
assert_tip_stable
FINAL_BUNDLE="bosspong_wip_$(date +%Y%m%d_%H%M%S).bundle"
TMP_BUNDLE="$BACKUP_DIR/.tmp_$FINAL_BUNDLE"
git bundle create "$TMP_BUNDLE" "$BRANCH" backup/wip-snapshot-current --not --remotes
git bundle verify "$TMP_BUNDLE" >/dev/null
mv "$TMP_BUNDLE" "$BACKUP_DIR/$FINAL_BUNDLE"
TMP_BUNDLE=""
echo "bundle=$FINAL_BUNDLE (verify OK)"

# --- 3) LFS 커버리지: 전수 sha256 검증 + 불량/미싱 원자 치유 ---
SNAP_OIDS=$(mktemp)
git lfs ls-files -l backup/wip-snapshot-current | awk '{print $1}' | sort -u > "$SNAP_OIDS"
healed=0
verified=0
while read -r oid; do
    dstdir="$BACKUP_DIR/lfs_objects/${oid:0:2}/${oid:2:2}"
    dst="$dstdir/$oid"
    ok=0
    if [ -f "$dst" ] && [ "$(sha256sum "$dst" | awk '{print $1}')" = "$oid" ]; then
        ok=1
    fi
    if [ "$ok" -ne 1 ]; then
        src=".git/lfs/objects/${oid:0:2}/${oid:2:2}/$oid"
        if [ ! -f "$src" ]; then
            echo "FATAL: 스냅샷 참조 LFS 객체가 로컬 스토어에 없음: $oid" >&2
            exit 1
        fi
        mkdir -p "$dstdir"
        SIDE_TMP=$(mktemp -p "$dstdir")
        cp "$src" "$SIDE_TMP"
        if [ "$(sha256sum "$SIDE_TMP" | awk '{print $1}')" != "$oid" ]; then
            echo "FATAL: 복사본 sha256 불일치(소스 손상 의심): $oid" >&2
            exit 1
        fi
        mv "$SIDE_TMP" "$dst"
        SIDE_TMP=""
        healed=$((healed + 1))
    fi
    verified=$((verified + 1))
done < "$SNAP_OIDS"
echo "lfs: verified=$verified healed=$healed missing=0 (전수 sha256)"

# --- 4) LFS manifest 임시 작성 → 이동 ---
TMP_MANIFEST="$BACKUP_DIR/.tmp_lfs_manifest.txt"
{
    echo "# lfs sidecar manifest — $(date +%Y-%m-%d\ %H:%M)"
    echo "# scope: backup/wip-snapshot-current $SNAP (tip $TIP) 참조 oid 전수 sha256 검증 $verified OK / healed $healed"
    echo "# bundle: $FINAL_BUNDLE"
    echo "# total sidecar objects: $(find "$BACKUP_DIR/lfs_objects" -type f | wc -l)"
    cat "$SNAP_OIDS"
} > "$TMP_MANIFEST"
mv "$TMP_MANIFEST" "$BACKUP_DIR/lfs_manifest_current.txt"
TMP_MANIFEST=""

# --- 5) CURRENT 포인터: 마지막에 원자 교체 ---
assert_tip_stable
printf '%s\n' "$FINAL_BUNDLE" > "$BACKUP_DIR/.tmp_CURRENT_BUNDLE.txt"
mv "$BACKUP_DIR/.tmp_CURRENT_BUNDLE.txt" "$BACKUP_DIR/CURRENT_BUNDLE.txt"
echo "CURRENT_BUNDLE.txt -> $FINAL_BUNDLE"
echo "refresh_wip_backup: ok"
