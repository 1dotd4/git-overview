.POSIX:

include config.mk
BIN=git-overview
SRCS=go.scm
LINKS=git-overview.link

all: $(BIN)

$(BIN): $(SRCS)
	$(COMPILER) -static -o $(BIN) $(SRCS)

clean:
	rm -f $(BIN) $(LINKS)

.PHONY: all clean
