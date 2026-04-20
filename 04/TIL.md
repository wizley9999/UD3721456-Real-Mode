# TIL : 04 - BIOS Parameter Block

출력 결과는 동일하게 `Hello World!`지만,  
부트 섹터 앞부분에 **BPB(BIOS Parameter Block)** 구조를 위한 공간이 추가됐다.  
새로 등장한 개념: **BPB**, **jmp short**, **nop**, **진입점 구조 변화**

참고: https://wiki.osdev.org/FAT

## 03과 달라진 점 한눈에 보기

| 항목           | 03                           | 04                              |
| -------------- | ---------------------------- | ------------------------------- |
| 첫 번째 명령어 | `jmp 0x7c0:start` (Far Jump) | `jmp short start` + `nop`       |
| BPB 공간       | 없음                         | `times 33 db 0` (33바이트 예약) |
| 진입점 이름    | `start:`                     | `_start:` → `start:` → `step2:` |
| Far Jump 위치  | 맨 처음                      | `start:` 에서 `step2:`로        |

## BPB란?

FAT 파일시스템으로 포맷된 디스크는 부트 섹터 앞부분에  
**디스크 구조 정보를 담은 고정된 데이터 블록**이 있어야 한다.  
이걸 BPB(BIOS Parameter Block)라고 부른다.

```
오프셋 0x00 ~ 0x02 : 점프 명령어 (3바이트 고정)
오프셋 0x03 ~ 0x23 : BPB 데이터 (섹터 크기, 클러스터 수 등, 33바이트)
오프셋 0x24 ~      : 실제 부트스트랩 코드
```

Windows 같은 OS는 디스크를 인식할 때 이 구조를 기대한다.  
BPB가 없거나 엉뚱한 값이 들어있으면 디스크를 제대로 마운트 못 할 수 있다.  
04에서는 BPB 내용을 0으로 채웠지만 **공간 자체는 확보**해뒀다.

## jmp short + nop — 왜 3바이트인가

```nasm
_start:
    jmp short start   ; 2바이트
    nop               ; 1바이트
                      ; 합계 3바이트 → 오프셋 0x03에서 BPB 시작
```

BPB 규격상 **오프셋 0x03부터 BPB 데이터가 시작**해야 한다.  
그래서 첫 점프 명령어가 정확히 3바이트여야 한다.

### jmp short vs jmp

|           | jmp (Near Jump) | jmp short (Short Jump) |
| --------- | --------------- | ---------------------- |
| 크기      | 3바이트         | **2바이트**            |
| 점프 범위 | -32768 ~ +32767 | **-128 ~ +127**        |

`jmp short`은 2바이트짜리 짧은 점프다.  
여기서 `start:`까지의 거리가 짧으니까 short으로 충분하다.

### nop — No Operation

```nasm
nop   ; 아무것도 안 함, 1바이트 차지
```

말 그대로 아무 동작도 안 하는 명령어다.  
`jmp short`(2바이트) + `nop`(1바이트) = 딱 3바이트를 맞추기 위한 패딩이다.

## times 33 db 0 — BPB 공간 예약

```nasm
times 33 db 0
```

33바이트를 0으로 채운다. 실제 BPB 필드값은 아직 안 채웠지만  
**오프셋 위치를 맞추기 위해 공간만 잡아둔 것**이다.

```
오프셋 0x00 : jmp short start  (2바이트)
오프셋 0x02 : nop              (1바이트)
오프셋 0x03 : times 33 db 0   (33바이트) ← BPB 영역
오프셋 0x24 : start:           ← 실제 코드 시작
```

## 진입점 흐름

```
_start: (오프셋 0x0000)
  jmp short start       ; BPB 33바이트 건너뜀
  nop

  [BPB 33바이트]

start: (오프셋 0x0024)
  jmp 0x7c0:step2       ; CS 확정 (Far Jump)

step2:
  cli
  세그먼트 초기화 (03과 동일)
  sti
  Hello World! 출력
```

03에서 `start:`가 하던 역할이 `step2:`로 이름만 바뀐 거다.  
`start:`는 이제 Far Jump만 담당한다.

## 핵심 정리

1. FAT 디스크의 부트 섹터는 오프셋 0x00~0x02에 3바이트 점프, 0x03~0x23에 BPB가 있어야 한다.
2. `jmp short`(2바이트) + `nop`(1바이트)으로 딱 3바이트 점프를 만든다.
3. `nop`은 아무것도 안 하는 1바이트 패딩 명령어다.
4. `times 33 db 0`으로 BPB 공간(33바이트)을 0으로 예약해둔다.
5. 실제 코드는 BPB 이후인 오프셋 0x24부터 시작된다.
