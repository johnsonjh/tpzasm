# TPZASM: TDL ZASM / PSA PASM compatible assembler - Makefile
# Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
# SPDX-License-Identifier: MIT-0
# scspell-id: 8424df2a-631f-11f1-955d-246e96298730

################################################################################

XCC=$$(command -v cc 2> /dev/null || command -v gcc 2> /dev/null || \
	command -v clang 2> /dev/null || echo cc)
XCFLAGS=-O

################################################################################

PROG     = asm
SRCDIR   = src
LINKS    = pasm zasm

################################################################################

OBJ = $(SRCDIR)/main.o $(SRCDIR)/expr.o $(SRCDIR)/sym.o \
	$(SRCDIR)/lex.o $(SRCDIR)/insn.o $(SRCDIR)/assemble.o \
	$(SRCDIR)/objout.o $(SRCDIR)/platform.o

################################################################################

all: $(PROG) $(LINKS) hexcom

################################################################################

$(PROG): $(OBJ)
	@eval echo \
		"$${CC:-$(XCC)}" "$${CFLAGS:-$(XCFLAGS)}" -o $@ $(OBJ) \
		"$${LDFLAGS:-$(XLDFLAGS)}"
	@eval \
		"$${CC:-$(XCC)}" "$${CFLAGS:-$(XCFLAGS)}" -o $@ $(OBJ) \
		"$${LDFLAGS:-$(XLDFLAGS)}"

################################################################################

# pasm / zasm are the same binary; the dialect is selected from argv[0].
$(LINKS): $(PROG)
	ln -f -s $(PROG) $@

################################################################################

$(SRCDIR)/main.o: $(SRCDIR)/main.c $(SRCDIR)/asm.h $(SRCDIR)/platform.h \
	$(SRCDIR)/version.h
	@eval echo \
		"$${CC:-$(XCC)}" "$${CFLAGS:-$(XCFLAGS)}" \
		-c -o $@ $(SRCDIR)/main.c
	@eval \
		"$${CC:-$(XCC)}" "$${CFLAGS:-$(XCFLAGS)}" \
		-c -o $@ $(SRCDIR)/main.c
$(SRCDIR)/expr.o: $(SRCDIR)/expr.c $(SRCDIR)/asm.h
	@eval echo \
		"$${CC:-$(XCC)}" "$${CFLAGS:-$(XCFLAGS)}" \
		-c -o $@ $(SRCDIR)/expr.c
	@eval \
		"$${CC:-$(XCC)}" "$${CFLAGS:-$(XCFLAGS)}" \
		-c -o $@ $(SRCDIR)/expr.c
$(SRCDIR)/sym.o: $(SRCDIR)/sym.c $(SRCDIR)/asm.h
	@eval echo \
		"$${CC:-$(XCC)}" "$${CFLAGS:-$(XCFLAGS)}" \
		-c -o $@ $(SRCDIR)/sym.c
	@eval \
		"$${CC:-$(XCC)}" "$${CFLAGS:-$(XCFLAGS)}" \
		-c -o $@ $(SRCDIR)/sym.c
$(SRCDIR)/lex.o: $(SRCDIR)/lex.c $(SRCDIR)/asm.h
	@eval echo \
		"$${CC:-$(XCC)}" "$${CFLAGS:-$(XCFLAGS)}" \
		-c -o $@ $(SRCDIR)/lex.c
	@eval \
		"$${CC:-$(XCC)}" "$${CFLAGS:-$(XCFLAGS)}" \
		-c -o $@ $(SRCDIR)/lex.c
$(SRCDIR)/insn.o: $(SRCDIR)/insn.c $(SRCDIR)/asm.h
	@eval echo \
		"$${CC:-$(XCC)}" "$${CFLAGS:-$(XCFLAGS)}" \
		-c -o $@ $(SRCDIR)/insn.c
	@eval \
		"$${CC:-$(XCC)}" "$${CFLAGS:-$(XCFLAGS)}" \
		-c -o $@ $(SRCDIR)/insn.c
$(SRCDIR)/assemble.o: $(SRCDIR)/assemble.c $(SRCDIR)/asm.h
	@eval echo \
		"$${CC:-$(XCC)}" "$${CFLAGS:-$(XCFLAGS)}" \
		-c -o $@ $(SRCDIR)/assemble.c
	@eval \
		"$${CC:-$(XCC)}" "$${CFLAGS:-$(XCFLAGS)}" \
		-c -o $@ $(SRCDIR)/assemble.c
$(SRCDIR)/objout.o: $(SRCDIR)/objout.c $(SRCDIR)/asm.h
	@eval echo \
		"$${CC:-$(XCC)}" "$${CFLAGS:-$(XCFLAGS)}" \
		-c -o $@ $(SRCDIR)/objout.c
	@eval \
		"$${CC:-$(XCC)}" "$${CFLAGS:-$(XCFLAGS)}" \
		-c -o $@ $(SRCDIR)/objout.c
$(SRCDIR)/platform.o: $(SRCDIR)/platform.c $(SRCDIR)/platform.h
	@eval echo \
		"$${CC:-$(XCC)}" "$${CFLAGS:-$(XCFLAGS)}" \
		-c -o $@ $(SRCDIR)/platform.c
	@eval \
		"$${CC:-$(XCC)}" "$${CFLAGS:-$(XCFLAGS)}" \
		-c -o $@ $(SRCDIR)/platform.c

################################################################################

# Unit tests for the engine.  test_obj.sh checks the -R/-X object emitters
# against committed golden files (no CP/M oracle needed); tools/vrel.sh does
# the differential check against the original PSA PASM when tnylpo is present.
test: test_expr asm tests/test_trunc.sh tests/test_obj.sh \
	tests/test_datetime.sh tests/test_page.sh tests/longname.asm
	@printf '%s\n' "" 2> /dev/null || :
	@./test_expr
	@./tests/test_trunc.sh
	@./tests/test_obj.sh
	@./tests/test_datetime.sh
	@./tests/test_page.sh

################################################################################

# longtest: everything in 'test' plus the slow, tnylpo-gated checks -- the
# differential object comparison against the original PSA PASM (tools/vrel.sh
# over EVERY fixture that has a committed object golden, including the absolute
# SARGON) and the SARGON playability run (tests/test_play.sh).  The fixture
# list is derived from tests/golden/*.rel so it never goes stale as fixtures
# are added.  The tnylpo-dependent parts skip cleanly when the CP/M emulator is
# not installed.
longtest: test tests/test_play.sh tests/test_listing.sh tools/vrel.sh
	@if command -v tnylpo > /dev/null 2>&1; then \
		for f in $$(ls tests/golden/*.rel 2> /dev/null \
			| sed 's|.*/||; s|\.rel$$||'); do \
			printf '%s\n' "vrel: $$f"; \
			./tools/vrel.sh tests/$$f.asm || exit 1; \
		done; \
	else \
		printf '%s\n' \
			"SKIP: tnylpo not found; skipping vrel differential."; \
	fi
	@./tests/test_play.sh
	@./tests/test_listing.sh

################################################################################

test_expr: $(SRCDIR)/test_expr.o $(SRCDIR)/expr.o $(SRCDIR)/sym.o \
		$(SRCDIR)/insn.o
	@eval echo \
		"$${CC:-$(XCC)}" "$${CFLAGS:-$(XCFLAGS)}" \
		-o $@ $(SRCDIR)/test_expr.o $(SRCDIR)/expr.o \
		$(SRCDIR)/sym.o $(SRCDIR)/insn.o "$${CFLAGS:-$(XCFLAGS)}" \
		"$${LDFLAGS:-$(XLDFLAGS)}"
	@eval \
		"$${CC:-$(XCC)}" "$${CFLAGS:-$(XCFLAGS)}" \
		-o $@ $(SRCDIR)/test_expr.o $(SRCDIR)/expr.o \
		$(SRCDIR)/sym.o $(SRCDIR)/insn.o "$${CFLAGS:-$(XCFLAGS)}" \
		"$${LDFLAGS:-$(XLDFLAGS)}"

################################################################################

$(SRCDIR)/test_expr.o: $(SRCDIR)/test_expr.c $(SRCDIR)/asm.h
	@eval echo \
		"$${CC:-$(XCC)}" "$${CFLAGS:-$(XCFLAGS)}" \
		-c -o $@ $(SRCDIR)/test_expr.c
	@eval \
		"$${CC:-$(XCC)}" "$${CFLAGS:-$(XCFLAGS)}" \
		-c -o $@ $(SRCDIR)/test_expr.c

################################################################################

# Build with DMD ImportC
# Works on Linux, some platforms might need "-inline -betterC" removed
dmd:
	dmd -inline -betterC -nothrow -fPIC -fPIE -O -release -check=off \
		-boundscheck=off \
		$$(ls -1 src/*.c | grep -Ev '(test_expr\.c|hexcom\.c)')
	mv -f assemble asm
	rm -f assemble.o
	ln -f -s asm pasm
	ln -f -s asm zasm
	dmd -inline -betterC -nothrow -fPIC -fPIE -O -release -check=off \
		-boundscheck=off src/hexcom.c
	rm -f hexcom.o

################################################################################

hexcom: $(SRCDIR)/hexcom.o
	@eval echo \
		"$${CC:-$(XCC)}" "$${CFLAGS:-$(XCFLAGS)}" \
		-o $@ $(SRCDIR)/hexcom.o "$${CFLAGS:-$(XCFLAGS)}" \
		"$${LDFLAGS:-$(XLDFLAGS)}"
	@eval \
		"$${CC:-$(XCC)}" "$${CFLAGS:-$(XCFLAGS)}" \
		-o $@ $(SRCDIR)/hexcom.o "$${CFLAGS:-$(XCFLAGS)}" \
		"$${LDFLAGS:-$(XLDFLAGS)}"

$(SRCDIR)/hexcom.o: $(SRCDIR)/hexcom.c
	@eval echo \
		"$${CC:-$(XCC)}" "$${CFLAGS:-$(XCFLAGS)}" \
		-c -o $@ $(SRCDIR)/hexcom.c
	@eval \
		"$${CC:-$(XCC)}" "$${CFLAGS:-$(XCFLAGS)}" \
		-c -o $@ $(SRCDIR)/hexcom.c

################################################################################

clean:
	rm -f a.out $(PROG) $(LINKS) hexcom test_expr ./.test ./.t src/_chtmp.c
	rm -f a.exe $(PROG).exe hexcom.exe test_expr.exe ./.test.exe ./.t.exe
	rm -f a.sym $(PROG).sym hexcom.sym test_expr.sym ./.test.sym ./.t.sym
	rm -f ./*.obj $(SRCDIR)/*.o ./.test.o ./.test.obj
	rm -f compile_commands.json log.pvs

################################################################################

lint:
	@./.lint.sh

################################################################################

distclean: clean
	rm -f tags cscope.out GPATH GRTAGS GTAGS TAGS
	rm -f -r ./pvsreport core ./*.core core-* 2> /dev/null
	command -v git > /dev/null 2>&1 && git clean -ndx 2> /dev/null || :

################################################################################

tags etags ctags gtags TAGS GPATH GRTAGS GTAGS cscope cscope.out tag:
	@command -v etags > /dev/null 2>&1 && \
		{ { echo etags...; etags src/*.c && exit 0; };\
			exit 1; } || :
	@command -v ctags > /dev/null 2>&1 && \
		{ { echo ctags...; ctags src/*.c 2> /dev/null && exit 0; }; \
			exit 1; } || :
	@command -v gtags > /dev/null 2>&1 && \
		{ { echo gtags...; gtags . && exit 0; }; \
			exit 1; } || :
	@command -v cscope > /dev/null 2>&1 && \
		{ { echo cscope...; cscope -b src/*.c && exit 0; }; \
			exit 1; } || :

################################################################################

.PHONY: all clean distclean test longtest tags etags ctags gtags TAGS GPATH \
		GRTAGS GTAGS cscope cscope.out tag lint dmd

################################################################################

.NOTPARALLEL:

################################################################################

# Local Variables:
# mode: makefile
# indent-tabs-mode: t
# tab-width: 8
# whitespace-style: (tabs tab-mark)
# whitespace-display-mappings: ((tab-mark 9 [45] [45]))
# fill-column: 80
# eval: (setq-local whitespace-display-mappings
#                   '((tab-mark 9
#                               [45 45 45 45 45 45 62]
#                               [45 45 45 45 45 45 62])))
# eval: (whitespace-mode 1)
# eval: (setq-local display-fill-column-indicator-column 80)
# eval: (display-fill-column-indicator-mode 1)
# End:

################################################################################
# vim: set ft=make ts=8 ai noexpandtab list listchars=tab\:\>\- cc=80 :
################################################################################
