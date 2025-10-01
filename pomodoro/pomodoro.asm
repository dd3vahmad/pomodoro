; Pomodoro timer (real-mode .COM/TSR style)
[org 0x0100]
  jmp start

; -------------------------
; Data
; -------------------------
min:        dw 25
s:          dw 0
ms:         dw 0

oldKb:      dd 0

; resting durations (minutes)
shortPeriod: db 5
longPeriod:  db 15

; modes
rMode:      db 0   ; resting
aMode:      db 1   ; active (start in active mode)

; rest scheduling (0..2 -> S, S, L)
currentPeriod: db 0

; control flags
timerStarted:  db 0
timerPaused:   db 0

location:    db 6

; -------------------------
; Clear screen
; -------------------------
cls:
  pusha
  push es
  mov ax, 0xB800
  mov es, ax
  xor di, di
  mov ax, 0x0720
  mov cx, 2000
  cld
  rep stosw
  pop es
  popa
  ret

; -------------------------
; Print layout
; -------------------------
printTimer:
  pusha
  push es
  mov ax, 0xB800
  mov es, ax
  mov di, 160
  mov byte [es:di+0], 'M'
  mov byte [es:di+2], 'I'
  mov byte [es:di+4], 'N'
  mov byte [es:di+8], ':'
  mov byte [es:di+12], 'S'
  mov byte [es:di+16], ':'
  mov byte [es:di+20], 'M'
  mov byte [es:di+22], 'S'
  pop es
  popa
  ret

; -------------------------
; Keyboard ISR
; -------------------------
kbisr:
  push ax
  in  al, 0x60

  ; release codes (scancode set 1)
  cmp al, 0x93        ; 'R' released
  jz resetTimer

  cmp al, 0x99        ; 'P' released
  jz pauseTimer

  cmp al, 0x9F        ; 'S' released
  jz startTimer

  cmp al, 0xAE        ; 'C' released
  jz startTimer

  cmp al, 185         ; SPACE released
  jz startTimer

  jnz oldKBHandler

; reset
resetTimer:
  mov word [cs:min], 25
  mov word [cs:s], 0
  mov word [cs:ms], 0
  mov byte [cs:rMode], 0
  mov byte [cs:aMode], 1
  mov byte [cs:timerStarted], 0
  mov byte [cs:timerPaused], 0
  call cls
  mov byte [cs:location], 6
  jmp EOI

; start toggle
startTimer:
  cmp byte [cs:timerStarted], 1
  jz doPauseFromStartLabel
  ; start timer
  mov byte [cs:timerStarted], 1
  mov byte [cs:timerPaused], 0
  jmp EOI

doPauseFromStartLabel:
  ; if already started, toggle pause
  cmp byte [cs:timerPaused], 1
  jz unpauseFromStart
  mov byte [cs:timerPaused], 1
  jmp EOI
unpauseFromStart:
  mov byte [cs:timerPaused], 0
  jmp EOI

; explicit pause (P)
pauseTimer:
  cmp byte [cs:timerPaused], 1
  jz unpause_label
  mov byte [cs:timerPaused], 1
  jmp EOI
unpause_label:
  mov byte [cs:timerPaused], 0
  jmp EOI

; send EOI and return
EOI:
  mov al, 0x20
  out 0x20, al
  pop ax
  iret

oldKBHandler:
  pop ax
  jmp far [cs:oldKb]

; -------------------------
; Print number helper
; Arguments:
;   [bp+4] = location (offset in B800)
;   [bp+6] = number (word)
; -------------------------
printToScreen:
  push bp
  mov bp, sp
  pusha

  push es
  mov ax, 0xB800
  mov es, ax

  mov di, [bp+4]    ; location
  mov ax, [bp+6]    ; number

  mov bx, 10
  xor cx, cx        ; digit count = 0

.nextDigit:
  xor dx, dx
  div bx            ; AX = AX / 10 ; DX = remainder
  add dl, '0'
  push dx
  inc cx
  cmp ax, 0
  jnz .nextDigit

  cmp cx, 1
  jnz .nextPOS
  mov byte [es:di], '0'
  add di, 2

.nextPOS:
  ; CX holds number of digits, use LOOP with CX
  ; But loop expects CX as counter. We used CX above.
  ; Pop digits and print
.printLoop:
  pop dx
  mov dh, 0x07
  mov [es:di], dx
  add di, 2
  loop .printLoop

  pop es
  popa
  pop bp
  ret 4

; -------------------------
; Print full time: args:
;  [bp+4] = base location
;  [bp+6] = minutes
;  [bp+8] = seconds
;  [bp+10] = ms
; -------------------------
printTime:
  push bp
  mov bp, sp
  pusha
  push es

  mov ax, 0xB800
  mov es, ax

  mov di, [bp+4]

  ; minutes
  push word [bp+6]
  add di, 2
  push di
  call printToScreen

  ; colon
  add di, 6
  mov byte [es:di], ':'

  ; seconds
  push word [bp+8]
  add di, 6
  push di
  call printToScreen

  ; colon
  add di, 6
  mov byte [es:di], ':'

  ; milliseconds
  push word [bp+10]
  add di, 2
  push di
  call printToScreen

  pop es
  popa
  pop bp
  ret 10

; -------------------------
; Pomodoro timer ISR (wired to IRQ0 / int 8)
; Called repeatedly by hardware timer
; -------------------------
pomodoroTimer:
  pusha
  push es

  call printTimer

  push word [cs:ms]
  push word [cs:s]
  push word [cs:min]
  push 480
  call printTime

  ; If timer started and not paused -> update countdown
  cmp byte [cs:timerStarted], 1
  jne .skipUpdate
  cmp byte [cs:timerPaused], 1
  je .skipUpdate

  call updateTime

.skipUpdate:
  ; send EOI for timer IRQ
  mov al, 0x20
  out 0x20, al

  pop es
  popa
  iret

; -------------------------
; updateTime : decrement countdown by ~55ms per tick
; Called from pomodoroTimer ISR when active
; Uses borrowing from seconds/minutes. If time reaches 0 -> changeMode
; Must preserve registers (we were called from an ISR, but we used pusha/pop)
; -------------------------
updateTime:
  pusha

  ; if ms >= 55 -> just subtract
  mov ax, [cs:ms]
  cmp ax, 55
  jge .subMsDirect

  ; need to borrow from seconds
  mov ax, [cs:s]
  cmp ax, 0
  jne .borrowFromSeconds

  ; seconds == 0 => check minutes
  mov ax, [cs:min]
  cmp ax, 0
  je .timeUp    ; minutes == 0 and seconds == 0 -> time up
  ; borrow from minutes
  dec word [cs:min]
  ; seconds become 59
  mov word [cs:s], 59
  ; increase ms by 1000 so we can subtract
  add word [cs:ms], 1000
  jmp .subMsNow

.borrowFromSeconds:
  dec word [cs:s]
  add word [cs:ms], 1000
  jmp .subMsNow

.subMsDirect:
  ; nothing to borrow, just subtract
.subMsNow:
  sub word [cs:ms], 55
  jmp .done

.timeUp:
  ; timer reached zero -> toggle mode (active <-> resting)
  call changeMode
  ; after changeMode we start the timer automatically (if appropriate)
  jmp .done

.done:
  popa
  ret

; -------------------------
; changeMode: toggle between active and resting
; If we were active -> go to resting (call addRestPeriod to set rest duration)
; If we were resting -> go to active (set 25 minutes default)
; -------------------------
changeMode:
  pusha

  cmp byte [cs:aMode], 1
  je .toRest       ; if currently active -> switch to rest

  ; else currently resting -> go active
  ; set active mode values
  mov byte [cs:rMode], 0
  mov byte [cs:aMode], 1
  mov word [cs:min], 25
  mov word [cs:s], 0
  mov word [cs:ms], 0
  mov byte [cs:timerStarted], 1
  mov byte [cs:timerPaused], 0
  jmp .endChange

.toRest:
  ; going to rest mode
  mov byte [cs:aMode], 0
  mov byte [cs:rMode], 1
  call addRestPeriod
  mov byte [cs:timerStarted], 1
  mov byte [cs:timerPaused], 0

.endChange:
  popa
  ret

; -------------------------
; addRestPeriod: choose S or L based on currentPeriod (0->S,1->S,2->L) then advance index
; sets min, s, ms accordingly
; -------------------------
addRestPeriod:
  pusha

  mov al, [cs:currentPeriod]
  cmp al, 2
  jne .shortRest

  ; long rest
  mov al, [cs:longPeriod]
  movzx ax, al
  mov [cs:min], ax
  mov word [cs:s], 0
  mov word [cs:ms], 0
  ; advance period index -> wrap to 0
  mov al, [cs:currentPeriod]
  inc al
  mov [cs:currentPeriod], al
  cmp al, 3
  jb .afterAdvance
  mov byte [cs:currentPeriod], 0
  jmp .afterAdvance

.shortRest:
  ; short rest
  mov al, [cs:shortPeriod]
  movzx ax, al
  mov [cs:min], ax
  mov word [cs:s], 0
  mov word [cs:ms], 0
  ; advance index
  mov al, [cs:currentPeriod]
  inc al
  mov [cs:currentPeriod], al
  cmp al, 3
  jb .afterAdvance
  mov byte [cs:currentPeriod], 0

.afterAdvance:
  popa
  ret

; -------------------------
; Driver / startup
; -------------------------
start:
  mov ax, 0
  mov es, ax

  ; save old keyboard handler (vector 9)
  mov ax, [es:9*4]
  mov [oldKb], ax
  mov ax, [es:9*4+2]
  mov [oldKb+2], ax

  call cls

  cli
  ; hook keyboard IRQ (vector 9)
  mov word [es:9*4], kbisr
  mov word [es:9*4+2], cs

  ; hook timer IRQ (vector 8)
  mov word [es:8*4], pomodoroTimer
  mov word [es:8*4+2], cs
  sti

  ; become TSR
  mov dx, start
  add dx, 15
  mov cl, 4
  shr dx, cl
  mov ax, 0x3100
  int 21h

  ret
