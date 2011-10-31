CC=gcc
CFLAGS=-c -Wall
SOURCES=src/main.c

OBJECTS=$(SOURCES:.c=.o)
PROGRAM=tester

ifeq ($(DEBUG), 1)
  CFLAGS+=-g
endif

all: $(SOURCES) $(PROGRAM)

$(PROGRAM): $(OBJECTS) 
	$(CC) $(OBJECTS) -o $@

.c.o:
	$(CC) $(CFLAGS) $< -o $@


clean:
	rm -rf $(OBJECTS) $(PROGRAM)