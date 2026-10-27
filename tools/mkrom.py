#!/usr/bin/env python3
"""Writes a tiny GBA ROM that fills the screen with a colour gradient, for trying the app
without a game.

    python3 tools/mkrom.py test.gba

Eleven hand-assembled ARM instructions: switch to bitmap mode 3, fill the 240x160 screen
with halfwords that count up, loop forever. The header is the 192 bytes the console
expects, with a correct checksum, and no logo. Nothing in it belongs to anybody.
"""
import struct
import sys


def mov(rd, imm8, rot):
    return 0xE3A00000 | (rd << 12) | (rot << 8) | imm8


def orr(rd, rn, imm8):
    return 0xE3800000 | (rn << 16) | (rd << 12) | imm8


def add(rd, rn, imm8):
    return 0xE2800000 | (rn << 16) | (rd << 12) | imm8


def subs(rd, rn, imm8):
    return 0xE2500000 | (rn << 16) | (rd << 12) | imm8


def strh_post(rd, rn, offset):
    # STRH rd, [rn], #offset   (post-indexed, up)
    return 0xE0C000B0 | (rn << 16) | (rd << 12) | ((offset >> 4) << 8) | (offset & 15)


def branch(cond, offset_words):
    return (cond << 28) | 0x0A000000 | (offset_words & 0xFFFFFF)


code_at = 0xC0
program = [
    mov(0, 0x04, 4),        # r0 = 0x04000000        (I/O registers)
    mov(1, 0x01, 11),       # r1 = 0x400
    orr(1, 1, 3),           # r1 |= 3                (mode 3, background 2 on)
    0xE1C010B0,             # STRH r1, [r0]
    mov(2, 0x06, 4),        # r2 = 0x06000000        (video memory)
    mov(3, 0x96, 12),       # r3 = 0x9600            (240 * 160 pixels)
    mov(4, 0x00, 0),        # r4 = 0                 (the colour)
]
loop_at = code_at + 4 * len(program)
program += [
    strh_post(4, 2, 2),     # STRH r4, [r2], #2
    add(4, 4, 0x21),        # r4 += 0x21
    subs(3, 3, 1),          # r3 -= 1
]
# BNE loop: offset counts from the instruction after next (pc + 8)
here = code_at + 4 * len(program)
program.append(branch(0x1, (loop_at - (here + 8)) // 4))
here = code_at + 4 * len(program)
program.append(branch(0xE, (here - (here + 8)) // 4))      # B . (stay here)

rom = bytearray(code_at + 4 * len(program))
rom[0:4] = struct.pack('<I', branch(0xE, (code_at - 8) // 4))   # B code
rom[0xA0:0xAC] = b'SONIXTEST\0\0\0'
rom[0xAC:0xB0] = b'ATST'
rom[0xB0:0xB2] = b'01'
rom[0xB2] = 0x96
check = 0
for byte in rom[0xA0:0xBD]:
    check = (check - byte) & 0xFF
rom[0xBD] = (check - 0x19) & 0xFF
for i, word in enumerate(program):
    rom[code_at + 4 * i:code_at + 4 * i + 4] = struct.pack('<I', word)
rom += bytes((-len(rom)) % 4)
open(sys.argv[1] if len(sys.argv) > 1 else 'test.gba', 'wb').write(rom)
