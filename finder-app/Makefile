#Select compiler if by console command pass make CROSS_COMPILE = aarch64-linx_gnu- will use this cross compile, but if we use only -->makewe use gcc compiler
CC = $(CROSS_COMPILE)gcc

#Tipycall flags to compile -Wall: show warnings, -Werror: show errors, -g: Debug symbols
CFLAGS = -Wall -Werror -g

#Name of the program
TARGET = writer

#Source files where Makefile is going to look for
SRC = writer.c

#Obj which convert writer.c --> writer.o then OBJ = writer.o
OBJ = $(SRC:.c=.o)

#Rule all: Target by default, when we write "make" in console the Makefile look for the first target in the file, so we mark as reference TARGET
all: $(TARGET)

#For generate "writer" which is the TARGET I nedd writer.o which is OBJ so we link with CC so the command execxuted would be make CRISS_COMPILE = aarch64-link-gnu- -Wall -Werror -g -o writerwriter.o
$(TARGET): $(OBJ)
	$(CC) $(CFLAGS) -o $(TARGET) $(OBJ)

#How generate writer.o
#For files.o I need files.c
#$< --> Firts file of the dependency (writer.c)
#-c --> Only compile, not link
%.O: %.c
	$(CC) $(CFLAGS) -c $<

# Rule: Cleaning instruction
# linux command : rm -rf writer writer.o
clean:
	rm -rf $(TARGET) $(OBJ)
