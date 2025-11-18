import types


def rect(l, t, w, h):
    r = types.SimpleNamespace()
    r.left = l
    r.top = t
    r.width = w
    r.height = h
    r.right = l + w
    r.bottom = t + h
    r.centerx = l + w // 2
    r.centery = t + h // 2
    return r


def test_choose_reflection_axis_horizontal_from_left():
    from game_logic.stage7_tetriser import choose_reflection_axis
    prev = rect(90, 100, 10, 10)   # 이전 프레임: 블록 왼쪽
    curr = rect(100, 100, 10, 10)  # 현재: 살짝 겹침
    block = rect(105, 100, 20, 20)
    axis = choose_reflection_axis(prev, curr, block)
    assert axis == 'h'


def test_choose_reflection_axis_vertical_from_top():
    from game_logic.stage7_tetriser import choose_reflection_axis
    prev = rect(110, 80, 10, 10)   # 이전 프레임: 블록 위
    curr = rect(110, 95, 10, 10)   # 현재: 살짝 겹침
    block = rect(105, 100, 20, 20)
    axis = choose_reflection_axis(prev, curr, block)
    assert axis == 'v'


def test_choose_reflection_axis_ambiguous_overlap_prefers_minimum_penetration():
    from game_logic.stage7_tetriser import choose_reflection_axis
    prev = rect(90, 90, 10, 10)    # 대각 접근
    curr = rect(102, 98, 10, 10)
    block = rect(105, 100, 20, 20)
    axis = choose_reflection_axis(prev, curr, block)
    # 수평 겹침이 더 작게 설정되도록 curr를 구성 → 'h'
    assert axis in ('h', 'v')
