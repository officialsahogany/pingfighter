# -*- coding: utf-8 -*-
"""
게임 데이터 리포지토리
데이터 접근 계층을 추상화하고 데이터 저장소와의 상호작용 관리
"""

import json
import os
import sqlite3
from typing import Dict, List, Any, Optional
from dataclasses import dataclass, asdict
from datetime import datetime
from abc import ABC, abstractmethod


@dataclass
class StageData:
    """스테이지 데이터"""
    stage_id: int
    name: str
    boss_name: str
    difficulty: int
    boss_health: int
    boss_speed: float
    background: str
    music: str
    special_mechanics: List[str] = None


@dataclass
class PlayerData:
    """플레이어 데이터"""
    player_id: str
    name: str
    total_score: int
    medals: int
    stages_cleared: List[int]
    items_unlocked: List[str]
    achievements: List[str]
    play_time: float
    created_at: datetime
    updated_at: datetime


@dataclass
class GameResult:
    """게임 결과 데이터"""
    result_id: str
    player_id: str
    stage: int
    score: int
    medals_earned: int
    time_played: float
    completed: bool
    timestamp: datetime


class IRepository(ABC):
    """리포지토리 인터페이스"""
    
    @abstractmethod
    def save(self, data: Any) -> bool:
        """데이터 저장"""
        pass
    
    @abstractmethod
    def load(self, identifier: Any) -> Optional[Any]:
        """데이터 로드"""
        pass
    
    @abstractmethod
    def delete(self, identifier: Any) -> bool:
        """데이터 삭제"""
        pass
    
    @abstractmethod
    def exists(self, identifier: Any) -> bool:
        """데이터 존재 확인"""
        pass


class GameRepository:
    """게임 데이터 리포지토리
    
    JSON, SQLite, 메모리 캐시 등 다양한 저장소를 지원합니다.
    """
    
    def __init__(self, storage_type: str = "json", data_path: str = "data"):
        """리포지토리 초기화
        
        Args:
            storage_type: 저장소 타입 (json, sqlite, memory)
            data_path: 데이터 저장 경로
        """
        self.storage_type = storage_type
        self.data_path = data_path
        self._cache: Dict[str, Any] = {}
        
        # 저장소 초기화
        self._init_storage()
    
    def _init_storage(self):
        """저장소 초기화"""
        if not os.path.exists(self.data_path):
            os.makedirs(self.data_path)
        
        if self.storage_type == "sqlite":
            self._init_database()
        elif self.storage_type == "json":
            self._init_json_storage()
    
    def _init_database(self):
        """SQLite 데이터베이스 초기화"""
        db_path = os.path.join(self.data_path, "game.db")
        self.conn = sqlite3.connect(db_path)
        self.cursor = self.conn.cursor()
        
        # 테이블 생성
        self._create_tables()
    
    def _create_tables(self):
        """데이터베이스 테이블 생성"""
        # 스테이지 테이블
        self.cursor.execute("""
            CREATE TABLE IF NOT EXISTS stages (
                stage_id INTEGER PRIMARY KEY,
                name TEXT NOT NULL,
                boss_name TEXT NOT NULL,
                difficulty INTEGER,
                boss_health INTEGER,
                boss_speed REAL,
                background TEXT,
                music TEXT,
                special_mechanics TEXT
            )
        """)
        
        # 플레이어 테이블
        self.cursor.execute("""
            CREATE TABLE IF NOT EXISTS players (
                player_id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                total_score INTEGER DEFAULT 0,
                medals INTEGER DEFAULT 0,
                stages_cleared TEXT,
                items_unlocked TEXT,
                achievements TEXT,
                play_time REAL DEFAULT 0,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        
        # 게임 결과 테이블
        self.cursor.execute("""
            CREATE TABLE IF NOT EXISTS game_results (
                result_id TEXT PRIMARY KEY,
                player_id TEXT,
                stage INTEGER,
                score INTEGER,
                medals_earned INTEGER,
                time_played REAL,
                completed BOOLEAN,
                timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (player_id) REFERENCES players(player_id)
            )
        """)
        
        self.conn.commit()
    
    def _init_json_storage(self):
        """JSON 저장소 초기화"""
        # 기본 데이터 파일 생성
        files = ['stages.json', 'players.json', 'results.json', 'settings.json']
        
        for filename in files:
            filepath = os.path.join(self.data_path, filename)
            if not os.path.exists(filepath):
                with open(filepath, 'w', encoding='utf-8') as f:
                    json.dump({}, f)
    
    # ========== 스테이지 데이터 ==========
    
    def get_stage_data(self, stage_id: int) -> Optional[StageData]:
        """스테이지 데이터 조회
        
        Args:
            stage_id: 스테이지 ID
            
        Returns:
            스테이지 데이터 또는 None
        """
        # 캐시 확인
        cache_key = f"stage_{stage_id}"
        if cache_key in self._cache:
            return self._cache[cache_key]
        
        if self.storage_type == "json":
            data = self._load_json_stage(stage_id)
        elif self.storage_type == "sqlite":
            data = self._load_db_stage(stage_id)
        else:
            data = self._load_memory_stage(stage_id)
        
        if data:
            self._cache[cache_key] = data
        
        return data
    
    def _load_json_stage(self, stage_id: int) -> Optional[StageData]:
        """JSON에서 스테이지 데이터 로드"""
        filepath = os.path.join(self.data_path, 'stages.json')
        
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                stages = json.load(f)
                
            if str(stage_id) in stages:
                stage_dict = stages[str(stage_id)]
                return StageData(**stage_dict)
                
        except Exception as e:
            print(f"스테이지 데이터 로드 오류: {e}")
        
        return None
    
    def _load_db_stage(self, stage_id: int) -> Optional[StageData]:
        """데이터베이스에서 스테이지 데이터 로드"""
        self.cursor.execute(
            "SELECT * FROM stages WHERE stage_id = ?",
            (stage_id,)
        )
        
        row = self.cursor.fetchone()
        if row:
            return StageData(
                stage_id=row[0],
                name=row[1],
                boss_name=row[2],
                difficulty=row[3],
                boss_health=row[4],
                boss_speed=row[5],
                background=row[6],
                music=row[7],
                special_mechanics=json.loads(row[8]) if row[8] else []
            )
        
        return None
    
    def _load_memory_stage(self, stage_id: int) -> Optional[StageData]:
        """메모리에서 스테이지 데이터 로드 (기본값)"""
        # 하드코딩된 기본 스테이지 데이터
        default_stages = {
            1: StageData(1, "Stage 1", "Basic Boss", 1, 100, 6.0, "forest", "stage1.mp3", []),
            2: StageData(2, "Stage 2", "Crocodile Boss", 2, 150, 7.0, "swamp", "stage2.mp3", ["water"]),
            3: StageData(3, "Stage 3", "Menhera Girl", 3, 200, 8.0, "city", "stage3.mp3", ["emotion"]),
            4: StageData(4, "Stage 4", "Magnet Witch", 4, 250, 9.0, "laboratory", "stage4.mp3", ["magnetic"]),
            5: StageData(5, "Stage 5", "Slot Machine", 5, 300, 10.0, "casino", "stage5.mp3", ["random"]),
            6: StageData(6, "Stage 6", "Tank Boss", 6, 400, 11.0, "fortress", "stage6.mp3", ["armor"])
        }
        
        return default_stages.get(stage_id)
    
    def save_stage_data(self, stage: StageData) -> bool:
        """스테이지 데이터 저장"""
        try:
            if self.storage_type == "json":
                return self._save_json_stage(stage)
            elif self.storage_type == "sqlite":
                return self._save_db_stage(stage)
            else:
                self._cache[f"stage_{stage.stage_id}"] = stage
                return True
                
        except Exception as e:
            print(f"스테이지 저장 오류: {e}")
            return False
    
    # ========== 플레이어 데이터 ==========
    
    def get_player_data(self, player_id: str) -> Optional[PlayerData]:
        """플레이어 데이터 조회"""
        cache_key = f"player_{player_id}"
        if cache_key in self._cache:
            return self._cache[cache_key]
        
        # 실제 구현...
        return None
    
    def save_player_data(self, player: PlayerData) -> bool:
        """플레이어 데이터 저장"""
        try:
            cache_key = f"player_{player.player_id}"
            self._cache[cache_key] = player
            
            if self.storage_type == "json":
                return self._save_json_player(player)
            elif self.storage_type == "sqlite":
                return self._save_db_player(player)
            
            return True
            
        except Exception as e:
            print(f"플레이어 저장 오류: {e}")
            return False
    
    # ========== 게임 결과 ==========
    
    def save_game_result(self, result: Dict[str, Any]) -> bool:
        """게임 결과 저장"""
        try:
            # 결과 ID 생성
            result_id = f"result_{datetime.now().timestamp()}"
            
            game_result = GameResult(
                result_id=result_id,
                player_id=result.get('player_id', 'default'),
                stage=result['stage'],
                score=result['score'],
                medals_earned=result['medals'],
                time_played=result['time_played'],
                completed=result.get('completed', False),
                timestamp=datetime.now()
            )
            
            if self.storage_type == "json":
                return self._save_json_result(game_result)
            elif self.storage_type == "sqlite":
                return self._save_db_result(game_result)
            
            return True
            
        except Exception as e:
            print(f"결과 저장 오류: {e}")
            return False
    
    def get_high_scores(self, stage: Optional[int] = None, limit: int = 10) -> List[GameResult]:
        """하이스코어 조회"""
        if self.storage_type == "sqlite":
            return self._get_db_high_scores(stage, limit)
        elif self.storage_type == "json":
            return self._get_json_high_scores(stage, limit)
        
        return []
    
    # ========== 설정 데이터 ==========
    
    def load_settings(self) -> Dict[str, Any]:
        """게임 설정 로드"""
        filepath = os.path.join(self.data_path, 'settings.json')
        
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                return json.load(f)
        except:
            return self._get_default_settings()
    
    def save_settings(self, settings: Dict[str, Any]) -> bool:
        """게임 설정 저장"""
        filepath = os.path.join(self.data_path, 'settings.json')
        
        try:
            with open(filepath, 'w', encoding='utf-8') as f:
                json.dump(settings, f, indent=2, ensure_ascii=False)
            return True
        except Exception as e:
            print(f"설정 저장 오류: {e}")
            return False
    
    def _get_default_settings(self) -> Dict[str, Any]:
        """기본 설정 반환"""
        return {
            'sound_enabled': True,
            'music_enabled': True,
            'sound_volume': 0.7,
            'music_volume': 0.5,
            'fullscreen': False,
            'resolution': '800x600',
            'language': 'ko'
        }
    
    # ========== 헬퍼 메서드 ==========
    
    def _save_json_stage(self, stage: StageData) -> bool:
        """JSON에 스테이지 저장"""
        filepath = os.path.join(self.data_path, 'stages.json')
        
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                stages = json.load(f)
            
            stages[str(stage.stage_id)] = asdict(stage)
            
            with open(filepath, 'w', encoding='utf-8') as f:
                json.dump(stages, f, indent=2, ensure_ascii=False)
            
            return True
        except Exception as e:
            print(f"JSON 저장 오류: {e}")
            return False
    
    def _save_db_stage(self, stage: StageData) -> bool:
        """데이터베이스에 스테이지 저장"""
        try:
            self.cursor.execute("""
                INSERT OR REPLACE INTO stages VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                stage.stage_id,
                stage.name,
                stage.boss_name,
                stage.difficulty,
                stage.boss_health,
                stage.boss_speed,
                stage.background,
                stage.music,
                json.dumps(stage.special_mechanics) if stage.special_mechanics else None
            ))
            
            self.conn.commit()
            return True
            
        except Exception as e:
            print(f"DB 저장 오류: {e}")
            return False
    
    def clear_cache(self):
        """캐시 초기화"""
        self._cache.clear()
    
    def close(self):
        """리포지토리 종료"""
        if self.storage_type == "sqlite" and hasattr(self, 'conn'):
            self.conn.close()