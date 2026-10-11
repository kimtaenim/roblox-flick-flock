# CLAUDE.md

이 레포의 기준 문서는 `FLICK_FLOCK_DESIGN.md` 다. 작업 전에 반드시 읽는다.

## 핵심 규칙 (설계서 10장 요약)
- 서버 권위: 물리·판정·HP는 서버. 클라이언트는 입력과 UI만.
- 밸런스 숫자는 전부 `src/shared/Config.lua` 한 곳에. 하드코딩 금지.
- 변수명은 쉬운 영어, 주석은 한국어 (아들이 읽을 수 있게).
- 능력은 `src/server/Abilities/` 에 파일 하나씩, `Ability.Execute(piece, context)` + `Ability.OnTurnEnd(piece)`.
- 새 능력 추가 시 설계서 5장 표에 먼저 한 줄 추가.
- 단계(설계서 9장)마다, 그리고 작은 기능마다 커밋·푸시.

## 실행
- Windows: `open-studio.bat` 더블클릭 (바탕화면에 복사해 써도 됨). git pull → Rojo 다운로드 → 플레이스 빌드 → Studio 열기 → `rojo serve` (포트 34872).
- Studio: 플러그인 탭 → Rojo → Connect (localhost:34872).
- 2인 테스트: Test → Clients and Servers → 2 Players. 혼자 Play 하면 파랑은 NPC (`Config.SoloMode`).

## 테스트 (Studio 없이)
- `sh tests/simulate.sh` : 진짜 Config 숫자로 NPC 대전 (튕기기만, 능력 제외). 2팀 추천 팀 조합 160판 + 3팀·4팀 각 100판 + 랜덤 모드 2·3·4팀 각 40판 + 판 크기·모양 × 바닥(나무·얼음·화산·울퉁불퉁·모래·체스·장기·바둑) × 팀 수 각 20판. 울퉁불퉁은 Board 와 같은 지형 배치(BoardShape.terrain)로 혹은 장애물, 구덩이는 끌어당김으로 넣고 고인 알 수를 셈 (언덕은 2D 라서 개수만). 시작 배치 겹침, 승패가 나는지, 팀·자리별 승리 수 출력.
- 타입 검사: `rojo sourcemap -o sourcemap.json` 후 `luau-lsp analyze --definitions=@roblox=globalTypes.d.luau --sourcemap=sourcemap.json src`

## 코드 위치
| 파일 | 역할 |
| --- | --- |
| `src/server/GameManager.server.lua` | 팀 고르기·턴 진행, 요청 검증, 능력 효과 턴 관리, 승패 |
| `src/server/Board.lua` | 판 생성 (모양·크기·바닥, 용암 구멍, 울퉁불퉁 혹·언덕·구덩이) |
| `src/server/PieceFactory.lua` | 알 생성 (Config.Pieces 다섯 값), 눈·왕관, HP 막대, 거대화 |
| `src/server/Placement.lua` | 팀 배치, 빈 자리 찾기 |
| `src/server/Damage.lua` | 왕알 HP (충돌 데미지) |
| `src/server/Elimination.lua` | 판 밖 탈락 |
| `src/server/Effects.lua` | 소리, 반짝이, 폭발, 배너 |
| `src/server/Speech.lua` | 알 대사 말풍선·목소리 (대사는 `Config.Lines`) |
| `src/server/Npc.lua` | NPC 조준 계산 (숫자만 써서 Studio 없이 테스트 가능) |
| `src/server/Abilities/*.lua` | 능력 7개 (`Execute(piece, context)` + `OnTurnEnd(piece)`) |
| `src/client/FlickInput.client.lua` | 자유 카메라(Studio 식)·흔들림, 드래그 조준, 발사 요청 |
| `src/client/AbilityUI.client.lua` | 능력 버튼 |
| `src/client/TeamSelectUI.client.lua` | 모드(2·3·4팀) 고르기, 추천 팀 / 고급 예산 조합 |
| `src/client/TurnUI.client.lua` | 차례·알 개수·왕알 HP, 배너 |
| `src/client/TutorialUI.client.lua` | 튜토리얼 (? 버튼) |
| `src/shared/Config.lua` | 모든 숫자 |
| `src/shared/AbilityList.lua` | 능력 이름·아이콘 (이름은 아들과 결정) |
| `src/shared/Remotes.lua` | RemoteEvent + GameState(Attribute) |
| `src/shared/BoardShape.lua` | 판 모양(사각형·육각형·원 여러 개 : 호리병·세잎·네잎·곰돌이, 화산 구멍) 판 안·가장자리 거리, 판 설정 묶음(makeSetup : 크기·바닥·배치·마찰) (숫자만) |
| `src/shared/TeamLayout.lua` | 2~4팀 자리·방향·다음 차례 계산 (숫자만, 테스트 가능) |

## 진행 상황
- [x] 1단계: 판 + 납작 알 + 드래그 튕기기 + 턴 교대 + 판 밖 탈락
- [x] 플레이어 대 NPC (혼자 접속하면 파랑 = NPC, 능력도 씀)
- [x] 2단계: 왕알 HP + 데미지 + 승리 판정
- [x] 3단계: 둥근 알, 0.5 알, 폭발·거대화·텔레포트
- [x] 4단계: 소환·분신·자석·유령 + 연출 (똥알은 뺌)
- [x] 5단계: 팀 선택 UI (추천 팀 4개 + 고급)
- [x] 6단계: 알 디자인(눈·왕관, 임시), 소리, 튜토리얼
- [x] 3·4팀 대결 (방장이 모드 선택, 모자란 자리는 NPC, 탈락제)
- [x] 알 캐릭터 (이름·얼굴·성격 대사), 사람 후공, 3팀 육각형 판
- [x] 판 고르기 : 보통·작은·큰·호리병·곰돌이 × 나무·얼음판·화산·울퉁불퉁·모래판·체스판·장기판·바둑판. 판 크기별 예산(작은 8, 보통 12, 큰 15)과 추천 팀 크기 조절 (`BoardShape.adaptPreset`)
- [x] 랜덤 모드 : 팀 수만 고르고 🎲 랜덤 → 판·바닥 무작위, 모든 팀이 같은 무작위 알 조합 (`BoardShape.randomBoard`, `randomCounts`)
- [x] 꾸미기 : 판 테두리(`Config.BoardFrame`), 납작 알 윗면 동그라미, 조명(대기·블룸·색 보정), 팀 색 밝게
- [ ] Studio 실제 플레이 테스트 후 고칠 것 정리 (물리 느낌, 소리 파일 존재 여부, UI 크기)

## 설계서에서 정한 해석
- 왕알도 튕길 수 있음. 무거운 만큼 세게 튕겨서 잘 움직임 (`King.flickScale`). 거대화 알도 무게만큼 힘 보정 (`Config.HeavyFlickPower`).
- 왕알은 같은 편 알과 부딪혀도, 같은 편 폭발에도 데미지 없음.
- NPC 는 왕알도 치지만, 왕알을 칠 때는 판 끝·용암까지 안 가는 세기로만.
- 왕알만 남아도 계속 싸움. 지는 건 왕알 HP 0 또는 왕알이 판 밖으로 나갈 때뿐.
- 유령은 반복 사용 가능 (`Config.ReusableAbilities`), 소환 등 나머지는 1회 (횟수는 `Config.AbilityUses` 로 정할 수 있음), 나머지 능력은 1회.
- 유령·자석은 상대 턴 한 번 동안 (`Config.EffectTurns`). 자석은 고정이 아니라 아주 무거워져서 세게 맞으면 조금 밀림 (`Config.MagnetMassScale`).
- 알이 3초 넘게 움직이면 모두 그 자리에 멈추고 턴을 넘김 (`Config.MaxMoveTime`). 턴이 끝날 때 기울거나 선 알·떠 있는 알은 그 자리(겹치면 바로 옆) 판 위에 똑바로 눕힘.
- 호리병 + 화산 조합은 막음 (`BlockedFloors`).
- 조준 취소 : 알 위로 돌아와서 놓기, 오른쪽 클릭, Esc. 차례는 그대로.
- 배치파일은 git pull 뒤 레포 안의 최신 open-studio.bat 으로 넘겨서 실행 (바탕화면 복사본이 옛날 것이어도 됨). 실행하면 바탕화면에 `알까기` 바로 가기를 만든다 (레포 안 open-studio.bat 을 가리킴, Studio 아이콘).
- 말풍선 대사는 화면을 가려서 꺼 둠 (`Config.ShowSpeech = false`). 대사·캐릭터 코드는 그대로 있어서 true 로 바꾸면 다시 나옴.
- 소리는 로블록스 기본 내장 소리 8개를 음 높이만 바꿔 씀 (`Config.Sounds`, `Config.Melodies`).
- 둥근 알은 구슬이 아니라 바둑알처럼 볼록한 타원체. 물리 몸통은 원기둥이고 겉모양만 볼록 (`Config.RoundHeight`). 납작 알보다 미끄러워서 멀리 가고(friction), 세게 튄다(bounce).
- 능력 대상은 능력 알 자기 자신 (분신은 그 알 옆, 텔레포트는 그 알을 가운데로).
- 폭발 턴에는 왕알 HP 가 1 아래로 안 내려감 (충돌 데미지 포함).
