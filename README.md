# Stranger of Sword City 한국어 패치 v1.1

## 적용 방식

- **일본어 슬롯**의 텍스트·튜토리얼·테이블·일본어 오프닝을 한국어로 교체합니다.
- 의미 기준 원문은 일본어판이며 공식 영어판을 교차 참조했습니다.
- 공식 영어 `_E` 텍스트 자산은 수정하지 않습니다.
- 공용 실행 파일에서는 일본어 전용 문자열 참조만 한국어 섹션으로 이동합니다.


## v1.1 정밀 검수

- 일본어 원문 기준 **16,392개 문자열 전수 검수**
- **63개 검수 패킷**, 최종 교정 **8,143건**
- 보호 토큰·커스텀 인코딩·1,107자 한글 글꼴·문자열 폭·고정 필드 용량 검증
- `item.dat` 설명 영역 밖 변경 **0건**, 영어 `_E` 자산 변경 **0건**
- 독립 정적 검증 **12/12 통과**
- 게임과 Steam은 실행하지 않은 정적 검수판

v1.0이 설치되어 있으면 v1.0의 `Restore-Original.ps1`로 먼저 원본을
복구한 뒤 v1.1을 설치합니다.

## 설치

1. 게임과 Steam의 게임 실행 화면을 닫습니다.
2. PowerShell에서 다음 명령을 실행합니다.

   ```powershell
   powershell.exe -ExecutionPolicy Bypass -File .\Install-KoreanPatch.ps1
   ```

3. Steam의 **속성 → 언어**에서 **일본어(Japanese)**를 선택합니다. 이 슬롯이 패치 후 한국어 슬롯으로 동작합니다.
4. 게임 내 **Options → Language**에서도 Japanese 위치를 선택하고 **Apply**한 뒤 게임을 다시 시작합니다.
5. `Verify-KoreanPatch.ps1`로 설치 파일 해시를 다시 확인할 수 있습니다.

설치기는 패키지 전체 인벤토리, 게임 버전, 패치 파일의 SHA-256을 먼저 확인합니다. 지원하지 않는 버전, 원본·패치 혼합 상태, 변조된 파일은 쓰기 전에 거부합니다. 검증된 원본과 패치 복구본은 게임 및 패치 폴더 바깥의 다음 위치에 보관됩니다.

`문서\Stranger of Sword City Korean Patch Backups`

## 원본 복구

게임을 종료한 뒤 실행합니다.

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Restore-Original.ps1
```

가장 최근의 유효한 백업을 사용합니다. 특정 백업은 `-BackupPath`로 지정할 수 있습니다.
설치가 중단되어 원본/패치 파일이 섞인 상태도 해당 설치의 백업 매니페스트로 복구할 수 있습니다.

## 선택적 경로 지정

게임 또는 백업 위치가 다르면 다음처럼 지정합니다.

```powershell
.\Install-KoreanPatch.ps1 `
  -GameRoot 'Y:\SteamLibrary\steamapps\common\Stranger of Sword City' `
  -BackupRoot 'D:\Game Backups\Stranger of Sword City'
```

## 검증 범위

- 일본어 슬롯 전체 이벤트 스크립트, 데이터 테이블, 튜토리얼, 하드코딩 UI 문자열
- 한글 글꼴·Shift-JIS↔Unicode 사용자 매핑
- 타이틀/주의 문구/지도 UI 그래픽과 일본어 오프닝 자막
- 원본/패치/패키지 SHA-256, 구조 파싱, 재압축 왕복
- 설치·멱등 재설치·중단/혼합 상태 복구·외부 백업 경로·패키지/게임 변조 거부 픽스처
- 영어 `_E` 자산의 바이트 동일성

세부 수치와 해시는 `manifests` 폴더의 보고서를 참조하십시오.

## 타이틀 메뉴

일본어판의 선택 상태 렌더링과 시각적으로 일치하도록 `New Game`, `Option`, `Load Data`, `Exit` 네 메뉴는 원문 영문을 유지합니다. 타이틀 부제, 시작 안내와 주의 문구를 포함한 나머지 한글화 대상은 한국어로 표시됩니다.
