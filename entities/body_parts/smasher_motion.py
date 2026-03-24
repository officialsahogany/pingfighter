"""
SmasherMotionProfile — 스매셔 캐릭터 전용 모션.

원본: pingfighter.py create_smasher_paddle_surface() 내 모션 계산 코드
- idle/walk: torso_bob, arm_swing, shoulder_shift, hip_sway, leg_lift
- hit_pose: 왼팔 히트 포즈 (공 타격 시)
- shield_raise: 오른팔 방패 들기 (오른쪽 타격 시)
- left_raise: 왼팔 들어올리기 (왼쪽 타격 시)
"""

import math
from entities.player_skeleton import MotionProfile


class SmasherMotionProfile(MotionProfile):
    """스매셔 — 묵직하고 안정적인 메카 모션.

    특징:
    - 걷기: 낮은 바운스, 작은 팔 스윙, 넓은 보폭
    - 타격: 큰 백스윙 + 강한 손목 스냅
    - 방패: 오른팔을 높이 들어올려 정면 방어
    """

    def get_idle_pose(self, phase: float) -> dict[str, float]:
        """대기 상태: 묵직한 메카 호흡 모션.

        투기장 영웅들처럼 가만히 서 있어도 숨쉬는 듯한 움직임.
        느린 주기(1.2초)로 상체가 미세하게 오르내리고,
        팔과 어깨가 약간씩 흔들리며, 방패 팔은 살짝 긴장감을 유지.
        """
        # 느린 호흡 (메인 웨이브)
        breath = math.sin(phase * math.tau)
        # 미세한 2차 흔들림 (비대칭 느낌)
        sway = math.sin(phase * math.tau * 1.7 + 0.5)

        return {
            # 상체 호흡: 위아래 미세 움직임
            "torso": breath * 1.2,
            "neck": breath * 0.4,
            "head": -breath * 0.6 + sway * 0.3,   # 머리 보정 + 약간의 좌우

            # 어깨/팔: 호흡에 따라 미세하게 오르내림
            "l_shoulder": breath * 1.5 + sway * 0.5,    # 왼팔 (탁구채) 약간 흔들림
            "l_elbow": -breath * 0.8,
            "r_shoulder": -breath * 1.2 + sway * 0.3,   # 오른팔 (방패) 살짝 긴장
            "r_elbow": breath * 0.5,

            # 다리: 체중이동 느낌 (미세)
            "l_hip": sway * 0.4,
            "r_hip": -sway * 0.4,
        }

    def get_walk_pose(self, phase: float) -> dict[str, float]:
        """걷기/이동: 묵직한 메카 보행.

        원본 변수 매핑:
        - torso_bob = sin(phase) * 2
        - arm_swing = sin(phase) * 5
        - shoulder_shift = sin(phase) * 2
        - hip_sway = sin(phase) * 2
        - left_leg_lift = -max(0, wave) * 4
        - right_leg_lift = -max(0, -wave) * 4
        """
        wave = math.sin(phase * math.tau)

        # 관절 회전으로 변환 (기존 픽셀 오프셋 → 각도 근사)
        # arm_swing 5px ≈ 어깨 기준 약 12도 회전
        # leg_lift 4px ≈ 힙 기준 약 8도 회전
        return {
            # 상체
            "torso": wave * 1.5,             # 상체 좌우 미세 틸트
            "head": -wave * 1.0,             # 머리 보정
            "neck": wave * 0.5,

            # 어깨/팔 스윙
            "l_shoulder": wave * 12.0,       # 왼팔 전후 스윙
            "l_elbow": wave * 3.0,
            "r_shoulder": -wave * 12.0,      # 오른팔 (반대 방향)
            "r_elbow": -wave * 3.0,

            # 다리 교차 리프트
            "l_hip": -max(0.0, wave) * 8.0,    # 왼다리 들어올리기
            "l_knee": max(0.0, wave) * 12.0,   # 무릎 굽히기
            "r_hip": -max(0.0, -wave) * 8.0,   # 오른다리 (교차)
            "r_knee": max(0.0, -wave) * 12.0,
        }

    def get_hit_pose(self, progress: float) -> dict[str, float]:
        """타격 포즈: 왼팔로 강한 스매시.

        progress: 0(타격 직후) → 1(복귀 완료)
        원본: hit_pose_ratio 기반, 어깨 55도 + 팔꿈치 38도 회전.
        """
        # 타격 강도 (시작이 가장 강하고 서서히 복귀)
        strength = max(0.0, min(1.0, 1.0 - progress))
        ease = strength ** 0.7  # ease-out

        return {
            # 왼팔: 큰 백스윙 → 포워드 스윙
            "l_shoulder": -55.0 * ease,      # 어깨 뒤로
            "l_elbow": -38.0 * ease,         # 팔꿈치 접기
            "l_wrist": 20.0 * ease,          # 손목 스냅

            # 상체: 약간 뒤틀림
            "torso": 8.0 * ease,
            "head": -5.0 * ease,             # 고개 살짝 숙임
        }

    def get_shield_raise_pose(self, strength: float) -> dict[str, float]:
        """방패 들기: 오른팔을 위로 들어 정면 방어.

        strength: 0(내림) → 1(최대 들어올림)
        원본: shield_raise_strength 기반, 어깨 -62도 + 팔꿈치 -85도.
        """
        ease = strength ** 0.7

        return {
            # 오른팔: 위로 들어올림
            "r_shoulder": -62.0 * ease,
            "r_elbow": -85.0 * ease,
            "r_wrist": -20.0 * ease,
        }

    def get_left_raise_pose(self, strength: float) -> dict[str, float]:
        """왼팔 들어올리기: 왼쪽 타격 시 왼팔 방어.

        strength: 0(내림) → 1(최대)
        원본: left_raise_strength 기반, 어깨 78도 + 팔꿈치 92도.
        """
        ease = strength ** 0.7

        return {
            "l_shoulder": 78.0 * ease,
            "l_elbow": 92.0 * ease,
            "l_wrist": 30.0 * ease,
        }

    def get_dash_pose(self, progress: float, direction: int) -> dict[str, float]:
        """대시 포즈: 이동 방향으로 몸을 기울임.

        direction: -1(좌), 1(우)
        """
        lean = 15.0 * direction * (1.0 - progress)  # 시작이 최대, 서서히 복귀
        return {
            "torso": lean,
            "head": -lean * 0.5,             # 머리 보정
            "l_shoulder": lean * 0.8,
            "r_shoulder": lean * 0.8,
        }
