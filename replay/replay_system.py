"""
Replay System v3 — 화면 캡처 기반 리플레이
게임 중 실제 화면을 축소/압축하여 디스크에 스트리밍 기록.
재생 시 원본 그대로 보여주므로 아이템, 스킬, 이펙트 모두 재현.
"""

import pygame
import zlib
import struct
import pickle
import gzip
import time
import os
import sys
from typing import Dict, Any, List, Optional

# 파일 매직 + 버전
_MAGIC = b'PFRP'
_VERSION = 3

# 캡처 설정
CAPTURE_INTERVAL = 2    # 2프레임마다 1회 캡처 → 실질 30fps
SCALE_FACTOR = 0.75     # 75% 축소 (고화질)
COMPRESS_LEVEL = 1      # zlib 압축 (1=빠름, 9=최대)
MAX_DURATION = 600      # 최대 10분


def _replays_dir() -> str:
    try:
        base = sys._MEIPASS
    except AttributeError:
        base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    return os.path.join(base, "replays")


# ============================================================================
# 레코더 — 화면을 축소/압축하여 디스크에 바로 쓰기 (메모리 부담 없음)
# ============================================================================
class ReplayRecorder:
    """게임 루프에서 매 프레임 capture() 호출 → 디스크 스트리밍 기록"""

    def __init__(self):
        self.recording = False
        self.file = None
        self.filepath = None
        self.game_frame = 0
        self.captured_frames = 0
        self.start_time = 0.0
        self.metadata: Dict[str, Any] = {}
        self.scaled_w = 0
        self.scaled_h = 0
        self.current_frame = 0  # 호환용

    def start(self, stage: int = 1, boss_name: str = "",
              ai_mode: str = "normal", character: str = "smasher",
              result: str = "", screen_w: int = 760, screen_h: int = 750):
        """녹화 시작 — 임시 파일에 프레임 스트리밍 기록 시작"""
        if self.recording:
            self.stop()

        self.scaled_w = int(screen_w * SCALE_FACTOR)
        self.scaled_h = int(screen_h * SCALE_FACTOR)
        self.game_frame = 0
        self.captured_frames = 0
        self.start_time = time.time()
        self.current_frame = 0

        self.metadata = {
            'version': _VERSION,
            'stage': stage,
            'boss_name': boss_name,
            'ai_mode': ai_mode,
            'character': character,
            'result': result,
            'duration': 0,
            'total_frames': 0,
            'created_at': self.start_time,
            'screen_w': screen_w,
            'screen_h': screen_h,
            'scaled_w': self.scaled_w,
            'scaled_h': self.scaled_h,
            'capture_fps': 60 // CAPTURE_INTERVAL,
        }

        # 임시 파일 열기
        replay_dir = _replays_dir()
        os.makedirs(replay_dir, exist_ok=True)
        self.filepath = os.path.join(replay_dir, f"_recording_{int(self.start_time)}.tmp")
        try:
            self.file = open(self.filepath, 'wb')
            # 헤더: 매직 + 메타데이터 공간 예약 (나중에 덮어씀)
            self.file.write(_MAGIC)
            self.file.write(struct.pack('I', 0))  # 메타데이터 길이 (나중에 채움)
            self.recording = True
            print(f"[Replay] 화면 녹화 시작 — Stage {stage}, {self.scaled_w}x{self.scaled_h} @{60//CAPTURE_INTERVAL}fps")
        except Exception as e:
            print(f"[Replay] 녹화 파일 생성 실패: {e}")
            self.recording = False

    def capture(self, screen: pygame.Surface):
        """매 게임 프레임(60fps) 호출 — CAPTURE_INTERVAL마다 실제 캡처"""
        if not self.recording or self.file is None:
            return
        self.game_frame += 1
        self.current_frame = self.game_frame

        # 시간 제한 체크
        if time.time() - self.start_time > MAX_DURATION:
            self.stop()
            return

        # 캡처 간격 체크
        if self.game_frame % CAPTURE_INTERVAL != 0:
            return

        try:
            # 축소
            small = pygame.transform.scale(screen, (self.scaled_w, self.scaled_h))
            # 픽셀 데이터 추출
            raw = pygame.image.tostring(small, 'RGB')
            # 압축
            compressed = zlib.compress(raw, COMPRESS_LEVEL)
            # 파일에 쓰기: [4바이트 길이][압축 데이터]
            self.file.write(struct.pack('I', len(compressed)))
            self.file.write(compressed)
            self.captured_frames += 1
        except Exception:
            pass  # 캡처 실패 시 무시 (게임 프레임에 영향 주지 않음)

    def stop(self, result: str = "") -> bool:
        """녹화 중지 + 파일 완성"""
        if not self.recording:
            return False
        self.recording = False

        self.metadata['duration'] = time.time() - self.start_time
        self.metadata['total_frames'] = self.captured_frames
        if result:
            self.metadata['result'] = result

        print(f"[Replay] 녹화 중지 — {self.captured_frames}프레임, {self.metadata['duration']:.1f}초, result={result}")

        if self.captured_frames == 0 or self.file is None:
            print(f"[Replay] 프레임이 0개라 저장 건너뜀")
            self._cleanup_temp()
            return False

        return self._finalize()

    def _finalize(self) -> bool:
        """임시 파일을 최종 .rpl 파일로 변환"""
        try:
            # 메타데이터를 파일 끝에 추가
            meta_bytes = pickle.dumps(self.metadata, protocol=pickle.HIGHEST_PROTOCOL)
            self.file.write(struct.pack('I', len(meta_bytes)))
            self.file.write(meta_bytes)
            # 파일 선두의 메타데이터 길이 업데이트
            self.file.seek(len(_MAGIC))
            self.file.write(struct.pack('I', len(meta_bytes)))
            self.file.close()
            self.file = None

            # 최종 파일명으로 리네임
            replay_dir = _replays_dir()
            ts_str = time.strftime("%Y%m%d_%H%M%S")
            stage = self.metadata.get('stage', 0)
            final_name = f"replay_s{stage}_{ts_str}.rpl"
            final_path = os.path.join(replay_dir, final_name)
            os.rename(self.filepath, final_path)

            size_mb = os.path.getsize(final_path) / (1024 * 1024)
            print(f"[Replay] 저장 완료: {final_name} ({self.captured_frames}프레임, {size_mb:.1f}MB)")
            return True
        except Exception as e:
            print(f"[Replay] 저장 실패: {e}")
            import traceback; traceback.print_exc()
            self._cleanup_temp()
            return False

    def _cleanup_temp(self):
        """임시 파일 정리"""
        if self.file:
            try:
                self.file.close()
            except Exception:
                pass
            self.file = None
        if self.filepath and os.path.exists(self.filepath):
            try:
                os.remove(self.filepath)
            except Exception:
                pass


# ============================================================================
# 플레이어 — .rpl 파일에서 프레임을 읽어 재생
# ============================================================================
class ReplayPlayer:
    """화면 캡처 리플레이 재생"""

    SPEED_OPTIONS = [0.25, 0.5, 1.0, 1.5, 2.0, 4.0]

    def __init__(self):
        self.metadata: Dict[str, Any] = {}
        self.playing = False
        self.paused = False
        self.current_index = 0
        self.speed = 1.0
        self.frame_accum = 0.0
        self.total_frames = 0
        self.scaled_w = 0
        self.scaled_h = 0
        # 프레임 데이터 — 파일에서 전부 읽어서 메모리에 보관
        self.frame_data: List[bytes] = []  # 압축된 프레임 데이터
        self._current_surface: Optional[pygame.Surface] = None

    def load(self, filepath: str) -> bool:
        """리플레이 파일을 읽어서 프레임 데이터 로드"""
        try:
            with open(filepath, 'rb') as f:
                # 매직 체크
                magic = f.read(4)
                if magic != _MAGIC:
                    print(f"[Replay] 잘못된 파일 형식")
                    return False

                meta_len_bytes = f.read(4)
                meta_len = struct.unpack('I', meta_len_bytes)[0]

                # 프레임 데이터 읽기
                self.frame_data = []
                while True:
                    size_bytes = f.read(4)
                    if len(size_bytes) < 4:
                        break
                    chunk_size = struct.unpack('I', size_bytes)[0]
                    chunk = f.read(chunk_size)
                    if len(chunk) < chunk_size:
                        break

                    # 마지막 청크가 메타데이터인지 체크
                    # 파일 끝에 도달했는지 확인
                    pos = f.tell()
                    next_bytes = f.read(4)
                    if len(next_bytes) < 4:
                        # 이게 마지막 청크 = 메타데이터
                        self.metadata = pickle.loads(chunk)
                        break
                    else:
                        f.seek(pos)  # 되돌리기
                        self.frame_data.append(chunk)

            self.total_frames = len(self.frame_data)
            self.scaled_w = self.metadata.get('scaled_w', 380)
            self.scaled_h = self.metadata.get('scaled_h', 375)
            self.current_index = 0
            self.frame_accum = 0.0

            size_mb = os.path.getsize(filepath) / (1024 * 1024)
            print(f"[Replay] 로드: {self.total_frames}프레임, {self.scaled_w}x{self.scaled_h}, {size_mb:.1f}MB")
            return self.total_frames > 0
        except Exception as e:
            print(f"[Replay] 로드 실패: {e}")
            import traceback; traceback.print_exc()
            return False

    def start(self):
        if self.total_frames == 0:
            return
        self.playing = True
        self.paused = False
        self.current_index = 0
        self.frame_accum = 0.0

    def stop(self):
        self.playing = False
        self.paused = False

    def toggle_pause(self):
        self.paused = not self.paused

    def cycle_speed(self):
        try:
            idx = self.SPEED_OPTIONS.index(self.speed)
            self.speed = self.SPEED_OPTIONS[(idx + 1) % len(self.SPEED_OPTIONS)]
        except ValueError:
            self.speed = 1.0

    def seek_relative(self, delta_frames: int):
        new_idx = max(0, min(self.total_frames - 1, self.current_index + delta_frames))
        self.current_index = new_idx
        self._current_surface = None

    def get_frame_surface(self) -> Optional[pygame.Surface]:
        """현재 인덱스의 프레임을 Surface로 디코딩하여 반환"""
        if self.current_index < 0 or self.current_index >= self.total_frames:
            return self._current_surface
        try:
            compressed = self.frame_data[self.current_index]
            raw = zlib.decompress(compressed)
            surf = pygame.image.fromstring(raw, (self.scaled_w, self.scaled_h), 'RGB')
            self._current_surface = surf
            return surf
        except Exception:
            return self._current_surface

    def advance(self) -> Optional[pygame.Surface]:
        """매 프레임(60fps) 호출 — 캡처 fps에 맞춰 정속 재생"""
        if not self.playing and not self.paused:
            return None
        if self.paused:
            return self.get_frame_surface()
        if not self.playing:
            return None

        # 캡처 fps / 디스플레이 fps 비율 (30/60 = 0.5)
        # x1 속도에서 2 게임프레임마다 1 캡처프레임 진행해야 정속
        capture_fps = self.metadata.get('capture_fps', 30)
        step = self.speed * (capture_fps / 60.0)

        self.frame_accum += step
        surf = None
        while self.frame_accum >= 1.0:
            self.frame_accum -= 1.0
            if self.current_index < self.total_frames:
                surf = self.get_frame_surface()
                self.current_index += 1
            else:
                self.stop()
                break
        return surf

    @property
    def progress(self) -> float:
        if self.total_frames == 0:
            return 0.0
        return self.current_index / self.total_frames

    @property
    def current_time(self) -> float:
        if self.total_frames == 0:
            return 0.0
        capture_fps = self.metadata.get('capture_fps', 30)
        return self.current_index / capture_fps

    @property
    def total_time(self) -> float:
        return self.metadata.get('duration', 0)

    @property
    def finished(self) -> bool:
        return not self.playing and self.current_index >= self.total_frames

    # frames 속성 호환 (기존 코드에서 len(rp.frames) 사용)
    @property
    def frames(self):
        return self.frame_data


# ============================================================================
# 유틸: 리플레이 목록 조회 / 삭제
# ============================================================================
def list_replays() -> List[Dict[str, Any]]:
    """replays/ 폴더의 리플레이 목록 반환 (최신순)"""
    replays = []
    replay_dir = _replays_dir()
    if not os.path.isdir(replay_dir):
        return replays
    for fn in os.listdir(replay_dir):
        if not fn.endswith('.rpl'):
            continue
        fp = os.path.join(replay_dir, fn)
        try:
            # .rpl 파일에서 메타데이터만 빠르게 읽기
            md = _read_metadata_fast(fp)
            if md:
                replays.append({
                    'filename': fn,
                    'filepath': fp,
                    'stage': md.get('stage', 0),
                    'boss_name': md.get('boss_name', ''),
                    'ai_mode': md.get('ai_mode', ''),
                    'character': md.get('character', ''),
                    'result': md.get('result', ''),
                    'duration': md.get('duration', 0),
                    'total_frames': md.get('total_frames', 0),
                    'created_at': md.get('created_at', 0),
                })
        except Exception:
            pass
    replays.sort(key=lambda x: x['created_at'], reverse=True)
    return replays


def _read_metadata_fast(filepath: str) -> Optional[Dict]:
    """파일 끝에서 메타데이터만 빠르게 읽기"""
    try:
        file_size = os.path.getsize(filepath)
        if file_size < 16:
            return None
        with open(filepath, 'rb') as f:
            magic = f.read(4)
            if magic != _MAGIC:
                return None
            meta_len = struct.unpack('I', f.read(4))[0]
            if meta_len == 0 or meta_len > file_size:
                return None
            # 메타데이터는 파일 끝에 있음: [4바이트 길이][메타 데이터]
            f.seek(file_size - meta_len)
            meta_bytes = f.read(meta_len)
            return pickle.loads(meta_bytes)
    except Exception:
        return None


def delete_replay(filepath: str) -> bool:
    try:
        os.remove(filepath)
        return True
    except Exception:
        return False


# ============================================================================
# 싱글톤 레코더 (전역 접근용)
# ============================================================================
_recorder: Optional[ReplayRecorder] = None


def get_recorder() -> ReplayRecorder:
    global _recorder
    if _recorder is None:
        _recorder = ReplayRecorder()
    return _recorder
