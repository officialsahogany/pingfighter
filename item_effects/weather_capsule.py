"""
기상조절캡슐 아이템 효과
현재 진행 중인 날씨 이벤트를 강제 종료시킵니다.
즉발형 액티브 아이템 (소모품)
"""

import os

# 디버그 모드
DEBUG_WEATHER_CAPSULE = os.environ.get("DEBUG_WEATHER_CAPSULE", "0") == "1"


class WeatherCapsule:
    def __init__(self):
        self.last_weather_cleared = None  # 마지막으로 제거한 날씨 타입
        self.debug = DEBUG_WEATHER_CAPSULE

    def activate(self, game_state=None, current_stage=None, width=600, height=750):
        """기상조절캡슐 활성화 - 현재 날씨 이벤트를 점진적으로 종료"""
        try:
            from events.weather_event import (
                is_weather_active,
                get_weather_type,
                start_weather_capsule_fadeout
            )

            # 현재 날씨가 활성화되어 있는지 확인
            if is_weather_active():
                weather_type = get_weather_type()
                self.last_weather_cleared = weather_type

                # 점진적 페이드아웃 시작 (즉시 종료 대신)
                success, fadeout_type = start_weather_capsule_fadeout()

                if success:
                    if self.debug:
                        print(f"[WEATHER_CAPSULE] 날씨 이벤트 '{weather_type}' 페이드아웃 시작!")
                    return True, weather_type  # 성공, 종료 중인 날씨 타입
                else:
                    if self.debug:
                        print("[WEATHER_CAPSULE] 페이드아웃 시작 실패 (이미 진행 중)")
                    return False, None
            else:
                if self.debug:
                    print("[WEATHER_CAPSULE] 활성화된 날씨 이벤트가 없습니다.")
                return False, None  # 실패 (날씨 없음)

        except ImportError as e:
            if self.debug:
                print(f"[WEATHER_CAPSULE] weather_event 모듈 import 실패: {e}")
            return False, None
        except Exception as e:
            if self.debug:
                print(f"[WEATHER_CAPSULE] 오류 발생: {e}")
            return False, None

    def get_weather_name_korean(self, weather_type):
        """날씨 타입을 한글로 변환"""
        weather_names = {
            "breeze": "미풍",
            "gust": "강풍",
            "fire": "불",
            "ice": "얼음",
            "rain": "소나기",
            "hail": "우박"
        }
        return weather_names.get(weather_type, weather_type)


# 싱글톤 인스턴스
weather_capsule_instance = None


def get_weather_capsule_instance():
    global weather_capsule_instance
    if weather_capsule_instance is None:
        weather_capsule_instance = WeatherCapsule()
    return weather_capsule_instance


def activate_weather_capsule(game_state=None, current_stage=None, width=600, height=750):
    """기상조절캡슐 활성화"""
    capsule = get_weather_capsule_instance()
    success, weather_type = capsule.activate(game_state, current_stage, width, height)
    return success, weather_type


def get_last_cleared_weather():
    """마지막으로 제거한 날씨 타입 반환"""
    capsule = get_weather_capsule_instance()
    return capsule.last_weather_cleared


def get_weather_name_korean(weather_type):
    """날씨 타입을 한글로 변환"""
    capsule = get_weather_capsule_instance()
    return capsule.get_weather_name_korean(weather_type)
