#!/usr/bin/env bash
# WIP 백업 세트 갱신(이동 스냅샷 + C: 번들 + LFS 사이드카 + CURRENT 디스크립터).
#
# 실패 원자성 계약(코덱스 2026-07-14 리뷰 3회 반영):
#   0) 단일 실행 잠금(mkdir 원자성) + trap 분리(EXIT=정리 전용,
#      INT/TERM은 즉시 exit로 승격 — Git Bash에서 'trap f INT'만으로는
#      핸들러 후 실행이 계속되어 잠금 삭제 후 경합이 재현됐음)
#      + 현재 심볼릭 HEAD/브랜치 ref/HEAD oid 3중 고정 검증
#   1) 스냅샷 재생성 — git add 실패는 ref 갱신 전에 중단(오류 삼킴 없음),
#      snapshot^ == HEAD 불변식 검증
#   2) 번들을 임시 이름으로 생성 → verify 통과 후 버전 이름으로 이동
#   3) LFS 커버리지 — 스냅샷 참조 oid 전수 sha256 검증, 불량/미싱은
#      같은 디렉터리 임시 복사 → 해시 검증 → 원자 rename 치유
#   4) manifest는 버전 파일(lfs_manifest_<ts>.txt)로 생성 — 기존 포인터를
#      건드리지 않음
#   5) **단일 디스크립터 CURRENT.txt**(bundle/manifest/snapshot/tip)를
#      모든 단계 성공 후 마지막에 원자 교체 — 중간 실패 시 이전
#      디스크립터가 온전히 유효(신규 버전 파일은 무해한 고아)
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

# --- 0) 단일 실행 잠금 + 트랩 + 브랜치/HEAD 3중 고정 ---
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
SM_TMP=""
cleanup() {
    rm -rf "$LOCK_DIR"
    [ -n "$TMP_INDEX" ] && rm -f "$TMP_INDEX"
    [ -n "$TMP_BUNDLE" ] && rm -f "$TMP_BUNDLE"
    [ -n "$TMP_MANIFEST" ] && rm -f "$TMP_MANIFEST"
    [ -n "$SNAP_OIDS" ] && rm -f "$SNAP_OIDS"
    [ -n "$SIDE_TMP" ] && rm -f "$SIDE_TMP"
    [ -n "$SM_TMP" ] && rm -f "$SM_TMP"
}
# EXIT 트랩은 정리 전용. INT/TERM은 반드시 exit로 승격해야 한다 — Git Bash에서
# 'trap cleanup INT'만 걸면 핸들러 실행 후 본문이 계속 돌며(잠금은 이미 삭제됨)
# 두 번째 실행과 경합하고 그 실행의 잠금까지 지울 수 있다(코덱스 재현).
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

CUR_BRANCH=$(git symbolic-ref --short HEAD)
if [ "$CUR_BRANCH" != "$BRANCH" ]; then
    echo "FATAL: 현재 브랜치($CUR_BRANCH) != 기대 브랜치($BRANCH) — 중단" >&2
    exit 1
fi
TIP=$(git rev-parse HEAD)

assert_tip_stable() {
    local ref_now head_now sym_now
    ref_now=$(git rev-parse "refs/heads/$BRANCH")
    head_now=$(git rev-parse HEAD)
    sym_now=$(git symbolic-ref --short HEAD)
    if [ "$ref_now" != "$TIP" ] || [ "$head_now" != "$TIP" ] || [ "$sym_now" != "$BRANCH" ]; then
        echo "FATAL: 실행 중 HEAD/브랜치 이동(ref=$ref_now head=$head_now sym=$sym_now, 기대 $TIP@$BRANCH) — 중단" >&2
        exit 1
    fi
}

# --- 1) 이동 스냅샷 재생성(임시 인덱스; 작업 인덱스/워크트리 비오염) ---
TMP_INDEX=$(mktemp)
export GIT_INDEX_FILE="$TMP_INDEX"
git read-tree HEAD
# git add 실패(LFS clean 훅, 권한, 디스크 등)는 절대 삼키지 않는다(set -e).
# mcp/.env.save는 gitignore 등재라 -A에 걸리지 않으며, 아래 ls-files로 강제 확인.
git add -A .
if [ "$(git ls-files --cached -- mcp/.env.save | wc -l)" -ne 0 ]; then
    echo "FATAL: mcp/.env.save가 스냅샷 트리에 포함됨 — 중단" >&2
    exit 1
fi
SNAP_COUNT=$(git ls-files --cached | wc -l)
SNAPTREE=$(git write-tree)
unset GIT_INDEX_FILE
assert_tip_stable
SNAP=$(git commit-tree "$SNAPTREE" -p "$TIP" -m "backup: wip-snapshot-current $(date +%Y%m%d-%H%M)${LABEL:+ ($LABEL)}")
git update-ref "$SNAP_REF" "$SNAP"
if [ "$(git rev-parse "$SNAP_REF^")" != "$TIP" ]; then
    echo "FATAL: 스냅샷 불변식 위반(snapshot^ != HEAD)" >&2
    exit 1
fi
echo "snapshot=$SNAP (parent==HEAD OK, files=$SNAP_COUNT)"

# --- 2) 번들: 임시 생성 → verify → 버전 이름으로 이동(no-clobber) ---
# 파일명에 스냅샷 OID 12자리를 포함해 세대를 내용으로 식별한다 — 시계 역행으로
# 같은 타임스탬프가 나와도 다른 세대를 덮지 못하고, 동일 이름 존재는 FATAL.
assert_tip_stable
STAMP=$(date +%Y%m%d_%H%M%S)
GEN="${STAMP}_${SNAP:0:12}"
FINAL_BUNDLE="bosspong_wip_$GEN.bundle"
FINAL_MANIFEST="lfs_manifest_$GEN.txt"
for existing in "$BACKUP_DIR/$FINAL_BUNDLE" "$BACKUP_DIR/$FINAL_MANIFEST"; do
    if [ -e "$existing" ]; then
        echo "FATAL: 세대 파일이 이미 존재($existing) — 시계 역행/중복 실행 의심, 중단" >&2
        exit 1
    fi
done
TMP_BUNDLE="$BACKUP_DIR/.tmp_$FINAL_BUNDLE"
git bundle create "$TMP_BUNDLE" "$BRANCH" backup/wip-snapshot-current --not --remotes
git bundle verify "$TMP_BUNDLE" >/dev/null
# 복원측 대조용: 디스크립터 4필드 vs 번들 heads가 일치해야 한다(아래서 즉시 자가검증).
BUNDLE_SNAP=$(git bundle list-heads "$TMP_BUNDLE" | awk '$2=="refs/heads/backup/wip-snapshot-current"{print $1}')
BUNDLE_TIP=$(git bundle list-heads "$TMP_BUNDLE" | awk -v ref="refs/heads/$BRANCH" '$2==ref{print $1}')
if [ "$BUNDLE_SNAP" != "$SNAP" ] || [ "$BUNDLE_TIP" != "$TIP" ]; then
    echo "FATAL: 번들 heads($BUNDLE_SNAP/$BUNDLE_TIP) != 스냅샷/tip($SNAP/$TIP)" >&2
    exit 1
fi
mv "$TMP_BUNDLE" "$BACKUP_DIR/$FINAL_BUNDLE"
TMP_BUNDLE=""
echo "bundle=$FINAL_BUNDLE (verify+heads OK)"

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

# --- 4) manifest: 버전 파일로 생성(기존 포인터 비접촉) ---
TMP_MANIFEST="$BACKUP_DIR/.tmp_$FINAL_MANIFEST"
{
    echo "# lfs sidecar manifest — $(date +%Y-%m-%d\ %H:%M)"
    echo "# scope: backup/wip-snapshot-current $SNAP (tip $TIP) 참조 oid 전수 sha256 검증 $verified OK / healed $healed"
    echo "# bundle: $FINAL_BUNDLE"
    echo "# total sidecar objects: $(find "$BACKUP_DIR/lfs_objects" -type f | wc -l)"
    cat "$SNAP_OIDS"
} > "$TMP_MANIFEST"
mv "$TMP_MANIFEST" "$BACKUP_DIR/$FINAL_MANIFEST"
TMP_MANIFEST=""

# --- 4.5) source_media 사이드카: 부패 감지 + D: 원본에서 원자 치유 ---
# gitignore(*.mp4)로 스냅샷/번들에 못 들어가는 원본 미디어의 단일 사본 방지.
# 진실 = source_media/MANIFEST.txt의 sha256 기록. 사이드카 해시가 다르면
# D: 원본(stagevideo/<name>)이 기록과 일치할 때만 임시복사→해시→원자 rename.
# fail-closed: MANIFEST 부재/필수 항목 미기재/비정상 해시는 전부 FATAL —
# manifest가 사라지면 verified=0으로 '성공'하는 fail-open을 금지한다.
SM_DIR="$BACKUP_DIR/source_media"
SM_REQUIRED="stage8.mp4"
sm_verified=0
sm_healed=0
if [ ! -f "$SM_DIR/MANIFEST.txt" ]; then
    echo "FATAL: source_media MANIFEST.txt 부재 — 원본 미디어 사이드카 검증 불가, 중단" >&2
    exit 1
fi
for required_name in $SM_REQUIRED; do
    # 정규식 금지 — awk 문자열 '정확' 비교(stage8.mp4의 .이 wildcard가 되어
    # stage8Xmp4가 통과하는 fail-open을 차단).
    if ! awk -v n="$required_name" '$1==n{found=1} END{exit !found}' "$SM_DIR/MANIFEST.txt"; then
        echo "FATAL: source_media MANIFEST에 필수 항목 미기재: $required_name" >&2
        exit 1
    fi
done
# 커밋된 영상 provenance manifest의 source sha와 교차검증 — fail-closed:
# 워크트리 파일이 아니라 방금 만든 '스냅샷 블롭'에서 읽고(백업이 실제로
# 담는 세대와 대조), 부재/추출 0건·2건 이상이면 전부 FATAL.
committed_manifest_json=$(git show "$SNAP:godot/assets/video/stage7_akamu_intro_v1_manifest.json" 2>/dev/null || true)
if [ -z "$committed_manifest_json" ]; then
    echo "FATAL: 스냅샷에 영상 provenance manifest 블롭이 없음 — 교차검증 불가, 중단" >&2
    exit 1
fi
committed_src_sha=$(printf '%s' "$committed_manifest_json" | grep -A2 '"path": "stagevideo/stage8.mp4"' | grep -o '[0-9a-f]\{64\}')
committed_src_count=$(printf '%s
' "$committed_src_sha" | grep -c '[0-9a-f]' || true)
if [ "$committed_src_count" -ne 1 ]; then
    echo "FATAL: 영상 manifest에서 source sha 추출이 정확히 1건이 아님($committed_src_count건)" >&2
    exit 1
fi
sidecar_sha=$(awk '$1=="stage8.mp4"{print $2}' "$SM_DIR/MANIFEST.txt" | awk -F= '$1=="sha256"{print $2}')
if [ "$committed_src_sha" != "$sidecar_sha" ]; then
    echo "FATAL: source_media MANIFEST sha($sidecar_sha) != 스냅샷 영상 manifest source sha($committed_src_sha)" >&2
    exit 1
fi
SM_SEEN=""
{
    while read -r name rest; do
        case "$name" in \#*|"") continue ;; esac
        # 이름 안전성: basename만(경로 분리자·.. 금지) + 허용 문자 + 중복 금지
        case "$name" in
            */*|*\*|*..*)
                echo "FATAL: source_media MANIFEST 항목명에 경로 요소 포함: $name" >&2
                exit 1
                ;;
        esac
        if ! printf '%s' "$name" | grep -Eq '^[A-Za-z0-9._-]+$'; then
            echo "FATAL: source_media MANIFEST 항목명이 허용 문자 밖: $name" >&2
            exit 1
        fi
        case " $SM_SEEN " in
            *" $name "*)
                echo "FATAL: source_media MANIFEST 항목 중복: $name" >&2
                exit 1
                ;;
        esac
        SM_SEEN="$SM_SEEN $name"
        want=$(printf '%s' "$rest" | tr ' ' '
' | awk -F= '$1=="sha256"{print $2}')
        if ! printf '%s' "$want" | grep -Eq '^[0-9a-f]{64}$'; then
            echo "FATAL: source_media MANIFEST 항목의 sha256이 비정상: $name ($want)" >&2
            exit 1
        fi
        dst="$SM_DIR/$name"
        ok=0
        if [ -f "$dst" ] && [ "$(sha256sum "$dst" | awk '{print $1}')" = "$want" ]; then
            ok=1
        fi
        if [ "$ok" -ne 1 ]; then
            src="$REPO/stagevideo/$name"
            if [ -f "$src" ] && [ "$(sha256sum "$src" | awk '{print $1}')" = "$want" ]; then
                SM_TMP=$(mktemp -p "$SM_DIR")
                cp "$src" "$SM_TMP"
                if [ "$(sha256sum "$SM_TMP" | awk '{print $1}')" != "$want" ]; then
                    rm -f "$SM_TMP"
                    echo "FATAL: source_media 치유 복사본 해시 불일치: $name" >&2
                    exit 1
                fi
                mv "$SM_TMP" "$dst"
                SM_TMP=""
                sm_healed=$((sm_healed + 1))
            else
                echo "FATAL: source_media 부패 감지 + D: 원본 불일치/부재: $name" >&2
                exit 1
            fi
        fi
        sm_verified=$((sm_verified + 1))
    done < "$SM_DIR/MANIFEST.txt"
}
required_count=$(printf '%s
' $SM_REQUIRED | wc -l)
if [ "$sm_verified" -lt "$required_count" ]; then
    echo "FATAL: source_media 검증 수($sm_verified) < 필수 수($required_count)" >&2
    exit 1
fi
echo "source_media: verified=$sm_verified healed=$sm_healed"

# --- 5) 단일 디스크립터 CURRENT.txt: 마지막에 원자 교체 ---
assert_tip_stable
{
    echo "bundle=$FINAL_BUNDLE"
    echo "manifest=$FINAL_MANIFEST"
    echo "snapshot=$SNAP"
    echo "tip=$TIP"
    echo "source_media_verified=$sm_verified"
    echo "source_manifest_sha256=$(sha256sum "$SM_DIR/MANIFEST.txt" | awk '{print $1}')"
} > "$BACKUP_DIR/.tmp_CURRENT.txt"
mv "$BACKUP_DIR/.tmp_CURRENT.txt" "$BACKUP_DIR/CURRENT.txt"
echo "CURRENT.txt -> bundle=$FINAL_BUNDLE manifest=$FINAL_MANIFEST"
echo "refresh_wip_backup: ok"
