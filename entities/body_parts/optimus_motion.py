"""
OptimusMotionProfile — 옵티머스 캐릭터 전용 모션.

원본: pingfighter.py _create_mecha_paddle_surface() 내 모션 변수
- stride = sin(phase * tau)
- torso_bob = sin(phase * tau * 2) * 6
- sway = sin(phase * tau * 0.5) * 4
- arm_swing = stride * 12

옵티머스는 스매셔보다 크고 묵직한 메카로, 보폭이 좁고 상체 흔들림이 큼.
"""

import math
from entities.player_skeleton import MotionProfile


class OptimusMotionProfile(MotionProfile):
    """옵티머스 — 거대한 메카 로봇의 중후한 모션.

    특징:
    - 걷기: 큰 상체 바운스(torso_bob), 느린 팔 스윙
    - 타격: 빠른 좌팔 스윙 (전자 탁구채)
    - 대시: 몸체 기울기 + 추진기 가속
    """

    def get_idle_pose(self, phase: float) -> dict[str, float]:
        """대기 상태: 에너지 코어 맥동에 맞춘 호흡 모션."""
        breath = math.sin(phase * math.tau)
        sway = math.sin(phase * math.tau * 1.5 + 0.5)

        return {
            "torso": breath * 1.5,
            "neck": breath * 0.3,
            "head": -breath * 0.5 + sway * 0.2,

            "l_shoulder": breath * 1.2 + sway * 0.4,
            "l_elbow": -breath * 0.6,
            "r_shoulder": -breath * 1.0 + sway * 0.3,
            "r_elbow": breath * 0.4,

            "l_hip": sway * 0.3,
            "r_hip": -sway * 0.3,
        }

    def get_walk_pose(self, phase: float) -> dict[str, float]:
        """걷기/이동: 묵직한 메카 보행 + torso_bob.

        hip의 local_y를 직접 수정하는 대신, 각 바디 파츠에서
        phase를 통해 torso_bob을 계산한다.
        """
        wave = math.sin(phase * math.tau)

        return {
            "torso": wave * 2.0,
            "head": -wave * 1.2,
            "neck": wave * 0.6,

            "l_shoulder": wave * 14.0,
            "l_elbow": wave * 4.0,
            "r_shoulder": -wave * 14.0,
            "r_elbow": -wave * 4.0,

            "l_hip": -max(0.0, wave) * 6.0,
            "l_knee": max(0.0, wave) * 10.0,
            "r_hip": -max(0.0, -wave) * 6.0,
            "r_knee": max(0.0, -wave) * 10.0,
        }

    def get_hit_pose(self, progress: float) -> dict[str, float]:
        """타격 포즈: 왼팔로 전자 탁구채 스매시."""
        strength = max(0.0, min(1.0, 1.0 - progress))
        ease = strength ** 0.7

        return {
            "l_shoulder": -50.0 * ease,
            "l_elbow": -35.0 * ease,
            "l_wrist": 18.0 * ease,
            "torso": 6.0 * ease,
            "head": -4.0 * ease,
        }

    def get_shield_raise_pose(self, strength: float) -> dict[str, float]:
        """오른팔 들기 (강철 주먹 가드)."""
        ease = strength ** 0.7

        return {
            "r_shoulder": -55.0 * ease,
            "r_elbow": -80.0 * ease,
            "r_wrist": -15.0 * ease,
        }

    def get_left_raise_pose(self, strength: float) -> dict[str, float]:
        """왼팔 들어올리기."""
        ease = strength ** 0.7

        return {
            "l_shoulder": 72.0 * ease,
            "l_elbow": 88.0 * ease,
            "l_wrist": 25.0 * ease,
        }

    def get_dash_pose(self, progress: float, direction: int) -> dict[str, float]:
        """대시: 추진기 가속 방향으로 기울임."""
        lean = 12.0 * direction * (1.0 - progress)
        return {
            "torso": lean,
            "head": -lean * 0.5,
            "l_shoulder": lean * 0.6,
            "r_shoulder": lean * 0.6,
        }
