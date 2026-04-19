# 02

01에서는 문자 하나('A')를 하드코딩해서 출력했다.  
02에서는 `"Hello World!"` 문자열을 루프로 순회하며 출력한다.  
새로 등장한 개념: **서브루틴(call/ret)**, **lodsb**, **null-terminated string**, **로컬 레이블**

## 전체 흐름

```
start
  └─ SI = message 주소
  └─ call print
       └─ BX = 0
       └─ .loop:
            lodsb          ; AL = [SI], SI++
            cmp al, 0      ; null이면 종료
            je .done
            call print_char
              └─ INT 10h (AH=0Eh, AL=문자)
            jmp .loop
       └─ .done: ret
  └─ jmp $  (무한 루프)
```

---

## 서브루틴 — call / ret

```nasm
call print       ; 현재 IP를 스택에 push하고 print 레이블로 점프
...
print:
    ...
    ret          ; 스택에서 IP를 pop해서 call 직후로 복귀
```

- `call`은 **리턴 주소(다음 명령어의 IP)를 스택에 push**한 뒤 점프한다.
- `ret`은 **스택에서 리턴 주소를 pop**해서 돌아온다.
- 고수준 언어의 함수 호출과 완전히 동일한 메커니즘이다.

## SI 레지스터와 lodsb

```nasm
mov si, message  ; SI = message 레이블의 주소 (문자열 시작 포인터)
```

```nasm
lodsb            ; AL = byte [DS:SI],  SI = SI + 1
```

`lodsb`(Load String Byte)는 한 명령어로 두 가지를 동시에 수행한다:

1. `[DS:SI]`의 값을 AL에 로드
2. SI를 1 증가 (다음 바이트로 이동)

리얼 모드에서 DS는 보통 0x0000이므로 `[SI]`와 사실상 동일하게 동작한다.  
루프를 돌 때마다 SI가 자동으로 증가해서 문자열을 순서대로 읽어나간다.

## Null-Terminated String

```nasm
message: db 'Hello World!', 0
```

- `db` : Define Byte — 바이트 데이터를 메모리에 직접 배치하는 지시어
- 문자열 끝에 **0x00(null byte)** 을 붙인다
- 루프에서 `cmp al, 0` + `je .done`으로 null을 만나면 종료

```nasm
.loop:
    lodsb
    cmp al, 0    ; 읽어온 바이트가 0이면
    je .done     ; 루프 탈출
    call print_char
    jmp .loop
```

null을 끝 표시자로 쓰는 방식은 C언어의 문자열과 완전히 동일한 개념이다.

## 로컬 레이블 (Local Label)

```nasm
print:
.loop:      ; print 안에서만 유효한 로컬 레이블
    ...
.done:      ; print 안에서만 유효한 로컬 레이블
    ret
```

- `.`으로 시작하는 레이블은 **가장 가까운 전역 레이블(print)의 스코프에 속한다.**
- 다른 함수에서 `.loop`, `.done`이라는 같은 이름을 써도 충돌하지 않는다.
- 전체 이름은 내부적으로 `print.loop`, `print.done`으로 처리된다.

## print_char 서브루틴

```nasm
print_char:
    mov ah, 0Eh
    int 0x10
    ret
```

- `call print_char`가 호출될 때 AL에는 이미 `lodsb`로 읽어온 문자가 들어있다.
- AH=0Eh + INT 10h = BIOS 텔레타입 출력 (01에서 배운 것과 동일)
- BX=0은 `print` 함수 시작 때 이미 세팅해뒀으므로 여기서 다시 설정하지 않아도 된다.

## 01과의 차이 비교

| 항목        | 01                | 02                            |
| ----------- | ----------------- | ----------------------------- |
| 출력 대상   | 문자 1개 (`'A'`)  | 문자열 (`"Hello World!"`)     |
| 출력 방식   | 직접 INT 10h 호출 | 서브루틴 분리                 |
| 루프        | 없음              | `lodsb` + `cmp` + `je`        |
| 데이터 정의 | 없음              | `db` + null terminator        |
| 레이블      | 전역만            | 전역 + 로컬(`.loop`, `.done`) |

## 핵심 정리

1. `call`/`ret`으로 서브루틴을 만들어 코드를 구조화할 수 있다.
2. `lodsb`는 `AL = [SI]; SI++`를 한 번에 수행하는 문자열 처리 전용 명령어다.
3. 문자열은 끝에 `0`을 붙인 null-terminated 방식으로 저장한다.
4. `db`로 어셈블리 코드 안에 데이터(문자열 등)를 직접 배치할 수 있다.
5. `.`으로 시작하는 로컬 레이블로 같은 이름을 함수별로 재사용할 수 있다.
