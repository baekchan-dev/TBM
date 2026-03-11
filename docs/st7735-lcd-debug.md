# ST7735 LCD 디버깅 가이드

ST7735 SPI LCD 디스플레이(128×160)의 텍스트/배경 방향 오류 디버깅 및 레이아웃 보정 워크플로우.
Raspberry Pi 기반 TBM 프로젝트에서 LCD 화면이 거꾸로 보이거나 텍스트 위치가 어긋날 때 참조.

---

## 1. 핵심 개념: 회전 각도 불일치

ST7735 LCD 코드에서 가장 흔한 오류는 **회전 각도 불일치**다.
배경 이미지, 텍스트, 아이콘 각각 다른 회전 파라미터를 사용하며, 이 중 하나라도 잘못되면 화면 일부가 거꾸로 보인다.

| 요소 | 올바른 값 | 잘못된 값 시 증상 |
| :--- | :--- | :--- |
| `display_background_image` | `rotate(270)` | 배경 상하 반전 |
| `draw_*_text` angle | `270` | 텍스트 180° 뒤집힘 |
| `display_icon` | `rotate(270)` | 아이콘 상하 반전 |

---

## 2. 하드웨어 사양 및 좌표 시스템

- **물리 해상도**: 128×160 (portrait)
- **실제 장착 방향**: 가로(landscape) — 160px가 가로, 128px가 세로
- **SPI 인터페이스**, BGR 색상 순서

### 소프트웨어 버퍼 좌표계

코드 내 `screen_buffer`는 항상 **128(W) × 160(H)** portrait 버퍼.

```
screen_buffer (128×160)
  x=0 (top) ──────────────────────────────── x=127 (bottom)
  y=0 (left)                                 y=159 (right)
```

LCD에 표시될 때 이 버퍼는 **90° CW 회전**되어 landscape로 출력됨.

### 변환 파이프라인

```
배경 이미지 (160×128 landscape PNG)
    ↓ img.rotate(270, expand=True)
portrait 버퍼 (128×160)에 붙여넣기
    ↓ 텍스트/아이콘 그리기 (angle=270)
screen_buffer (128×160)
    ↓ LCD 하드웨어 전송 (MADCTL=0x40: MX=1)
물리 LCD (160×128 landscape, 좌우 반전)
```

---

## 3. 디버깅 워크플로우

### 1단계: 실제 LCD 사진으로 증상 파악

실제 LCD 사진을 확인하고 다음을 진단:

- **배경만 거꾸로**: `display_background_image`의 rotate 값 오류
- **텍스트만 거꾸로**: `draw_*_text` angle 값 오류 (90 → 270으로 변경)
- **배경+텍스트 모두 거꾸로**: MADCTL 설정 오류 가능성
- **텍스트 위치 어긋남**: 좌표(x, y) 값 오류

### 2단계: 시뮬레이션으로 검증

물리 하드웨어 없이 레이아웃을 확인하려면 `tools/simulate_screens.py`를 사용:

```bash
python tools/simulate_screens.py <images_dir> <fonts_dir> <output_dir> --angle 270 --lcd-rotate 90
```

출력:
- `output_dir/buffer/` : 코드가 그리는 128×160 버퍼 (raw)
- `output_dir/lcd/` : 실제 LCD에서 보이는 모습 (90° CW 회전 적용)

**중요**: 시뮬레이션의 `lcd/` 폴더 이미지를 실제 LCD 사진과 비교한다. `buffer/` 이미지는 직접 보이는 것과 다르다.

### 3단계: 코드 수정

#### 텍스트가 180° 뒤집혀 있을 때

```python
# 잘못된 코드
draw_left_justified_text(screen_buffer, text, x, y, 90, font)

# 올바른 코드
draw_left_justified_text(screen_buffer, text, x, y, 270, font)
```

파일 전체에서 일괄 치환 시 주의: `90`은 y좌표 값으로도 사용되므로 `, 90,` 패턴으로 검색하되 angle 파라미터 위치인지 확인.

#### 배경이 거꾸로 보일 때

```python
# display_background_image 함수 내부
rotated = img.rotate(270, expand=True)  # 90이면 반전됨
```

### 4단계: 수정 후 재검증

코드 수정 후 시뮬레이션을 다시 실행하고 `lcd/` 이미지를 확인. 만족스러우면 실제 기기 테스트 진행.

---

## 4. 텍스트 그리기 규칙

`draw_left_justified_text(buf, text, x, y, angle, font)` 에서:
- `x`: 버퍼의 행 위치 (0=상단, 127=하단)
- `y`: 버퍼의 열 위치 (0=왼쪽, 159=오른쪽)
- `angle`: 반드시 **270** (텍스트가 LCD에서 정방향으로 보임)

angle=90이면 텍스트가 LCD에서 180° 뒤집혀 보임.

---

## 5. 주요 화면별 좌표 (TBM UmbrelLCDV2_0 기준)

### Screen 1: Bitcoin Price

| 요소 | x | y | 폰트 크기 |
| :--- | :--- | :--- | :--- |
| BTC 가격 | 79~118 | 30 | min(195/자릿수, 39) |
| SAT 가격 | 24~73 | 30 | min(200/자릿수, 50) |
| 통화 레이블 | 1 | 39 | 14 |
| 온도 | 3 (right) | 3 | 12 |

### Screen 2: Transactions

| 요소 | x | y | 폰트 크기 |
| :--- | :--- | :--- | :--- |
| Low fee | 85~90 | 9 | 86/자릿수 |
| High fee | 85~90 | 88 | 86/자릿수 |
| Next block TXs | 43 | 67 | 28 |
| Unconfirmed TXs | 7 | 64 | 24 |

### Screen 5: Network

| 요소 | x | y | 폰트 크기 |
| :--- | :--- | :--- | :--- |
| Connections | 68 | 자릿수별 | 15 |
| Mempool 값 | 68 | 자릿수별 | 15 |
| Mempool 단위 | 55 | 105 | 9 |
| Hashrate 값 | 22 | 자릿수별 | 15 |
| Blockchain 값 | 22 | 자릿수별 | 15 |

### Screen 7: Storage

| 요소 | x | y | 폰트 크기 |
| :--- | :--- | :--- | :--- |
| 사용량 | 59 | 7 | 20 |
| "Used out of..." | 44 | 7 | 11 |
| "...available" | 13 (right) | 11 | 11 |
| 진행 바 | x=29, y=7~147 | 폭=2 | - |

---

## 6. MADCTL 값 참조

| MADCTL | 효과 |
| :--- | :--- |
| 0x00 | 기본 (portrait) |
| 0x40 | MX=1: 좌우 반전 |
| 0xC0 | MY=1, MX=1: 180° 회전 |
| 0xC8 | MY=1, MX=1, MV=1: 270° |

---

## 7. 디버깅 체크리스트

텍스트가 거꾸로 보일 때:
1. `angle=270` 인지 확인 (90이면 180° 뒤집힘)
2. `display_background_image`에서 `rotate(270)` 인지 확인

배경이 거꾸로 보일 때:
1. `display_background_image`에서 `rotate(270)` 인지 확인 (90이면 반전)

텍스트가 엉뚱한 위치에 나올 때:
1. `tools/simulate_screens.py`로 시뮬레이션 생성
2. `--lcd-rotate 90` 옵션으로 LCD 뷰 확인
3. 실제 LCD 사진과 비교

---

## 8. 디버깅 원칙

1. 코드 수정 전에 반드시 실제 LCD 사진으로 증상을 파악한다.
2. 시뮬레이션 이미지를 확인받은 후 커밋한다.
3. 한 번에 하나의 변수만 변경하고 결과를 확인한다 (angle, rotate, MADCTL을 동시에 바꾸지 않는다).
4. 원본 코드(git history)를 참조하여 의도적으로 변경된 부분과 버그를 구분한다.
