#!/usr/bin/env bash
# WIP 백업 세트 갱신(이동 스냅샷 + C: 번들 + LFS 사이드카 + CURRENT 포인터).
#
# 실패 원자성 계약(코덱스 2026-07-14 리뷰):
#   1) 스냅샷 재생성 → snapshot^ == HEAD 불변식 검증
#   2) 번들을 임시 이름으로 생성 → verify 통과 후에만 최종 이름으로 이동
#   3) LFS 커버리지: 스냅샷 참조 oid 중 사이드카 미싱분을 sha256 검증 복사,
#      재계산 missing=0 강제(실패 시 CURRENT는 갱신되지 않음)
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

# --- 1) 이동 스냅샷 재생성(임시 인덱스; 작업 인덱스/워크트리 비오염) ---
TMP_INDEX=$(mktemp)
export GIT_INDEX_FILE="$TMP_INDEX"
git read-tree HEAD
git add -A -- . ':!mcp/.env.save' >/dev/null 2>&1 || true
if [ "$(git ls-files --cached -- mcp/.env.save | wc -l)" -ne 0 ]; then
    echo "FATAL: mcp/.env.save가 스냅샷 트리에 포함됨 — 중단" >&2
    exit 1
fi
SNAPTREE=$(git write-tree)
SNAP=$(git commit-tree "$SNAPTREE" -p HEAD -m "backup: wip-snapshot-current $(date +%Y%m%d-%H%M)${LABEL:+ ($LABEL)}")
unset GIT_INDEX_FILE
rm -f "$TMP_INDEX"
git update-ref "$SNAP_REF" "$SNAP"

TIP=$(git rev-parse HEAD)
if [ "$(git rev-parse "$SNAP_REF^")" != "$TIP" ]; then
    echo "FATAL: 스냅샷 불변식 위반(snapshot^ != HEAD)" >&2
    exit 1
fi
echo "snapshot=$SNAP (parent==HEAD OK)"

# --- 2) 번들: 임시 생성 → verify → 최종 이동 ---
FINAL_BUNDLE="bosspong_wip_$(date +%Y%m%d_%H%M%S).bundle"
TMP_BUNDLE="$BACKUP_DIR/.tmp_$FINAL_BUNDLE"
git bundle create "$TMP_BUNDLE" "$BRANCH" backup/wip-snapshot-current --not --remotes
git bundle verify "$TMP_BUNDLE" >/dev/null
mv "$TMP_BUNDLE" "$BACKUP_DIR/$FINAL_BUNDLE"
echo "bundle=$FINAL_BUNDLE (verify OK)"

# --- 3) LFS 커버리지: 미싱 복사(sha256 검증) → missing=0 강제 ---
SNAP_OIDS=$(mktemp)
SIDE_OIDS=$(mktemp)
git lfs ls-files -l backup/wip-snapshot-current | awk '{print $1}' | sort -u > "$SNAP_OIDS"
find "$BACKUP_DIR/lfs_objects" -type f -printf '%f\n' | sort -u > "$SIDE_OIDS"
copied=0
while read -r oid; do
    src=".git/lfs/objects/${oid:0:2}/${oid:2:2}/$oid"
    if [ ! -f "$src" ]; then
        echo "FATAL: 스냅샷 참조 LFS 객체가 로컬 스토어에 없음: $oid" >&2
        exit 1
    fi
    dstdir="$BACKUP_DIR/lfs_objects/${oid:0:2}/${oid:2:2}"
    mkdir -p "$dstdir"
    cp "$src" "$dstdir/$oid"
    if [ "$(sha256sum "$dstdir/$oid" | awk '{print $1}')" != "$oid" ]; then
        echo "FATAL: 복사본 sha256 불일치: $oid" >&2
        exit 1
    fi
    copied=$((copied + 1))
done < <(comm -23 "$SNAP_OIDS" "$SIDE_OIDS")
find "$BACKUP_DIR/lfs_objects" -type f -printf '%f\n' | sort -u > "$SIDE_OIDS"
missing=$(comm -23 "$SNAP_OIDS" "$SIDE_OIDS" | wc -l)
if [ "$missing" -ne 0 ]; then
    echo "FATAL: LFS 커버리지 미싱 $missing건 — CURRENT 미갱신" >&2
    exit 1
fi
echo "lfs: copied=$copied missing=0 (total sidecar=$(wc -l < "$SIDE_OIDS"))"

# --- 4) LFS manifest 임시 작성 → 이동 ---
TMP_MANIFEST="$BACKUP_DIR/.tmp_lfs_manifest.txt"
{
    echo "# lfs sidecar manifest — $(date +%Y-%m-%d\ %H:%M)"
    echo "# scope: backup/wip-snapshot-current $SNAP (tip $TIP) 참조 oid 전량 커버(missing 0)"
    echo "# bundle: $FINAL_BUNDLE"
    echo "# total objects: $(wc -l < "$SIDE_OIDS")"
    cat "$SIDE_OIDS"
} > "$TMP_MANIFEST"
mv "$TMP_MANIFEST" "$BACKUP_DIR/lfs_manifest_current.txt"

# --- 5) CURRENT 포인터: 마지막에 원자 교체 ---
printf '%s\n' "$FINAL_BUNDLE" > "$BACKUP_DIR/.tmp_CURRENT_BUNDLE.txt"
mv "$BACKUP_DIR/.tmp_CURRENT_BUNDLE.txt" "$BACKUP_DIR/CURRENT_BUNDLE.txt"
rm -f "$SNAP_OIDS" "$SIDE_OIDS"
echo "CURRENT_BUNDLE.txt -> $FINAL_BUNDLE"
echo "refresh_wip_backup: ok"
