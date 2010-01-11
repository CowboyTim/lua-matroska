LUAINC= /usr/include/lua5.1

CFLAGS= $(INCS) $(WARN) -O2 $G -fPIC
WARN= -ansi -pedantic -Wall
INCS= -I$(LUAINC)

MYNAME= pack
MYLIB= l$(MYNAME)
T= $(MYNAME).so
OBJS= $(MYLIB).o

all:	so

o:	$(MYLIB).o

so:	$T

$T:	$(OBJS)
	$(CC) -o $@ -shared $(OBJS)

clean:
	rm -f $(OBJS) $T
