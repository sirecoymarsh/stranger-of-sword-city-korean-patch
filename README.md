# Stranger of Sword City 한국어 패치 v1.5

일본어판 슬롯을 한국어 슬롯으로 교체하는 비공개 배포용 패치입니다. 의미 기준 원문은 일본어판이며 공식 영문판은 문맥 교차 확인에만 사용했습니다.

## v1.5 변경 사항

- NPC 이름, 선택지, 도움말 창 제목, 스킷 대사 등 누락된 이벤트 UI를 추가 번역
- CP949 한글 IME 이름 입력, 11,172개 완성형 한글 매핑·글꼴, `가` 경계 글리프 수정
- 한글 입력·스킷 진행 중 발생하던 실행 파일 충돌 방지
- 2개 선택지 동시 표시, 세로 균형과 하단 선택지 중앙 정렬 수정
- 한국어 종료 확인 대화상자 적용
- 오프닝 영상을 게임 호환 WMV3 형식으로 재인코딩
- 원판의 의도된 라틴어 선택 머리글 `SELECT / Verum cur non audimus?`는 원문 유지
- Google 번역이나 외부 기계번역을 최종 번역에 사용하지 않고 Codex가 일본어 원문과 인게임 문맥을 직접 재검수

## 설치

1. 게임을 종료합니다.
2. 압축을 푼 폴더에서 다음 명령을 실행합니다.

   ```powershell
   powershell.exe -ExecutionPolicy Bypass -File .\Install-KoreanPatch.ps1
   ```

3. Steam **속성 → 언어**에서 **일본어(Japanese)**를 선택합니다.
4. 게임 내 **Options → Language**에서도 Japanese 위치를 선택하고 **Apply**한 뒤 다시 시작합니다.

설치기는 Steam 라이브러리에서 게임을 자동 탐색합니다. 찾지 못하면 다음처럼 지정합니다.

```powershell
.\Install-KoreanPatch.ps1 -GameRoot 'D:\SteamLibrary\steamapps\common\Stranger of Sword City'
```

설치 전 패키지 전체 인벤토리와 원본·패치 SHA-256을 확인합니다. 지원하지 않는 버전, 원본·패치 혼합 상태, 변조 파일은 쓰기 전에 거부합니다. 백업은 게임 및 패치 폴더 바깥의 문서 폴더에 생성됩니다.

## 검증과 복구

```powershell
.\Verify-KoreanPatch.ps1
.\Restore-Original.ps1
```

기존 패치가 설치되어 있으면 **해당 판의** `Restore-Original.ps1`로 먼저 원본을 복구한 뒤 v1.5를 설치하십시오.

## 검증 범위

- 번역 맵 20,427개 UID, 원본 해시 17개, 패치 해시 17개
- 사용자 확인: 시작 진행, 한글 이름 입력, NPC 이름, 스킷, 2개 선택지 표시와 정렬
- 13.7분 연속 플레이에서 WER/크래시 덤프 없음
- 최종 라틴어 머리글 복구는 원본 해시·바이트로 정적 확인
- 전체 후반 플레이스루는 아직 완료하지 않음

세부 해시와 범위는 `manifests` 폴더를 참조하십시오.
