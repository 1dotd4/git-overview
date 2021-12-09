.POSIX:

CSC ?= chicken-csc
BIN=git-overview
SRCS=go.scm
LINKS=git-overview.link

all: $(BIN)

$(BIN): $(SRCS)
	$(CSC) -static -O3 -d0 -o $(BIN) $(SRCS)

clean:
	rm -f $(BIN) $(LINKS)

.PHONY: all clean
