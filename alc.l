%{
#include <stdio.h>
#include <string.h>
#include "alc.h"
#include "alc.tab.h"

int yylineno=0;
void yyerror (char *s);
int yylex();
int getArraySize(char* input);
%}

ALPHA           [A-Za-z]
DIGIT           ([0-9])
constArray     \[[ ]*[0-9]+([ ]*,[ ]*[0-9]+[ ]*)*\]
arraysSize         [{][0-9]+[}]
%%

"print"			                    {return print;}
"int"                               {return intx;}
"arr"                               {return arr;}
"begin"                             {return begin;}
"end"                               {return end;}
"while"                             {return WHILE;}
"do"                                {return DO;}
"if"			                    {return IF;}
"then"                              {return THEN;}
("_"|{ALPHA})({ALPHA}|{DIGIT})*		{strcpy(yylval.vName, yytext); return identifier;}
{DIGIT}+                            {yylval.num = atoi(yytext); return number;}
{arraysSize}                        {yylval.size = getArraySize(yytext); return arraysSize;}
{constArray}                        {strcpy(yylval.elem, yytext); return constArray;}
[-+*/=;]                            {return yytext[0];}
"@"                                 {return yytext[0];}
":"                                 {return yytext[0];}
"{"                                 {return yytext[0];}
"}"                                 {return yytext[0];}
"("                                 {return yytext[0];}
")"                                 {return yytext[0];}
","                                 {return yytext[0];}
">="                                {return GE;}
"<="                                {return LE;}
"=="                                {return EQ;}
"!="                                {return NE;}
"<"                                 {return SE;}
">"                                 {return BE;}
[ \t]                               ;
"\n"                                {++yylineno;}
.                                   {ECHO; yyerror ("Unexpected character");}
%%
int yywrap (void) {return 1;}

int getArraySize(char* arr)
{
    int size = strlen(arr);
    char temp[size];
    strcpy(temp, arr);
    char res[size-2];
    int i=0;
    for (i=1; i<size; i++)
        if(temp[i] != '{' && temp[i] != '}')
            res[i-1] = temp[i];
    return atoi(res);
}
