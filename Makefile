# Game Boy Advance for Sonix Plus: gpSP, the libretro core with a MIPS dynamic
# recompiler, linked into the SDK's libretro frontend as one static program.
#
#   make fetch    clones the SDK frontend and the core into ./sdk and ./core
#   make          builds build/gba (with the recompiler) and build/gba-interp (without it)
#   make host     builds an interpreter-only program for this computer, to try it off the player
#   make package  makes dist/GBA/ ready to copy to <card>/Apps/
#
# gba-interp is the same program without the recompiler: slower, but the fallback if the
# recompiler misbehaves on a game. To use it, change `exec = gba` in manifest.ini to
# `exec = gba-interp` (the package contains both).
#
# Variables worth knowing: CROSS (the toolchain prefix), SDK (a checkout of
# sonix-app-sdk, default ./sdk), CORE (a checkout of the gpsp libretro core).

CORE_URL := https://github.com/libretro/gpsp
CORE_REV := 5819380c2ffb0900219d700a382ee68c464ebb99
SDK_URL  := https://github.com/Simplyph0/sonix-app-sdk

SDK   ?= sdk
CORE  ?= core
CROSS ?= mipsel-rockbox-linux-gnu-
OUT   ?= build

COMMON := $(CORE)/libretro/libretro-common

# The player's CPU is a 1.1 GHz MIPS32r2, like the ones in the handhelds gpSP's "mips32"
# target was written for. That target chooses its own architecture flags (mips32, tuned for
# r2, with the r2 instructions switched on), so the core is built with -O2 alone and only the
# frontend gets -march=mips32r2.
CROSS_CFLAGS := -O2 -march=mips32r2 -mno-madd4 -mhard-float
CFLAGS_CORE  := -O2

.PHONY: all host fetch package clean

all:
	$(MAKE) core-build CC=$(CROSS)gcc CXX=$(CROSS)g++ AR=$(CROSS)ar CFLAGS_ARCH="$(CROSS_CFLAGS)" \
		LDFLAGS_EXTRA="-static -s" OUTDIR=$(OUT) CORE_ARGS="platform=mips32 MMAP_JIT_CACHE=1" \
		LIBNAME=libgpsp.a PROGRAM=gba
	$(MAKE) core-build CC=$(CROSS)gcc CXX=$(CROSS)g++ AR=$(CROSS)ar CFLAGS_ARCH="$(CROSS_CFLAGS)" \
		LDFLAGS_EXTRA="-static -s" OUTDIR=$(OUT) CORE_ARGS="platform=mips32 HAVE_DYNAREC=0 CPU_ARCH=none" \
		LIBNAME=libgpsp-interp.a PROGRAM=gba-interp

host:
	$(MAKE) core-build CC=gcc CXX=g++ AR=ar CFLAGS_ARCH="-O2" LDFLAGS_EXTRA= OUTDIR=$(OUT)-host \
		CORE_ARGS="platform=unix HAVE_DYNAREC=0 CPU_ARCH=none" LIBNAME=libgpsp.a PROGRAM=gba

fetch:
	test -d $(SDK) || git clone --depth 1 $(SDK_URL) $(SDK)
	test -d $(CORE) || (git clone $(CORE_URL) $(CORE) && git -C $(CORE) checkout $(CORE_REV))

# ---- the real build ----

core-build: $(OUTDIR)/$(PROGRAM)

# gpSP at this revision does not compile for MIPS: memmap.c calls validate_addr_section_mips(ptr, size)
# but defines it with a third parameter that it never uses. This drops the parameter. It is the only
# change made to the core, it is made in the checkout and not kept anywhere, and it does nothing
# when it has already been made.
$(CORE)/.mips-fixed:
	sed -i 's/bool validate_addr_section_mips(void \*ptr, unsigned size, unsigned max_offset_mb)/bool validate_addr_section_mips(void *ptr, unsigned size)/' $(CORE)/memmap.c
	touch $@

$(OUTDIR)/$(LIBNAME): $(CORE)/.mips-fixed
	mkdir -p $(OUTDIR)
	CFLAGS="$(CFLAGS_CORE)" $(MAKE) -C $(CORE) $(CORE_ARGS) STATIC_LINKING=1 fpic= \
		CC="$(CC)" CXX="$(CXX)" AR="$(AR)" clean-objs
	CFLAGS="$(CFLAGS_CORE)" $(MAKE) -C $(CORE) $(CORE_ARGS) STATIC_LINKING=1 fpic= \
		CC="$(CC)" CXX="$(CXX)" AR="$(AR)" -j$$(nproc)
	cp $(CORE)/gpsp_libretro.so $@

# The core brings its own copies of the libretro-common pieces it needs, so only the
# frontend and the library go in.
$(OUTDIR)/$(PROGRAM): $(OUTDIR)/$(LIBNAME) $(SDK)/frontend/sonix_libretro.c $(SDK)/include/sonixapp.h
	$(CC) $(CFLAGS_ARCH) -Wall -I$(SDK)/include -I$(COMMON)/include \
		-DSONIX_SYSTEM='"GBA"' -DSONIX_LAYOUT=LAYOUT_GBA -D__LIBRETRO__ \
		-c -o $(OUTDIR)/frontend-$(PROGRAM).o $(SDK)/frontend/sonix_libretro.c
	$(CXX) $(CFLAGS_ARCH) -o $@ $(OUTDIR)/frontend-$(PROGRAM).o $(OUTDIR)/$(LIBNAME) -lm $(LDFLAGS_EXTRA)

package: all
	rm -rf dist/GBA && mkdir -p dist/GBA
	cp $(OUT)/gba $(OUT)/gba-interp dist/GBA/
	cp manifest.ini icon.png dist/GBA/
	@echo "dist/GBA is ready: copy it to <card>/Apps/"

clean:
	rm -rf $(OUT) $(OUT)-host dist
