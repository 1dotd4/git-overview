OS != uname
.if "$(OS)" == "OpenBSD"
CC=chicken-csc
.else
CC=csc
.endif

.PHONY: all clean

.SUFFIXES=.scm
BIN=git-overview
SRCS=go.scm
LINKS=git-overview.link

all: $(BIN)

$(BIN): $(SRCS)
	$(CC) -static -o $@ $>

clean:
	rm -f $(BIN) $(LINKS)
