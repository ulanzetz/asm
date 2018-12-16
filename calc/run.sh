as common.s -o common.o
as int_parse.s -o int_parse.o
as postfix.s -o postfix.o
as main.s -o main.o
ld common.o int_parse.o postfix.o main.o -o main
./main