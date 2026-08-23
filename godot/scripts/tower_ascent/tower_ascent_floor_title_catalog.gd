extends RefCounted

# 피드백2 9항: 층 진입(구름 걷힘) 시 디아블로식 구역 타이틀에 쓰는 층 이름
# 정본. 2~4층은 기존 스테이지 랜딩 부제 재사용, 12층은 사용자 문구이며
# 전체 12층 판은 2026-08-24 사용자 확정본이다. 카피 개정은 이 파일 한
# 곳에서만 한다. 한국어 우선 등재이며 다국어 확산은 지도 오버레이
# 로컬라이제이션과 같은 백로그를 따른다.
const FLOOR_TITLES := {
	1: "홍진 어귀",
	2: "봉인된 용소",
	3: "환몽인형각",
	4: "소림사",
	5: "홍련각",
	6: "만상기관",
	7: "명부 그늘길",
	8: "흑뢰 미궁",
	9: "무너진 신전",
	10: "선계 초문",
	11: "사천왕 운교",
	12: "천당의 신로",
}

const TITLE_FADE_IN_END := 0.16
const TITLE_HOLD_END := 0.78


static func floor_title(floor_number: int) -> String:
	return str(FLOOR_TITLES.get(floor_number, ""))


static func floor_label(floor_number: int) -> String:
	return "%d층" % maxi(1, floor_number)


static func title_alpha(progress: float) -> float:
	# The reveal owns a single 0..1 progress; the title fades in fast, holds
	# through the cloud fade, then leaves before the reveal completes so the
	# freshly revealed nodes get the final beat to themselves.
	var t := clampf(progress, 0.0, 1.0)
	if t < TITLE_FADE_IN_END:
		return t / TITLE_FADE_IN_END
	if t <= TITLE_HOLD_END:
		return 1.0
	return clampf(1.0 - (t - TITLE_HOLD_END) / (1.0 - TITLE_HOLD_END), 0.0, 1.0)
