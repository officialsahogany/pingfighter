# PowerShell 스크립트 실행 정책 오류 해결 방법

## 문제 상황
```
& : 이 시스템에서 스크립트를 실행할 수 없으므로 E:\bosspong\.venv_win\Scripts\Activate.ps1 파일을 로드할 수 없습니다.
PSSecurityException: UnauthorizedAccess
```

## 해결 방법

### 방법 1: 실행 정책 변경 (권장)
PowerShell을 **관리자 권한**으로 실행 후:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### 방법 2: 일회성 우회
매번 실행 시마다:

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
& E:/bosspong/.venv_win/Scripts/Activate.ps1
```

### 방법 3: bat 파일 사용 (가장 간단)
기존 `run_game.bat` 파일을 그대로 사용:

```batch
E:\bosspong\.venv_win\Scripts\python.exe e:\bosspong\pingfighter.py
```

PowerShell 대신 명령 프롬프트(cmd)에서:
```
run_game.bat
```

## 현재 상태
- 게임은 정상 실행됨 ✓
- 가상환경도 정상 작동 중 ✓
- 단지 PowerShell 정책 제한만 발생

## 추천
**방법 1**을 사용하여 한 번만 설정하면 이후 문제 없이 사용 가능합니다.

또는 **방법 3**처럼 기존 bat 파일을 계속 사용하셔도 됩니다.
