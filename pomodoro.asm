[org 0x0100]
  jmp start


; Original Time
min:  dw 25
s:    dw 0
ms:   dw 0

oldKb: dd 0   ; For the purpose of saving old keyboard ISR

; Resting periods
shortPeriod: db 5     ; short resting period of 5mins
longPeriod: db 15     ; long resting period of 15mins

; Flags for modes
rMode: db 0   ; For setting into resting mode
aMode: db 1   ; For setting into active mode

; Flags for managing resting period
periodCount: db 2       ; number of times to repeat resting period
currentPeriod: db 0     ; where '0' means short and '1' means long
doubleShortPeriod: db 1 ; where '1' means double short and '0' means single

; Flags for other functions
timerStarted:   db 0    ; sets to '1' when timer starts
timerPaused:   db 0     ; sets to '1' when timer pauses

location: db 6
;--------------------------------------------------------------


; Clear the screen subroutine
cls: 
  pusha
  push es
  mov ax, 0xB800    ; point ES to text video memory
  mov es, ax
  xor di, di
  mov ax, 0x720
  mov cx, 2000

  cld
  rep stosw

  pop es
  popa
  ret
;--------------------------------------------------------------



; Print the timer layout
printTimer: 
  pusha
  push es

  mov ax, 0xB800    ; point ES to text video memory
  mov es, ax

  mov di, 160

  mov byte[es:di+0], 'M'
  mov byte[es:di+2], 'I'
  mov byte[es:di+4], 'N'

  mov byte[es:di+8], ':'

  mov byte[es:di+12], 'S'

  mov byte[es:di+16], ':'

  mov byte[es:di+20], 'M'
  mov byte[es:di+22], 'S'

  pop es
  popa
  ret
;--------------------------------------------------------------



; Keyboard ISR - It basically handles keyboard key clicks
kbisr: 
  push ax
  in  al, 0x60        ; read scancode from keyboard controller

  ; Check release codes only
  cmp al, 0x93        ; 'R' released
  jz resetTimer

  cmp al, 0x99        ; 'P' released
  jz pauseTimer

  cmp al, 0x9F        ; 'S' released
  jz startTimer

  cmp al, 0xAE        ; 'C' released
  jz startTimer

  cmp al, 185         ; 'SPACE' released
  jz startTimer
  
  jnz oldKBHandler    ; Unknown key released


; Reset timer
resetTimer:
  mov word [cs:min], 25
  mov word [cs:s], 0
  mov word [cs:ms], 0
  mov byte [cs:rMode], 0
  mov byte [cs:aMode], 1

  call cls

  mov byte [cs:location], 6

  jmp EOI


; Start timer
startTimer:
  cmp byte [cs:timerStarted], 1   ; If timer is already started
  jz pauseTimer                   ; pause it

  mov byte [cs:timerStarted], 1   ; Else start the timer

; Pause timer
pauseTimer:
  cmp byte [cs:timerPaused], 1    ; If timer is already paused
  jz startTimer                   ; start it

  mov byte [cs:timerPaused], 1    ; Else pause the timer


; Ends our program interrupt
EOI:
  mov al, 0x20    ; End of interrupt signal
  out 0x20, al

  pop ax
  iret


; Rest of the keyboard keys are handled by the old key keyboard ISR
oldKBHandler:
  pop ax
  jmp far [cs:oldKb]
;--------------------------------------------------------------

; To print the number on screen
printToScreen:
  push bp
  mov bp, sp
  pusha

  push es

  mov ax, 0xB800    ; point ES to text video memory
  mov es, ax

  mov di, [bp+4]    ; location in video memory
  mov ax, [bp+6]    ; number to print

  mov bx, 10        ; we'll divide by 10 each time
  mov cx, 0         ; digit count

nextDigit:
  mov dx, 0
  div bx            ; divide AX by 10 -> quotient in AX, remainder in DX

  add dl, 0x30      ; turn remainder into ASCII digit ('0' - '9')
  push dx           ; save this digit
  inc cx            ; count digits
  cmp ax, 0
  jnz nextDigit

  cmp cx, 1
  jnz nextPOS
  mov byte [es:di], '0'
  add di, 2


nextPOS:
  pop dx              ; get last digit back
  mov dh, 0x07        ; attribute (light grey on black)
  mov [es:di], dx     ; write digit + attribute on screen
  add di, 2           ; move to the next cell
  loop nextPOS

  pop es
  popa
  pop bp
  ret 4
;--------------------------------------------------------------


; Function which prints the time on screen
printTime:
  push bp
  mov bp, sp
  pusha

  push es

  mov ax, 0xB800
  mov es, ax

  mov di, [bp+4]      ; Location where the time is to be printed

  ; Printing minutes
  push word [bp+6]
  add di, 2
  push di
  call printToScreen

  ; Printing colon
  add di, 6
  mov byte [es:di], ':'

  ; Printing seconds
  push word [bp+8]
  add di, 2
  push di
  call printToScreen

  ; Printing colon
  add di, 6
  mov byte [es:di], ':'

  ; Printing milli seconds
  push word [bp+10]
  add di, 2
  push di
  call printToScreen

  pop es

  popa
  pop bp
  ret 10
;--------------------------------------------------------------

pomodoroTimer:
  pusha
  push es

  call printTimer

  push word [cs:ms]
  push word [cs:s]
  push word [cs:min]

  push 480
  call printTime

  cmp byte [cs:timerStarted], 1
  jnz dEOI      ; Using two jumps because of the short range of near jump

dEOI:
  jmp EOI

; Updates the time displaying on the timer 
updateTime:
  cmp word [cs:ms], 0
  jle carryFromSeconds

  sub word [cs:ms], 55
  ; Let's stop here for now

carryFromSeconds:
  cmp word [cs:s], 0
  jle carryFromMinutes

  add word [cs:ms], 1000
  dec word [cs:s]

carryFromMinutes:
  cmp word [cs:min], 0
  jz changeMode

  add word [cs:s], 60
  dec word [cs:min]
;--------------------------------------------------------------

; Toggles timer mode between resting and active modes
changeMode:		
 	jnz checkAMode
 			
 	mov byte [cs:aMode], 0			; Disable the active mode
 				
 	cmp byte [cs:rMode], 1			; If rMode was already enabled then do nothing
 	jz EOI
 				
 	mov byte [cs:rMode], 1			; Else enable the rMode
 	jmp EOI


# checkAMode:	
#   cmp al, 182						; Release code of Shift Right
# 	jnz startTimer
# 				
# 	mov byte [cs:rMode], 0			; Disable the rest mode
# 				
# 	cmp byte [cs:aMode], 1			; If aMode was aleady enabled then do nothing
# 	jz  EOI
# 				
# 	mov byte [cs:aMode], 1			; Else enable the aMode
# 	jmp EOI

; Driver Function (the starting point)
start:
  mov ax, 0
	mov es, ax		
			
	; Saving the previous keyboard handler routine
	mov ax, [es:9*4]
	mov [oldkb],ax
	mov ax, [es:9*4+2]
	mov [oldkb+2], ax
			
	call cls

	; Hooking the interrupts
	cli
			 
	; Keyboard Interrupt
	mov word [es:9*4], kbisr
  mov [es:9*4+2], cs
			
	; Timer Interrupt
	mov word [es:8*4], pomodoroTimer
	mov [es:8*4+2], cs
			 
	sti
			 		
	; Making it TSR 
	mov dx, start
	add dx, 15
	mov cl, 4
	shr dx, cl
			 
	mov ax, 0x3100
	int 21h
;--------------------------------------------------------------