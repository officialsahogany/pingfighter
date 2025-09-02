"""
Resource Manager - 리소스 관리자
이미지, 사운드, 폰트 등 리소스 로딩 및 캐싱
"""

import pygame
import os
import json
from typing import Dict, Any, Optional, List, Tuple
from pathlib import Path
import threading
from concurrent.futures import ThreadPoolExecutor
from core.global_manager import GlobalManager


class ResourceLoader:
    """리소스 로더 기본 클래스"""
    
    def load(self, path: str) -> Any:
        """리소스 로드
        
        Args:
            path: 파일 경로
            
        Returns:
            로드된 리소스
        """
        raise NotImplementedError
        
    def validate(self, resource: Any) -> bool:
        """리소스 유효성 검사
        
        Args:
            resource: 리소스
            
        Returns:
            유효 여부
        """
        return resource is not None


class ImageLoader(ResourceLoader):
    """이미지 로더"""
    
    def __init__(self):
        self.supported_formats = ['.png', '.jpg', '.jpeg', '.bmp', '.gif']
        
    def load(self, path: str) -> Optional[pygame.Surface]:
        """이미지 로드
        
        Args:
            path: 파일 경로
            
        Returns:
            Surface 객체 또는 None
        """
        try:
            # 파일 확장자 체크
            ext = Path(path).suffix.lower()
            if ext not in self.supported_formats:
                print(f"⚠️ 지원하지 않는 이미지 형식: {ext}")
                return None
                
            # 이미지 로드
            image = pygame.image.load(path)
            
            # 최적화
            if image.get_flags() & pygame.SRCALPHA:
                return image.convert_alpha()
            else:
                return image.convert()
                
        except Exception as e:
            print(f"❌ 이미지 로드 실패 ({path}): {e}")
            return None
            
    def load_scaled(self, path: str, size: Tuple[int, int]) -> Optional[pygame.Surface]:
        """크기 조정된 이미지 로드
        
        Args:
            path: 파일 경로
            size: 목표 크기
            
        Returns:
            Surface 객체 또는 None
        """
        image = self.load(path)
        if image:
            return pygame.transform.scale(image, size)
        return None


class SoundLoader(ResourceLoader):
    """사운드 로더"""
    
    def __init__(self):
        self.supported_formats = ['.wav', '.ogg', '.mp3']
        
    def load(self, path: str) -> Optional[pygame.mixer.Sound]:
        """사운드 로드
        
        Args:
            path: 파일 경로
            
        Returns:
            Sound 객체 또는 None
        """
        try:
            # 파일 확장자 체크
            ext = Path(path).suffix.lower()
            if ext not in self.supported_formats:
                print(f"⚠️ 지원하지 않는 사운드 형식: {ext}")
                return None
                
            # 사운드 로드
            return pygame.mixer.Sound(path)
            
        except Exception as e:
            print(f"❌ 사운드 로드 실패 ({path}): {e}")
            return None


class FontLoader(ResourceLoader):
    """폰트 로더"""
    
    def __init__(self):
        self.supported_formats = ['.ttf', '.otf']
        
    def load(self, path: str, size: int = 20) -> Optional[pygame.font.Font]:
        """폰트 로드
        
        Args:
            path: 파일 경로
            size: 폰트 크기
            
        Returns:
            Font 객체 또는 None
        """
        try:
            # 시스템 폰트인 경우
            if not path or path == "default":
                return pygame.font.Font(None, size)
                
            # 파일 확장자 체크
            ext = Path(path).suffix.lower()
            if ext not in self.supported_formats:
                print(f"⚠️ 지원하지 않는 폰트 형식: {ext}")
                return None
                
            # 폰트 로드
            return pygame.font.Font(path, size)
            
        except Exception as e:
            print(f"❌ 폰트 로드 실패 ({path}): {e}")
            # 기본 폰트로 폴백
            return pygame.font.Font(None, size)


class ResourceCache:
    """리소스 캐시"""
    
    def __init__(self, max_size: int = 100):
        self.cache: Dict[str, Any] = {}
        self.access_count: Dict[str, int] = {}
        self.max_size = max_size
        self.lock = threading.Lock()
        
    def get(self, key: str) -> Optional[Any]:
        """캐시에서 가져오기
        
        Args:
            key: 캐시 키
            
        Returns:
            리소스 또는 None
        """
        with self.lock:
            if key in self.cache:
                self.access_count[key] += 1
                return self.cache[key]
        return None
        
    def put(self, key: str, resource: Any):
        """캐시에 저장
        
        Args:
            key: 캐시 키
            resource: 리소스
        """
        with self.lock:
            # 캐시 크기 초과 시 LRU 제거
            if len(self.cache) >= self.max_size and key not in self.cache:
                # 가장 적게 사용된 항목 제거
                lru_key = min(self.access_count, key=self.access_count.get)
                del self.cache[lru_key]
                del self.access_count[lru_key]
                
            self.cache[key] = resource
            self.access_count[key] = 0
            
    def clear(self):
        """캐시 초기화"""
        with self.lock:
            self.cache.clear()
            self.access_count.clear()
            
    def remove(self, key: str):
        """특정 항목 제거
        
        Args:
            key: 캐시 키
        """
        with self.lock:
            if key in self.cache:
                del self.cache[key]
                del self.access_count[key]


class ResourceManager:
    """리소스 매니저"""
    
    def __init__(self):
        self.global_manager = GlobalManager.get_instance()
        
        # 로더
        self.image_loader = ImageLoader()
        self.sound_loader = SoundLoader()
        self.font_loader = FontLoader()
        
        # 캐시
        self.image_cache = ResourceCache(max_size=50)
        self.sound_cache = ResourceCache(max_size=30)
        self.font_cache = ResourceCache(max_size=20)
        
        # 비동기 로딩
        self.executor = ThreadPoolExecutor(max_workers=4)
        self.loading_tasks = {}
        
        # 리소스 경로
        self.base_path = Path(".")
        self.image_path = self.base_path / "images"
        self.sound_path = self.base_path / "sounds"
        self.font_path = self.base_path / "fonts"
        
        # 리소스 매니페스트
        self.manifest = {}
        self.load_manifest()
        
    def load_manifest(self):
        """리소스 매니페스트 로드"""
        manifest_path = self.base_path / "resources.json"
        if manifest_path.exists():
            try:
                with open(manifest_path, 'r', encoding='utf-8') as f:
                    self.manifest = json.load(f)
                print(f"📦 리소스 매니페스트 로드: {len(self.manifest)} 항목")
            except Exception as e:
                print(f"매니페스트 로드 실패: {e}")
                
    def preload_resources(self, resource_list: List[str]):
        """리소스 사전 로드
        
        Args:
            resource_list: 리소스 ID 리스트
        """
        for resource_id in resource_list:
            if resource_id in self.manifest:
                resource_info = self.manifest[resource_id]
                resource_type = resource_info.get('type', 'image')
                path = resource_info.get('path', resource_id)
                
                if resource_type == 'image':
                    self.get_image(path)
                elif resource_type == 'sound':
                    self.get_sound(path)
                elif resource_type == 'font':
                    size = resource_info.get('size', 20)
                    self.get_font(path, size)
                    
    def get_image(self, path: str, size: Optional[Tuple[int, int]] = None) -> Optional[pygame.Surface]:
        """이미지 가져오기
        
        Args:
            path: 파일 경로
            size: 크기 (선택적)
            
        Returns:
            Surface 객체 또는 None
        """
        # 캐시 키 생성
        cache_key = f"{path}_{size}" if size else path
        
        # 캐시 확인
        cached = self.image_cache.get(cache_key)
        if cached:
            return cached
            
        # 전체 경로 생성
        if not Path(path).is_absolute():
            full_path = self.image_path / path
        else:
            full_path = Path(path)
            
        # 파일 존재 확인
        if not full_path.exists():
            # 확장자 없이 시도
            for ext in self.image_loader.supported_formats:
                test_path = full_path.with_suffix(ext)
                if test_path.exists():
                    full_path = test_path
                    break
            else:
                print(f"❌ 이미지 파일 없음: {path}")
                return None
                
        # 이미지 로드
        if size:
            image = self.image_loader.load_scaled(str(full_path), size)
        else:
            image = self.image_loader.load(str(full_path))
            
        # 캐시에 저장
        if image:
            self.image_cache.put(cache_key, image)
            
        return image
        
    def get_sound(self, path: str) -> Optional[pygame.mixer.Sound]:
        """사운드 가져오기
        
        Args:
            path: 파일 경로
            
        Returns:
            Sound 객체 또는 None
        """
        # 캐시 확인
        cached = self.sound_cache.get(path)
        if cached:
            return cached
            
        # 전체 경로 생성
        if not Path(path).is_absolute():
            full_path = self.sound_path / path
        else:
            full_path = Path(path)
            
        # 파일 존재 확인
        if not full_path.exists():
            # 확장자 없이 시도
            for ext in self.sound_loader.supported_formats:
                test_path = full_path.with_suffix(ext)
                if test_path.exists():
                    full_path = test_path
                    break
            else:
                print(f"❌ 사운드 파일 없음: {path}")
                return None
                
        # 사운드 로드
        sound = self.sound_loader.load(str(full_path))
        
        # 캐시에 저장
        if sound:
            self.sound_cache.put(path, sound)
            
        return sound
        
    def get_font(self, path: str, size: int = 20) -> Optional[pygame.font.Font]:
        """폰트 가져오기
        
        Args:
            path: 파일 경로
            size: 폰트 크기
            
        Returns:
            Font 객체 또는 None
        """
        # 캐시 키 생성
        cache_key = f"{path}_{size}"
        
        # 캐시 확인
        cached = self.font_cache.get(cache_key)
        if cached:
            return cached
            
        # 시스템 폰트 처리
        if path in ["default", "system", ""]:
            font = self.font_loader.load("default", size)
        else:
            # 전체 경로 생성
            if not Path(path).is_absolute():
                full_path = self.font_path / path
            else:
                full_path = Path(path)
                
            # 파일 존재 확인
            if not full_path.exists():
                print(f"⚠️ 폰트 파일 없음, 기본 폰트 사용: {path}")
                font = self.font_loader.load("default", size)
            else:
                font = self.font_loader.load(str(full_path), size)
                
        # 캐시에 저장
        if font:
            self.font_cache.put(cache_key, font)
            
        return font
        
    def load_async(self, resource_type: str, path: str, callback=None):
        """비동기 리소스 로드
        
        Args:
            resource_type: 리소스 타입 (image, sound, font)
            path: 파일 경로
            callback: 완료 콜백
        """
        def load_task():
            resource = None
            
            if resource_type == 'image':
                resource = self.get_image(path)
            elif resource_type == 'sound':
                resource = self.get_sound(path)
            elif resource_type == 'font':
                resource = self.get_font(path)
                
            if callback:
                callback(resource)
                
            return resource
            
        future = self.executor.submit(load_task)
        self.loading_tasks[path] = future
        
    def is_loading(self, path: str) -> bool:
        """로딩 중 여부
        
        Args:
            path: 파일 경로
            
        Returns:
            로딩 중 여부
        """
        if path in self.loading_tasks:
            return not self.loading_tasks[path].done()
        return False
        
    def wait_for_loading(self, path: str) -> Any:
        """로딩 완료 대기
        
        Args:
            path: 파일 경로
            
        Returns:
            로드된 리소스
        """
        if path in self.loading_tasks:
            return self.loading_tasks[path].result()
        return None
        
    def clear_cache(self, resource_type: Optional[str] = None):
        """캐시 초기화
        
        Args:
            resource_type: 리소스 타입 (None이면 전체)
        """
        if resource_type == 'image' or resource_type is None:
            self.image_cache.clear()
            
        if resource_type == 'sound' or resource_type is None:
            self.sound_cache.clear()
            
        if resource_type == 'font' or resource_type is None:
            self.font_cache.clear()
            
        print(f"🧹 캐시 초기화: {resource_type or '전체'}")
        
    def get_cache_info(self) -> Dict[str, Any]:
        """캐시 정보 조회
        
        Returns:
            캐시 정보
        """
        return {
            'image_cache': {
                'size': len(self.image_cache.cache),
                'max_size': self.image_cache.max_size
            },
            'sound_cache': {
                'size': len(self.sound_cache.cache),
                'max_size': self.sound_cache.max_size
            },
            'font_cache': {
                'size': len(self.font_cache.cache),
                'max_size': self.font_cache.max_size
            }
        }
        
    def cleanup(self):
        """정리"""
        # 모든 캐시 초기화
        self.clear_cache()
        
        # 실행자 종료
        self.executor.shutdown(wait=False)
        
        print("🧹 리소스 매니저 정리 완료")


# 싱글톤 인스턴스
_resource_manager = None

def get_resource_manager() -> ResourceManager:
    """리소스 매니저 싱글톤 반환"""
    global _resource_manager
    if _resource_manager is None:
        _resource_manager = ResourceManager()
    return _resource_manager