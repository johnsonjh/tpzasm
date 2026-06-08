# PASM/ZASM - Makefile
# Copyright (c) 2026 Jeffrey H. Johnson <johnsonjh.dev@gmail.com>
# SPDX-License-Identifier: MIT-0
# scspell-id: 8424df2a-631f-11f1-955d-246e96298730

################################################################################

CC      ?= cc
CFLAGS  ?= -std=c89 -pedantic -Wall -Wextra -O2
PROG     = asm
SRCDIR   = src
LINKS    = pasm zasm

################################################################################

OBJ = $(SRCDIR)/main.o $(SRCDIR)/expr.o $(SRCDIR)/sym.o \
	$(SRCDIR)/lex.o $(SRCDIR)/insn.o $(SRCDIR)/assemble.o

################################################################################

all: $(PROG) $(LINKS) hexcom

################################################################################

$(PROG): $(OBJ)
	$(CC) $(CFLAGS) -o $@ $(OBJ)

################################################################################

# pasm / zasm are the same binary; the dialect is selected from argv[0].
$(LINKS): $(PROG)
	ln -f -s $(PROG) $@

################################################################################

$(SRCDIR)/main.o: $(SRCDIR)/main.c $(SRCDIR)/asm.h
	$(CC) $(CFLAGS) -c -o $@ $(SRCDIR)/main.c
$(SRCDIR)/expr.o: $(SRCDIR)/expr.c $(SRCDIR)/asm.h
	$(CC) $(CFLAGS) -c -o $@ $(SRCDIR)/expr.c
$(SRCDIR)/sym.o: $(SRCDIR)/sym.c $(SRCDIR)/asm.h
	$(CC) $(CFLAGS) -c -o $@ $(SRCDIR)/sym.c
$(SRCDIR)/lex.o: $(SRCDIR)/lex.c $(SRCDIR)/asm.h
	$(CC) $(CFLAGS) -c -o $@ $(SRCDIR)/lex.c
$(SRCDIR)/insn.o: $(SRCDIR)/insn.c $(SRCDIR)/asm.h
	$(CC) $(CFLAGS) -c -o $@ $(SRCDIR)/insn.c
$(SRCDIR)/assemble.o: $(SRCDIR)/assemble.c $(SRCDIR)/asm.h
	$(CC) $(CFLAGS) -c -o $@ $(SRCDIR)/assemble.c

################################################################################

# Unit tests for the engine.
test: test_expr
	./test_expr

################################################################################

test_expr: $(SRCDIR)/test_expr.o $(SRCDIR)/expr.o $(SRCDIR)/sym.o
	$(CC) $(CFLAGS) -o $@ $(SRCDIR)/test_expr.o $(SRCDIR)/expr.o \
		$(SRCDIR)/sym.o

################################################################################

$(SRCDIR)/test_expr.o: $(SRCDIR)/test_expr.c $(SRCDIR)/asm.h
	$(CC) $(CFLAGS) -c -o $@ $(SRCDIR)/test_expr.c

################################################################################

# hexcom: standalone Intel-HEX -> CP/M .COM converter (DRI HEXCOM 3.00 clone;
# self-contained, does not use the assembler engine).
hexcom: $(SRCDIR)/hexcom.o
	$(CC) $(CFLAGS) -o $@ $(SRCDIR)/hexcom.o

$(SRCDIR)/hexcom.o: $(SRCDIR)/hexcom.c
	$(CC) $(CFLAGS) -c -o $@ $(SRCDIR)/hexcom.c

################################################################################

clean:
	rm -f $(PROG) $(LINKS) hexcom test_expr
	rm -f $(SRCDIR)/*.o
	rm -f compile_commands.json log.pvs

################################################################################

lint:
	@./.lint.sh

################################################################################

distclean: clean
	rm -f tags cscope.out GPATH GRTAGS GTAGS TAGS
	rm -f -r ./pvsreport 2> /dev/null
	command -v git > /dev/null 2>&1 && git clean -ndx 2> /dev/null || :

################################################################################

tags etags ctags gtags TAGS GPATH GRTAGS GTAGS cscope cscope.out tag:
	@command -v etags > /dev/null 2>&1 && \
		{ { echo etags...; etags src/*c && exit 0; };\
			exit 1; } || :
	@command -v ctags > /dev/null 2>&1 && \
		{ { echo ctags...; ctags -R src 2> /dev/null && exit 0; }; \
			exit 1; } || :
	@command -v gtags > /dev/null 2>&1 && \
		{ { echo gtags...; gtags . && exit 0; }; \
			exit 1; } || :
	@command -v cscope > /dev/null 2>&1 && \
		{ { echo cscope...; cscope -b src/*.c && exit 0; }; \
			exit 1; } || :

################################################################################

.PHONY: all clean distclean test tags etags ctags gtags TAGS GPATH GRTAGS \
		GTAGS cscope cscope.out tag lint

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
