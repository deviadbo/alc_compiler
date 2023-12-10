$(info --Another Language Complier--)
$(info )
$(info To run the compiler with a input file write in the CMD ->)
$(info for example: alc input.a)
$(info )
alc.exe: 	clean lex.yy.c alc.tab.c
	gcc lex.yy.c alc.tab.c -o alc.exe

lex.yy.c: alc.tab.c alc.l
	flex alc.l

alc.tab.c: alc.y
	bison -d alc.y --debug

clean: 
	$(info Clean files...)
	del lex.yy.c alc.tab.c alc.tab.h alc.exe output.exe output.c