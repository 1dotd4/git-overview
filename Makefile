CC=csc
BIN=git-overview
SRCS=go.scm
LINKS=git-overview.link

.PHONY: all clean

all: $(BIN)

$(BIN): $(SRCS)
	$(CC) -static -o $@ $<

clean:
	rm -f $(BINS) $(LINKS)


