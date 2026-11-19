; River_Raid.rom (the cartridge image, 8192 bytes) from the SD card into $A000, as the Next's
; game takes it from its folder: the .spg is started by Wild Commander, which leaves no folder
; to the program, so the card is searched: its first partition (or the card, with no
; partition table), FAT16 or FAT32, the root first, then every folder in it, depth first.
; The file is found by its long name, River_Raid.rom (any case), or by the short one,
; RIVER_~1.ROM. Without it: a red border, and the program stops.
;
; The card through the Z-controller: port $77 bit 1 its /CS (bit 0 on), port $57 a byte each
; way (a read clocks $FF out and gives the byte that came in before). The sector buffer is
; SPANS (window 1, $4000: made anew after this).

SD_DATA		equ $57
SD_CTRL		equ $77
LR_BUF		equ SPANS		; a sector
LR_DEPTH	equ 8			; folders deep at most

load_rom:
	call sd_init
	jp c,lr_fail
	ld hl,0				; sector 0: a partition table, or the volume's boot sector
	ld de,0
	call lr_bpb
	jr nc,.vol
	ld hl,0
	ld de,0
	ld bc,LR_BUF
	call sd_read
	jp c,lr_fail
	ld hl,(LR_BUF + $1C6)		; the first partition's start
	ld de,(LR_BUF + $1C8)
	call lr_bpb
	jp c,lr_fail
.vol	xor a
	ld (lr_depth),a
	ld hl,(lr_root)			; from the root (FAT16: its own area, cluster 0)
	ld de,(lr_root + 2)
	call lr_search
	jp nc,lr_fail
	ld hl,(lr_fsize)		; 8192 bytes
	ld de,$2000
	or a
	sbc hl,de
	jp nz,lr_fail
	ld hl,(lr_fsize + 2)
	ld a,h
	or l
	jp nz,lr_fail
	ld hl,$A000			; 16 sectors from its first cluster on
	ld (lr_dst),hl
	ld hl,(lr_fclus)
	ld de,(lr_fclus + 2)
.clus	ld (lr_cur),hl
	ld (lr_cur + 2),de
	call lr_clus_lba
	ld a,(lr_spc)
	ld b,a
.sec	push bc
	push de
	push hl
	ld bc,(lr_dst)
	call sd_read
	pop hl
	pop de
	pop bc
	jp c,lr_fail
	ld a,(lr_dst + 1)
	add a,2
	ld (lr_dst + 1),a
	cp $C0
	jr z,.done
	call lr_inc32
	djnz .sec
	ld hl,(lr_cur)
	ld de,(lr_cur + 2)
	call lr_next
	jp c,lr_fail
	jr .clus
.done	ld a,3				; the card deselected
	out (SD_CTRL),a
	ld hl,($BFFA)			; the cartridge starts at $A000
	ld de,$A000
	or a
	sbc hl,de
	ret z
lr_fail:
	di
	ld a,2				; a red border
	out ($FE),a
	halt

; Sector DEHL: a FAT volume's boot sector? Its numbers kept (NC), or C
lr_bpb:
	ld (lr_part),hl
	ld (lr_part + 2),de
	ld bc,LR_BUF
	call sd_read
	ret c
	ld hl,(LR_BUF + $1FE)
	ld de,$AA55
	or a
	sbc hl,de
	scf
	ret nz
	ld hl,(LR_BUF + $0B)		; 512 bytes a sector
	ld de,512
	or a
	sbc hl,de
	scf
	ret nz
	ld a,(LR_BUF + $10)		; 1 or 2 FATs
	dec a
	cp 2
	ccf
	ret c
	ld a,(LR_BUF + $0D)		; sectors a cluster: a power of 2
	or a
	scf
	ret z
	ld (lr_spc),a
	ld c,a
	dec a
	and c
	scf
	ret nz
	ld hl,(lr_part)			; the FAT: after the reserved sectors
	ld de,(lr_part + 2)
	ld bc,(LR_BUF + $0E)
	call lr_add_bc
	ld (lr_fat),hl
	ld (lr_fat + 2),de
	ld hl,(LR_BUF + $16)		; FAT16: its size; FAT32: 0, the size at $24
	ld de,0
	ld a,h
	or l
	ld (lr_fat32),a			; (0: FAT32, for now)
	jr nz,1F
	ld hl,(LR_BUF + $24)
	ld de,(LR_BUF + $26)
1:	ld a,(LR_BUF + $10)		; the FATs' sectors
	cp 1
	jr z,2F
	add hl,hl
	ex de,hl
	adc hl,hl
	ex de,hl
2:	ld bc,(lr_fat)
	add hl,bc
	ex de,hl
	ld bc,(lr_fat + 2)
	adc hl,bc
	ex de,hl			; DEHL: past the FATs
	ld a,(lr_fat32)
	or a
	jr z,.f32
	xor a				; FAT16: the root's area there, the data after it
	ld (lr_fat32),a
	ld (lr_rootlba),hl
	ld (lr_rootlba + 2),de
	push hl
	ld hl,(LR_BUF + $11)		; its entries / 16: its sectors
	ld b,4
3:	srl h
	rr l
	djnz 3B
	ld (lr_rootsec),hl
	ld b,h
	ld c,l
	pop hl
	call lr_add_bc
	ld (lr_data),hl
	ld (lr_data + 2),de
	ld hl,0
	ld (lr_root),hl
	ld (lr_root + 2),hl
	or a
	ret
.f32	ld (lr_data),hl
	ld (lr_data + 2),de
	ld a,1
	ld (lr_fat32),a
	ld hl,(LR_BUF + $2C)
	ld (lr_root),hl
	ld hl,(LR_BUF + $2E)
	ld (lr_root + 2),hl
	or a
	ret

; DEHL += BC
lr_add_bc:
	add hl,bc
	ret nc
	inc de
	ret

; DEHL + 1 (BC kept)
lr_inc32:
	inc l
	ret nz
	inc h
	ret nz
	inc de
	ret

; Cluster DEHL's first sector: data + (cluster - 2) x sectors a cluster
lr_clus_lba:
	ld bc,-2
	add hl,bc
	jr c,1F
	dec de
1:	ld a,(lr_spc)
2:	rra
	jr c,3F
	add hl,hl
	ex de,hl
	adc hl,hl
	ex de,hl
	jr 2B
3:	ld bc,(lr_data)
	add hl,bc
	ex de,hl
	ld bc,(lr_data + 2)
	adc hl,bc
	ex de,hl
	ret

; The cluster after cluster DEHL (from the FAT) into DEHL; C: the chain's end
lr_next:
	ld a,(lr_fat32)			; its sector: FAT + cluster / 256 (FAT16) or / 128, at
	or a				; (cluster x 2 or 4) mod 512
	jr z,1F
	add hl,hl			; FAT32: x 2 first
	ex de,hl
	adc hl,hl
	ex de,hl
1:	ld a,l				; HL: the place in the sector (x 2)
	push af
	ld l,h				; DEHL / 256
	ld h,e
	ld e,d
	ld d,0
	ld bc,(lr_fat)
	add hl,bc
	ex de,hl
	ld bc,(lr_fat + 2)
	adc hl,bc
	ex de,hl
	ld bc,LR_BUF
	call sd_read
	pop bc				; B: the low byte of the cluster x 2 (FAT32: x 4 / 2)
	ret c
	ld l,b
	ld h,0
	add hl,hl
	ld bc,LR_BUF
	add hl,bc
	ld a,(lr_fat32)
	or a
	jr nz,.f32
	ld e,(hl)			; FAT16: $FFF8 on the end
	inc hl
	ld d,(hl)
	ex de,hl
	ld de,0
	ld a,h
	cp $FF
	jr nz,.ok
	ld a,l
	cp $F8
	ccf
	ret
.f32	ld c,(hl)			; FAT32: 28 bits, $0FFFFFF8 on the end
	inc hl
	ld b,(hl)
	inc hl
	ld e,(hl)
	inc hl
	ld a,(hl)
	and $0F
	ld d,a
	ld h,b
	ld l,c
	cp $0F
	jr nz,.ok
	ld a,e
	inc a
	jr nz,.ok
	ld a,h
	inc a
	jr nz,.ok
	ld a,l
	cp $F8
	ccf
	ret
.ok	or a
	ret

; The folder from cluster DEHL (0: FAT16's root) searched for the file (C: found, its first
; cluster and size in lr_fclus, lr_fsize), then its folders, depth first (NC: not there).
; The walk's state (lr_state) is put aside while a folder in it is searched.
lr_search:
	ld (lr_first),hl
	ld (lr_first + 2),de
	xor a
	ld (lr_mode),a			; 0: the files, 1: the folders
.pass	call lr_rewind
.loop	call lr_get
	jp c,.end
	ld a,(ix + 0)
	or a
	jp z,.end			; the folder's end
	cp $E5
	jp z,.reset			; deleted
	ld a,(ix + $0B)
	cp $0F
	jp z,.lfn
	bit 3,a				; a volume label
	jp nz,.reset
	ld a,(lr_mode)
	or a
	jp nz,.folder
	bit 4,(ix + $0B)
	jp nz,.reset
	call lr_name
	jp nc,.reset
	ld l,(ix + $1A)			; found
	ld h,(ix + $1B)
	ld (lr_fclus),hl
	ld l,(ix + $14)
	ld h,(ix + $15)
	ld a,(lr_fat32)
	or a
	jr nz,1F
	ld hl,0
1:	ld (lr_fclus + 2),hl
	ld l,(ix + $1C)
	ld h,(ix + $1D)
	ld (lr_fsize),hl
	ld l,(ix + $1E)
	ld h,(ix + $1F)
	ld (lr_fsize + 2),hl
	scf
	ret
.folder	bit 4,(ix + $0B)
	jp z,.reset
	ld a,(ix + 0)			; ("." and "..": not)
	cp '.'
	jp z,.reset
	ld a,(lr_depth)
	cp LR_DEPTH
	jp nc,.reset
	ld l,(ix + $1A)
	ld h,(ix + $1B)
	ld e,(ix + $14)
	ld d,(ix + $15)
	ld a,(lr_fat32)
	or a
	jr nz,2F
	ld de,0
2:	ld a,h
	or l
	or d
	or e
	jp z,.reset
	push de
	push hl
	call lr_save
	pop hl
	pop de
	call lr_search
	push af
	call lr_restore
	pop af
	ret c
	jp .reset
.lfn	call lr_lfn
	jp .next
.reset	xor a
	ld (lr_lfn_ok),a
.next	call lr_advance
	jp .loop
.end	ld a,(lr_mode)
	or a
	ret nz				; (NC)
	inc a
	ld (lr_mode),a
	xor a
	ld (lr_lfn_ok),a
	jp .pass

; The walk from the folder's start (lr_first)
lr_rewind:
	xor a
	ld (lr_end),a
	ld (lr_loaded),a
	ld hl,0
	ld (lr_off),hl
	ld hl,(lr_first)
	ld de,(lr_first + 2)
	ld (lr_cur),hl
	ld (lr_cur + 2),de
	ld a,h
	or l
	or d
	or e
	jr nz,lr_start_clus
	ld hl,(lr_rootsec)		; FAT16's root: its own area
	ld (lr_left),hl
	ld hl,(lr_rootlba)
	ld de,(lr_rootlba + 2)
	ld (lr_sec),hl
	ld (lr_sec + 2),de
	ret
lr_start_clus:				; lr_cur's sectors next
	call lr_clus_lba
	ld (lr_sec),hl
	ld (lr_sec + 2),de
	ld a,(lr_spc)
	ld l,a
	ld h,0
	ld (lr_left),hl
	ret

; IX: the walk's entry (its sector read when it is not in the buffer); C: the folder's end
lr_get:
	ld a,(lr_end)
	or a
	scf
	ret nz
	ld a,(lr_loaded)
	or a
	jr nz,1F
	ld hl,(lr_sec)
	ld de,(lr_sec + 2)
	ld bc,LR_BUF
	call sd_read
	ret c
	ld a,1
	ld (lr_loaded),a
1:	ld ix,LR_BUF
	ld bc,(lr_off)
	add ix,bc
	or a
	ret

; The next entry: the next sector, the next cluster
lr_advance:
	ld hl,(lr_off)
	ld bc,32
	add hl,bc
	ld (lr_off),hl
	ld a,h
	cp 2
	ret nz
	ld hl,0
	ld (lr_off),hl
	xor a
	ld (lr_loaded),a
	ld hl,(lr_sec)
	ld de,(lr_sec + 2)
	call lr_inc32
	ld (lr_sec),hl
	ld (lr_sec + 2),de
	ld hl,(lr_left)
	dec hl
	ld (lr_left),hl
	ld a,h
	or l
	ret nz
	ld hl,(lr_cur)			; the cluster's (or FAT16's root's) end
	ld de,(lr_cur + 2)
	ld a,h
	or l
	or d
	or e
	jr z,.end
	call lr_next
	jr c,.end
	ld (lr_cur),hl
	ld (lr_cur + 2),de
	jp lr_start_clus
.end	ld a,1
	ld (lr_end),a
	ret

; The walk's state put aside (lr_saved, by lr_depth), and back
lr_save:
	call .at
	ex de,hl
	ld hl,lr_state
	ld bc,LR_STATE
	ldir
	ld hl,lr_depth
	inc (hl)
	ret
.at	ld a,(lr_depth)			; HL: lr_saved + depth x LR_STATE
	ld hl,lr_saved
	ld de,LR_STATE
	or a
	ret z
1:	add hl,de
	dec a
	jr nz,1B
	ret
lr_restore:
	ld hl,lr_depth
	dec (hl)
	call lr_save.at
	ld de,lr_state
	ld bc,LR_STATE
	ldir
	xor a
	ld (lr_loaded),a
	ret

; An LFN entry at IX: its 13 characters into lr_lfn_buf at (sequence - 1) x 13 (the low
; bytes; a high byte not 0: no match), the last one ($40) starting the name
lr_lfn:
	ld a,(ix + 0)
	bit 6,a
	jr z,1F
	ld hl,lr_lfn_buf		; the name's last part, first: cleared
	ld de,lr_lfn_buf + 1
	ld bc,255
	ld (hl),0
	ldir
	ld a,1
	ld (lr_lfn_ok),a
	ld a,(ix + 0)
1:	and $1F
	ret z
	cp 6				; (River_Raid.rom: 2 of them; longer names: not it)
	jr nc,.no
	dec a
	ld b,a				; x 13
	add a,a
	add a,b
	add a,a
	add a,a
	add a,b
	ld e,a
	ld d,high lr_lfn_buf
	ld hl,.offsets
	ld b,13
2:	push hl
	ld a,(hl)
	ld c,a
	push ix
	pop hl
	ld a,l
	add a,c
	ld l,a
	jr nc,3F
	inc h
3:	ld a,(hl)			; the character's low byte
	inc hl
	ld c,(hl)			; its high byte
	pop hl
	inc c				; ($FFFF: the padding after the name's end)
	jr nz,4F
	inc a
	ret z
	jr .no
4:	dec c
	jr nz,.no
	ld (de),a
	inc e
	inc hl
	djnz 2B
	ret
.no	xor a
	ld (lr_lfn_ok),a
	ret
.offsets	db 1, 3, 5, 7, 9, 14, 16, 18, 20, 22, 24, 28, 30

; C: the entry at IX is River_Raid.rom (its long name, any case) or RIVER_~1.ROM
lr_name:
	ld a,(lr_lfn_ok)
	or a
	jr z,.short
	ld hl,lr_lfn_buf
	ld de,lr_rom_name
.l	ld a,(de)
	ld c,a
	ld a,(hl)
	call lr_upper
	cp c
	jr nz,.short
	or a
	scf
	ret z				; both ended
	inc hl
	inc de
	jr .l
.short	push ix
	pop hl
	ld de,lr_rom_short
	ld b,11
1:	ld a,(de)
	cp (hl)
	jr nz,.not
	inc hl
	inc de
	djnz 1B
	scf
	ret
.not	or a
	ret

; A in upper case (letters)
lr_upper:
	cp 'a'
	ret c
	cp 'z' + 1
	ret nc
	sub 'a' - 'A'
	ret

lr_rom_name:	db "RIVER_RAID.ROM",0
lr_rom_short:	db "RIVER_~1ROM"

; ------------------------------------------------------------------------------------------
; The card: SPI mode, out of idle; lr_hc: block addresses (SDHC), else bytes. C: no card.
sd_init:
	xor a
	ld (lr_hc),a
	ld a,3				; /CS high: 80 clocks
	out (SD_CTRL),a
	ld b,16
1:	ld a,$FF
	out (SD_DATA),a
	djnz 1B
	ld a,1				; selected
	out (SD_CTRL),a
	ld b,32				; CMD0: idle ($01)
2:	push bc
	ld a,$40
	ld hl,0
	ld de,0
	ld c,$95
	call sd_cmd
	pop bc
	cp 1
	jr z,3F
	djnz 2B
	scf
	ret
3:	ld a,$48			; CMD8 $1AA: a v2 card answers it
	ld hl,$01AA
	ld de,0
	ld c,$87
	call sd_cmd
	ld c,0				; C: ACMD41's HCS (v2: $40)
	bit 2,a
	jr nz,.v1
	call sd_in			; its 4 bytes
	call sd_in
	call sd_in
	call sd_in
	ld c,$40
.v1	ld b,0				; ACMD41 until ready (0), 256 x at most
.acmd	push bc
	ld a,$77			; CMD55
	ld hl,0
	ld de,0
	ld c,$FF
	call sd_cmd
	pop bc
	push bc
	ld a,$69			; ACMD41
	ld d,c
	ld e,0
	ld hl,0
	ld c,$FF
	call sd_cmd
	pop bc
	or a
	jr z,.ready
	push bc
	ld b,0				; a while
4:	ex (sp),hl
	ex (sp),hl
	djnz 4B
	pop bc
	djnz .acmd
	scf
	ret
.ready	ld a,c
	or a
	jr z,.sdsc
	ld a,$7A			; CMD58: the OCR, CCS (bit 30): block addresses
	ld hl,0
	ld de,0
	ld c,$FF
	call sd_cmd
	call sd_in
	push af
	call sd_in
	call sd_in
	call sd_in
	pop af
	and $40
	ld (lr_hc),a
	ret nz				; (NC)
.sdsc	ld a,$50			; CMD16 512
	ld hl,512
	ld de,0
	ld c,$FF
	call sd_cmd
	or a
	ret z
	scf
	ret

; Command A (with $40), argument DEHL, CRC C; A: its R1 ($FF none)
sd_cmd:
	push af
	call sd_in			; (a byte between commands)
	pop af
	out (SD_DATA),a
	ld a,d
	out (SD_DATA),a
	ld a,e
	out (SD_DATA),a
	ld a,h
	out (SD_DATA),a
	ld a,l
	out (SD_DATA),a
	ld a,c
	out (SD_DATA),a
	ld b,16				; the R1: the first byte with bit 7 0
1:	call sd_in
	bit 7,a
	ret z
	djnz 1B
	ret

sd_in:
	in a,(SD_DATA)
	ret

; Sector DEHL into BC (512 bytes); C: an error
sd_read:
	push bc
	ld a,(lr_hc)			; SDSC: a byte address (x 512)
	or a
	jr nz,1F
	ld d,e
	ld e,h
	ld h,l
	ld l,0
	sla h
	rl e
	rl d
1:	ld a,$51			; CMD17
	ld c,$FF
	call sd_cmd
	pop hl
	or a
	scf
	ret nz
	ld de,0				; the data token $FE
2:	call sd_in
	cp $FE
	jr z,3F
	dec de
	ld a,d
	or e
	jr nz,2B
	scf
	ret
3:	ld bc,SD_DATA			; 512 bytes, then the CRC
	inir
	inir
	call sd_in
	call sd_in
	or a
	ret
