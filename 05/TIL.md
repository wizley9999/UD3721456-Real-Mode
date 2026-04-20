# TIL : 05 - 커스텀 인터럽트 핸들러

IVT에 직접 함수 주소를 써서 **인터럽트 핸들러를 교체**한다.  
새로 등장한 개념: **IVT 직접 수정**, **iret**, **세그먼트 오버라이드**, **word**

참고: https://wiki.osdev.org/Exceptions

## 실행 결과

```
V
Hello World!
```

`int 1` → handle_one → 'V' 출력, 그 다음 Hello World! 출력.

## 04와 달라진 점

```nasm
handle_zero:          ; 인터럽트 0번 핸들러 — 'A' 출력
    ...
    iret

handle_one:           ; 인터럽트 1번 핸들러 — 'V' 출력
    ...
    iret

step2:
    ...세그먼트 초기화...

    mov word[ss:0x00], handle_zero   ; IVT[0] IP 설정
    mov word[ss:0x02], 0x7c0         ; IVT[0] CS 설정
    mov word[ss:0x04], handle_one    ; IVT[1] IP 설정
    mov word[ss:0x06], 0x7c0         ; IVT[1] CS 설정

    int 1                            ; 인터럽트 1번 발생
```

## IVT 구조 복습

IVT는 물리 주소 0x0000에 있고, 각 항목은 4바이트(IP 2 + CS 2)다.

```
물리 주소 0x0000 : 인터럽트 0번 IP (2바이트)
물리 주소 0x0002 : 인터럽트 0번 CS (2바이트)
물리 주소 0x0004 : 인터럽트 1번 IP (2바이트)
물리 주소 0x0006 : 인터럽트 1번 CS (2바이트)
...
```

n번 인터럽트 주소 = `n × 4`

## SS를 이용해서 IVT에 접근하는 이유

```nasm
mov word[ss:0x00], handle_zero
```

`ss:`는 **세그먼트 오버라이드 접두사**다.  
"이 메모리 접근은 DS 대신 SS를 기준으로 해라"는 뜻이다.

우리가 설정한 값을 보면:

```
SS = 0x0000
물리 주소 = 0x0000 × 16 + 오프셋 = 오프셋 그대로
```

SS가 0x0000이니까 `[ss:0x00]`은 물리 주소 **0x0000**, 즉 IVT 시작점이다.  
`[ss:0x04]`는 물리 주소 **0x0004**, 즉 인터럽트 1번 슬롯이다.

DS를 쓰면 안 되는 이유:

```
DS = 0x7C0
[ds:0x00] = 물리 주소 0x7C00  ← IVT가 아니라 부트로더 코드 영역
```

## word — 2바이트 단위 쓰기

```nasm
mov word[ss:0x00], handle_zero
```

`word`는 **2바이트**로 쓰겠다는 선언이다.

| 키워드  | 크기    |
| ------- | ------- |
| `byte`  | 1바이트 |
| `word`  | 2바이트 |
| `dword` | 4바이트 |

IVT 각 필드(IP, CS)가 2바이트씩이라 `word`를 쓴다.

## IVT에 핸들러 등록하는 과정

```nasm
; 인터럽트 0번 등록
mov word[ss:0x00], handle_zero   ; IP = handle_zero의 오프셋
mov word[ss:0x02], 0x7c0         ; CS = 0x7C0

; 인터럽트 1번 등록
mov word[ss:0x04], handle_one    ; IP = handle_one의 오프셋
mov word[ss:0x06], 0x7c0         ; CS = 0x7C0
```

메모리에 이렇게 쓰인다:

```
0x0000 : [handle_zero 오프셋 하위] [handle_zero 오프셋 상위]
0x0002 : [0xC0] [0x07]   ← 0x7C0, Little Endian
0x0004 : [handle_one 오프셋 하위] [handle_one 오프셋 상위]
0x0006 : [0xC0] [0x07]
```

## iret — 인터럽트 리턴

```nasm
handle_one:
    mov ah, 0eh
    mov al, 'V'
    mov bx, 0x00
    int 0x10
    iret          ; ← ret이 아니라 iret
```

인터럽트가 발생할 때 CPU는 스택에 3가지를 저장한다:

```
스택에 push 순서:
1. FLAGS (플래그 레지스터)
2. CS
3. IP
```

`ret`은 CS:IP만 복원한다.  
`iret`은 **CS:IP + FLAGS까지 전부 복원**한다.

인터럽트 핸들러는 반드시 `iret`으로 끝내야 하는 이유가 여기 있다 —  
FLAGS까지 복원해야 인터럽트 발생 전 상태로 완전히 돌아올 수 있다.

## 전체 실행 흐름

```
_start → start → step2

step2:
  세그먼트 초기화
       ↓
  IVT[0] ← handle_zero 주소 등록
  IVT[1] ← handle_one 주소 등록
       ↓
  int 1 발생
       ↓  CPU가 IVT[1] 조회
       ↓  CS:IP = 0x7C0:handle_one_오프셋
  handle_one 실행 → 'V' 출력
  iret → step2의 int 1 다음 줄로 복귀
       ↓
  print("Hello World!")
       ↓
  jmp $ (무한루프)
```

## 핵심 정리

1. IVT는 메모리 0x0000에 있고, 직접 값을 써서 핸들러를 교체할 수 있다.
2. `SS=0x0000`이라 `[ss:오프셋]`으로 IVT에 직접 접근한다.
3. `word`는 2바이트 단위로 메모리에 쓰겠다는 선언이다.
4. IVT 각 항목은 IP(2바이트) + CS(2바이트) = 4바이트다.
5. 인터럽트 핸들러는 `ret` 대신 `iret`으로 끝내야 FLAGS까지 복원된다.
6. `int n` 으로 소프트웨어 인터럽트를 직접 발생시킬 수 있다.
