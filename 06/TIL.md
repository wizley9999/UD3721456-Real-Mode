# TIL : 06 - 디스크에서 섹터 읽기

05까지는 부트로더 코드 안에 문자열 데이터를 직접 박아뒀다.  
06에서는 **디스크의 두 번째 섹터에 있는 데이터를 BIOS INT 13h로 읽어와 출력**한다.  
새로 등장한 개념: **INT 13h**, **Carry Flag 에러 처리**, **`buffer:` 레이블**, **`dd`로 바이너리 조립**

참고: https://www.ctyme.com/intr/rb-0607.htm

## 실행 결과

```
Hello World! This is my awesome message!
```

부트로더 512바이트 안에 없던 문자열이 디스크에서 읽혀서 출력된다.

## 05와 달라진 점

| 항목        | 05                 | 06                                  |
| ----------- | ------------------ | ----------------------------------- |
| 출력 데이터 | 코드 안에 하드코딩 | 디스크 두 번째 섹터에서 읽어옴      |
| 디스크 접근 | 없음               | INT 13h / AH=02h                    |
| 에러 처리   | 없음               | Carry Flag 확인 후 분기             |
| 빌드 방식   | `nasm` 단독        | `nasm` + `dd`로 바이너리 두 개 합성 |

## 디스크 구조 — 섹터란?

디스크는 **섹터(Sector)** 단위로 데이터를 읽는다. 섹터 하나는 512바이트다.

```
섹터 1 (LBA 0) : 부트로더 (boot.asm → boot.bin, 512바이트)
섹터 2 (LBA 1) : message.txt 내용 (dd로 붙인 것)
```

BIOS는 섹터 번호를 **1부터** 센다 (0-indexed가 아니다).  
따라서 `CL=2`가 두 번째 섹터, 즉 실제 데이터가 있는 곳이다.

## Makefile — dd로 바이너리 조립

```makefile
all:
    nasm -f bin ./boot.asm -o ./boot.bin
    dd if=./message.txt >> ./boot.bin
    dd if=/dev/zero bs=512 count=1 >> ./boot.bin
```

| 명령어                                       | 역할                                        |
| -------------------------------------------- | ------------------------------------------- |
| `nasm -f bin boot.asm -o boot.bin`           | 어셈블리를 512바이트 플랫 바이너리로 컴파일 |
| `dd if=./message.txt >> boot.bin`            | 텍스트 파일 내용을 그 뒤에 이어 붙임        |
| `dd if=/dev/zero bs=512 count=1 >> boot.bin` | 512바이트 0 패딩 추가 (디스크 정렬용)       |

결과적으로 `boot.bin`의 첫 512바이트는 부트로더, 그 다음은 message.txt가 된다.  
BIOS가 디스크를 읽을 때 이 구조를 그대로 활용한다.

## INT 13h / AH=02h — 디스크 섹터 읽기

```nasm
mov ah, 2   ; 명령: 섹터 읽기
mov al, 1   ; 읽을 섹터 수: 1개
mov ch, 0   ; 실린더 번호 (하위 8비트)
mov cl, 2   ; 섹터 번호 (1부터 시작, 2 = 두 번째 섹터)
mov dh, 0   ; 헤드 번호
mov bx, buffer  ; ES:BX → 읽은 데이터를 저장할 버퍼 주소
int 0x13
```

### 각 레지스터 역할

| 레지스터 | 값  | 의미                                                    |
| -------- | --- | ------------------------------------------------------- |
| `AH`     | 02h | INT 13h 기능 번호: 섹터 읽기                            |
| `AL`     | 1   | 읽을 섹터 수                                            |
| `CH`     | 0   | CHS 주소의 실린더 번호 (하위 8비트)                     |
| `CL`     | 2   | CHS 주소의 섹터 번호 (1-based, 비트 0-5)                |
| `DH`     | 0   | 헤드 번호                                               |
| `DL`     | -   | 드라이브 번호 (BIOS가 부팅 시 자동 세팅, 건드리지 않음) |
| `ES:BX`  | -   | 읽은 데이터를 메모리에 저장할 목적지 주소               |

> **CHS (Cylinder-Head-Sector)**: 오래된 디스크 주소 체계.  
> 실린더 → 헤드 → 섹터 순으로 물리적 위치를 지정한다.

## ES:BX — 데이터 버퍼 주소

INT 13h는 읽은 데이터를 `ES:BX`가 가리키는 메모리 주소에 쓴다.

```nasm
mov es, ax      ; ES = 0x7C0 (step2에서 이미 설정)
mov bx, buffer  ; BX = buffer 레이블의 오프셋
int 0x13        ; 읽은 데이터 → 물리 주소 (0x7C0 × 16 + buffer오프셋)
```

`ES`는 step2 세그먼트 초기화 때 이미 `0x7C0`으로 설정되어 있다.  
`BX`에 `buffer`의 오프셋을 넣으면 실제 데이터가 부트로더 바로 뒤 메모리에 올라온다.

## buffer: 레이블 — 부트 섹터 끝에 위치

```nasm
times 510-($ - $$) db 0
dw 0xAA55

buffer:         ; ← 512바이트 딱 뒤에 선언
```

`buffer:`은 코드도 데이터도 아니다. **512바이트 부트 섹터가 끝나는 바로 다음 주소**를 가리키는 레이블이다.  
INT 13h가 디스크에서 읽어온 내용을 이 주소부터 채워 넣는다.  
즉, 디스크의 두 번째 섹터 내용이 메모리 `buffer` 주소에 로드된다.

```
메모리:
0x7C00 ~ 0x7DFD : 부트로더 코드 + 패딩
0x7DFE ~ 0x7DFF : 0x55 0xAA (부트 시그니처)
0x7E00          : buffer ← INT 13h가 여기부터 채움
```

## Carry Flag — 에러 감지

```nasm
int 0x13
jc error        ; CF=1이면 error로 점프
```

INT 13h는 실패하면 **Carry Flag(CF)를 1로 세팅**한다.  
`jc`(Jump if Carry)로 CF가 서 있으면 에러 처리 루틴으로 분기한다.

```nasm
error:
    mov si, error_message
    call print
    jmp $
```

성공하면 CF=0, `jc`는 무시되고 정상 흐름으로 진행한다.

| 명령어 | 의미                              |
| ------ | --------------------------------- |
| `jc`   | Jump if Carry (CF=1이면 점프)     |
| `jnc`  | Jump if Not Carry (CF=0이면 점프) |

## 전체 실행 흐름

```
_start → start → step2

step2:
  세그먼트 초기화 (04/05와 동일)
       ↓
  INT 13h: 디스크 섹터 2 → buffer에 로드
       ↓
  CF=1? → error: "Failed to load sector" 출력 → jmp $
  CF=0? → SI = buffer, call print
       ↓
  print("Hello World! This is my awesome message!")
       ↓
  jmp $ (무한루프)
```

## 핵심 정리

1. BIOS INT 13h / AH=02h로 디스크 섹터를 메모리로 읽어올 수 있다.
2. CHS 주소에서 섹터 번호는 **1부터** 시작한다 — 두 번째 섹터는 `CL=2`.
3. 읽은 데이터는 `ES:BX`가 가리키는 주소에 저장된다.
4. `buffer:` 레이블은 부트 시그니처(`0xAA55`) 직후 주소로, 로드된 데이터가 놓이는 곳이다.
5. INT 13h 실패 시 **Carry Flag가 세팅**되고, `jc`로 에러 분기한다.
6. `dd`로 어셈블 결과물 뒤에 데이터 파일을 붙여 멀티 섹터 디스크 이미지를 만든다.
