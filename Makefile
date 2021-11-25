.POSIX:

CSC ?= chicken-csc
BIN=git-overview
SRCS=go.scm
LINKS=git-overview.link

all: $(BIN)

$(BIN): $(SRCS)
	$(CSC) -static -o $(BIN) $(SRCS)

clean:
	rm -f $(BIN) $(LINKS)

.PHONY: all clean
