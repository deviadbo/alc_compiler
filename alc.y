%{
#include <stdio.h>     							
#include <stdlib.h>
#include <ctype.h>
#include <string.h>
#include <stdbool.h>
#include <time.h>
#include "alc.h"

void yyerror(char *s);
int yylex();
extern int yylineno; 
extern FILE* yyin;
extern FILE * yyout;

//Array for reserved Index
char reservedIndex[ID_LEN];
int ecounter=0;	

//Array for Reserved Vars
char reserved[ARR_LEN] = "e";					
//Comma table counter	
int expArray = 1;	

//Comma Expression table					
Expression commaArray[ARR_LEN];					

// The Symbol table
ST_Var symbols[SYM_TABLE_SIZE];	
// Variable Table - Map for vars to symbol table					
char vars[SYM_TABLE_SIZE][ID_LEN];  					

//Table for temporary const arr 
ConstArrST_Var ConstArrArray[ARR_LEN];	
//Arr index counter
int arrIndxCount = -1;							
//Table temporary const integer
ConstIntST_Var ConstSclArray[ARR_LEN];			
//Counter for int index
int intIndxCount= -1;							

//Symbol Table Functions
void setSymbolTable(char *vName, varType type, int size);		
Expression getSymIndex(char *name, char mode);					
int variablesIndex(char *name, char mode);						

//Constant Table Functions
Expression constsArrUpdate(char* value);						
Expression constsIntUpdate(int value);						

//Show Screen
void startMsg();
void compileC_file();
void printC_file();

//Translaros
void statementTranslator(Expression exp);									
void ExpressionTranslator(Expression exp, int enter);								
void commaTranslator(Expression L_exp, Expression R_exp);						
void BlocksTranslator(Expression exp, char* stat);							
Expression AssignmentTranslator(Expression L_exp, Expression R_exp);							
Expression TermTranslator(Expression term);									
Expression OpExpTranslator(Expression L_exp, char* oper, Expression R_exp);		
Expression ArrExpTranslator(Expression L_exp, char* oper, Expression R_exp);
Expression condTranslator(Expression L_exp, char* relop, Expression R_exp);	
void CondTitleTranslator(Expression condi, char *cond_kind);	
void intralVarCreator(int count, char* result);		
void createDynamicArr(char *name);
%}

%union 
{
	int size;
	int num;
	char elem[ARR_LEN]; 
	char vName[ID_LEN];
	int IndnVar[3];
	Expression expr;
}      
	
/* Yacc definitions */
%start program                                      
%token intx arr
%token print
%token begin end
%token COMMENT msg
%token WHILE
%token IF
%token THEN DO
%token GE LE EQ NE BE SE
%token <vName> identifier
%token <size> arraysSize
%token <num> number
%token <elem> constArray
%token exit_command

%type <expr> term
%type <expr> line exp assignment cond expression_list

%left '(' ')'
%left '@'
%left GE LE EQ NE BE SE
%left '*' '/'
%left '+' '-'
%left ','
%left ':'
%right '='


%%

program		: block							{;} //Have to start with BEGIN
			;
block		: begin line end				{fprintf(yyout, "\t}\n");}
			| begin end						{fprintf(yyout, "\t}\n");}
			;
line    	: assignment ';'				{;}	
			| line assignment ';'			{;}
			| def ';'						{;}
			| line def ';'					{;}			
			| statement ';'					{;}
			| line statement ';'			{;}
			| conditional block				{;}
			| line conditional block 		{;}
			| loop block					{;}
			| line loop block 				{;}
        	;
assignment  : exp '=' exp  					{$$ = AssignmentTranslator($1, $3);}
			;
statement	: exp							{;} 
			| print expression_list			{statementTranslator($2);}	 
			;

expression_list: expression_list ',' exp	{ExpressionTranslator($3, 1);}	
			   | exp						{;}	
			   ;

conditional	: IF '(' cond ')' THEN  	    {CondTitleTranslator($3 ,"IF");}
			;
loop		: WHILE '(' cond ')' DO  	    {CondTitleTranslator($3 ,"WHILE");}
			;
exp    		: term                  		{$$ = TermTranslator($1);}
       		| exp '+' exp					{$$ = OpExpTranslator($1, "+", $3);}
			| exp '-' exp					{$$ = OpExpTranslator($1, "-", $3);}
			| exp '*' exp					{$$ = OpExpTranslator($1, "*", $3);}
			| exp '/' exp					{$$ = OpExpTranslator($1, "/", $3);}
			| exp '@' exp					{$$ = ArrExpTranslator($1, "@", $3);}
			| exp ':' exp					{$$ = ArrExpTranslator($1, ":", $3);}
			| '(' exp ')'					{$$ = $2;}
			| exp ',' exp					{$$ =  $3; commaTranslator($1, $3);}
       		;

cond		: exp BE exp		 	 		{$$ = condTranslator($1, ">", $3);}	
			| exp SE exp	 	 			{$$ = condTranslator($1, "<", $3);}	
			| exp GE exp	 	 			{$$ = condTranslator($1, ">=", $3);}	
			| exp LE exp	 	 			{$$ = condTranslator($1, "<=", $3);}	
			| exp EQ exp	 	 			{$$ = condTranslator($1, "==", $3);}
			| exp NE exp	 	 			{$$ = condTranslator($1, "!=", $3);}	
			;

term   		: number                		{$$ = constsIntUpdate($1);}
			| constArray					{$$ = constsArrUpdate($1);}
			| identifier					{$$ = getSymIndex($1, GET);} 
			;
int_ident_list  : identifier 				{fprintf(yyout, "\tint %s;\n", $1); setSymbolTable($1, integer, 0);}	
			| int_ident_list ',' int_ident_list 	{;}	
			; 
def			: intx int_ident_list			{;}
			| arr identifier 				{createDynamicArr($2);}
			;


%%                     

//Functionality

void printComment(char* comment)
{
	fprintf(yyout, "\nprintf('\"\nim comm: %s\n\");\n", comment);
}

void createDynamicArr(char *name)
{
	setSymbolTable(name, array, 0);
	fprintf(yyout, "\tint *%s = NULL;\n", name);
	int sIndex = variablesIndex(name, GET);
	//Create Expression for saving the size of Dynamic Array
	/*e-i create*/
	Expression arrSize;
	arrSize.ecounter = ecounter++;
	intralVarCreator(arrSize.ecounter, arrSize.name);
	arrSize.indx = -1;
	strcpy(symbols[sIndex].sizeVar_E_Name, arrSize.name);
	//ei for arr size
	fprintf(yyout, "\tint %s = %d; //e for size arr\n", arrSize.name, 0);
}

void delay(int milli_seconds)
{
    // Converting time into milli_seconds
    //int milli_seconds = 10 * number_of_tseconds;
    //int milli_seconds = 1000 * number_of_seconds;
    
	// Storing start time
    clock_t start_time = clock();
  
    // looping till required time is not achieved
    while (clock() < start_time + milli_seconds)
        ;
}

int variablesIndex(char *name, char mode)
{
	switch (mode)
	{
	case GET: /* Return index of variable from symbol table */
	{
		int i = 0;
		for (i = 0; i < SYM_TABLE_SIZE; i++)
		{
			if (!strcmp(vars[i], "-1"))
				return -1;
			else if (!strcmp(name, vars[i]))
				return i; /* ID found */
		}
		return -1;
	}
	case SET: /* Sets the index of variable from symbol table and then returns the index */
	{
		int i = 0;
		for (i = 0; i < SYM_TABLE_SIZE; i++)
		{
			if (!strcmp(name, &vars[i][0]))
			/* ID already exists */
			{
				char msg[100] = "Variable name ";
				strcat(msg, name);
				strcat(msg," already exist, choose diffrent name.");
				yyerror(msg);
			}
			else if (!strcmp(vars[i], "-1"))
			{
				strcpy(vars[i], name);
				return i;
			}
		}
		return -1;
	}
	}
}

int returnArrIndex(char *arrName)
{
	return variablesIndex(arrName, GET);
}

void setArrayNewSize(char *arrName, int newSize)
{
	int indx = variablesIndex(arrName, GET);
	symbols[indx].size = newSize;
}

// Update variable in symbol table
void setSymbolTable(char *vName, varType type, int size)
{
	int sIndex = variablesIndex(vName, SET);
	if (sIndex == -1)
	{
		char msg[100] = "Variable name ";
		strcat(msg, vName);
		strcat(msg," already exist, choose diffrent name");
		yyerror(msg);
	}
	symbols[sIndex].type = type;
	symbols[sIndex].size = size;
	symbols[sIndex].indx = sIndex;
	strcpy(symbols[sIndex].name, vName);
	//fprintf(yyout, "\t//in setSymbolTable var %s size= %d\n", symbols[sIndex].name, symbols[sIndex].size );
}

/* Returns the variable index from symbol table */
Expression getSymIndex(char *name, char mode)
{
	Expression expressionResult;
	int sIndex = variablesIndex(name, mode);
	if (sIndex == -1)
	{
		yyerror("Variable does not exist");
	}
	expressionResult.indx = sIndex;
	expressionResult.type = symbols[sIndex].type;
	expressionResult.ecounter = -1;
	expressionResult.size = symbols[sIndex].size;
	strcpy(expressionResult.name, symbols[sIndex].name);
	return expressionResult;
}

/* update const arrays table */
Expression constsArrUpdate(char *value)
{
	Expression expressionResult;
	arrIndxCount++;
	ConstArrArray[arrIndxCount].indx = arrIndxCount;

	/* calc array size */
	int count = 0;
	int i = 0;
	for (i = 0; value[i] != '\0'; i++)
	{ /* count size of array */
		if (value[i] == ',')
		{
			count++;
		}
		// Replace [ to {
		if (value[i] == '[')
		{
			value[i] = '{';
		}
		// Replace ] to }
		if (value[i] == ']')
		{
			value[i] = '}';
		}
	}
	count++;
	ConstArrArray[arrIndxCount].size = count;
	strcpy(ConstArrArray[arrIndxCount].val, value);
	expressionResult.indx = arrIndxCount;
	expressionResult.type = constArr;
	expressionResult.ecounter = -1;
	expressionResult.size = count;
	return expressionResult;
}

// Update constant integer table
Expression constsIntUpdate(int value)
{
	Expression expressionResult;
	intIndxCount++;
	ConstSclArray[intIndxCount].val = value;
	ConstSclArray[intIndxCount].indx = intIndxCount;

	expressionResult.indx = intIndxCount;
	expressionResult.type = constInt;
	expressionResult.ecounter = -1;
	expressionResult.size = 0;
	return expressionResult;
}

Expression TermTranslator(Expression term)
{
	Expression exp;
	exp.type = term.type;
	exp.indx = term.indx;

	/* print term */
	if (term.type == array)
	{
		exp.ecounter = -1;
		exp.size = term.size;
		strcpy(exp.name, term.name);
	}
	else if (term.type == integer)
	{
		exp.ecounter = -1;
		exp.size = 0;
		strcpy(exp.name, term.name);
	}
	else if (term.type == constArr)
	{
		exp.ecounter = ecounter;
		intralVarCreator(exp.ecounter, exp.name);
		exp.size = term.size;
		fprintf(yyout, "\tint e%d[] = %s;\n", exp.ecounter, ConstArrArray[term.indx].val);
		ecounter++;
	}
	else if (term.type == constInt)
	{
		exp.ecounter = ecounter;
		intralVarCreator(exp.ecounter, exp.name);
		exp.size = term.size;
		fprintf(yyout, "\tint e%d = %d;\n", exp.ecounter, ConstSclArray[term.indx].val);
		ecounter++;
	}
	return exp;
}

/* Assignment */
Expression AssignmentTranslator(Expression L_exp, Expression R_exp)
{
	Expression expressionResult;
	expressionResult.indx = L_exp.indx;
	expressionResult.size = L_exp.size;
	strcpy(expressionResult.name, L_exp.name);
	expressionResult.type = L_exp.type;
	expressionResult.ecounter = L_exp.ecounter;

	/* if exp type is integer */
	if (L_exp.type == integer || L_exp.type == constInt)
	{
		if (R_exp.type == integer || R_exp.type == constInt)
		{
			fprintf(yyout, "\t%s = %s;\n", L_exp.name, R_exp.name);
		}
		else
		{
			yyerror("integer can not be equal to array");
		}
		/* if exp type is array */
	}
	else if (L_exp.type == array || L_exp.type == constArr)
	{
		if (R_exp.type == integer || R_exp.type == constInt)
		{	
			//update vars in arr
			int indxName = variablesIndex(L_exp.name, GET);
			char* L_expSize = symbols[indxName].sizeVar_E_Name;
			fprintf(yyout, "\tfor(gIterator = 0; gIterator < %s; gIterator++){\n", L_expSize);
			//fprintf(yyout, "\tfor(gIterator = 0; gIterator < %d; gIterator++){\n", L_exp.size);
			fprintf(yyout, "\t\t%s[gIterator] = %s;\n\t}\n", L_exp.name, R_exp.name);

		}
		else if (R_exp.type == array || R_exp.type == constArr)
		{
				expressionResult.size = R_exp.size;
				
				//Assign expression result to l-value variable,
				//erases previous value	
				fprintf(yyout, "\t%s = (int*)realloc(%s, (%d)*sizeof(int));\n", expressionResult.name, expressionResult.name, expressionResult.size);			;
				fprintf(yyout, "\tfor(gIterator = 0; gIterator < %d; gIterator++)\n", expressionResult.size);
				fprintf(yyout, "\t\t%s[gIterator]=%s[gIterator];\n", expressionResult.name,R_exp.name);

				int indxName = variablesIndex(expressionResult.name, GET);
				char* ename = symbols[indxName].sizeVar_E_Name;
				fprintf(yyout, "\n\t%s = %d;",ename, expressionResult.size); 

				symbols[indxName].size = expressionResult.size;
		}
		else
			yyerror("Wrong input when assigned array");

	}
	else
		yyerror("Not valid Expression");
	return expressionResult;
}


// Cond Translate
Expression condTranslator(Expression L_exp, char *relop, Expression R_exp)
{
	// The condition is a non-complex expression
	bool ret = false;
	Expression expressionResult;
	strcpy(expressionResult.name, "ERROR");
	if (L_exp.type == integer || L_exp.type == constInt)
	{
		if (R_exp.type == integer || R_exp.type == constInt)
		{
			strcpy(expressionResult.name, L_exp.name);
			strcat(expressionResult.name, relop);
			strcat(expressionResult.name, R_exp.name);
			//fprintf(yyout, "(%s %s %s)\n\t{", L_exp.name, relop, R_exp.name);
			//Switch
			if (strcmp(relop, ">")==0)
					ret = L_exp.size > R_exp.size; 
			else if (strcmp(relop, "<")==0)
					ret = L_exp.size < R_exp.size; 
			else if (strcmp(relop, ">=")==0)
					ret = L_exp.size >= R_exp.size; 
			else if (strcmp(relop, "<=")==0)
					ret = L_exp.size <= R_exp.size; 
			else if (strcmp(relop, "==")==0)
					ret = L_exp.size == R_exp.size; 
			else if (strcmp(relop, "!=")==0)
					ret = L_exp.size != R_exp.size; 
		}
		else
			yyerror("Wrong condition types");
	}
	else
		yyerror("Wrong condition types");
	return expressionResult;
}

//Expressions Translte
Expression OpExpTranslator(Expression L_exp, char *oper, Expression R_exp)
{
	Expression expressionResult;
	expressionResult.ecounter = ecounter++;
	intralVarCreator(expressionResult.ecounter, expressionResult.name);
	expressionResult.indx = -1;
	if (L_exp.type == integer || L_exp.type == constInt)
	{
		if (R_exp.type == integer || R_exp.type == constInt)
		{
			expressionResult.type = constInt;
			expressionResult.size = 0;
			fprintf(yyout, "\tint %s = %s %s %s;\n", expressionResult.name, L_exp.name, oper, R_exp.name);
		}
		else if (R_exp.type == array || R_exp.type == constArr)
		{
			yyerror("Action not supported");
		}
	}
	else 
	if ((L_exp.type == array || L_exp.type == constArr) && (R_exp.type == array || R_exp.type == constArr))
	{
		expressionResult.type = constArr;
		//expressionResult.size = L_exp.size;

		fprintf(yyout, "\tint* %s = NULL;\n", expressionResult.name);
		int indxName = variablesIndex(L_exp.name, GET);
		char* L_expSize = symbols[indxName].sizeVar_E_Name;
		
		fprintf(yyout, "\n//size of L_exp: %d;\n", symbols[indxName].size);
		
		indxName = variablesIndex(R_exp.name, GET);
		char* R_expSize = symbols[indxName].sizeVar_E_Name;

		fprintf(yyout, "\n//size of R_exp %d;\n", symbols[indxName].size);
		
		fprintf(yyout, "\tif (%s >= %s)\n{", L_expSize, R_expSize);
		//if L_expSize big
		fprintf(yyout, "\tint resSize = %s;\n", L_expSize);
		fprintf(yyout, "\t%s = (int*)realloc(%s, (%s)*sizeof(int));\n", expressionResult.name, expressionResult.name, "resSize");			;
		
		fprintf(yyout, "\tfor(gIterator = 0; gIterator < %s; gIterator++)\n", "resSize");
		fprintf(yyout, "\t\t%s[gIterator]=%s[gIterator];\n", expressionResult.name,L_exp.name);
		fprintf(yyout, "\tfor(gIterator = 0; gIterator < %s; gIterator++){\n", R_expSize);
		fprintf(yyout, "\t\t%s[gIterator]=%s[gIterator] %s %s[gIterator];}}", expressionResult.name,expressionResult.name,oper,R_exp.name);
		
		//else
		fprintf(yyout, "\t\nelse\n{\n\t int resSize = %s;\n", R_expSize);
		fprintf(yyout, "\t%s = (int*)realloc(%s, (%s)*sizeof(int));\n", expressionResult.name, expressionResult.name, "resSize");	
		fprintf(yyout, "\tfor(gIterator = 0; gIterator < %s; gIterator++)\n", "resSize");
		fprintf(yyout, "\t\t%s[gIterator]=%s[gIterator];\n", expressionResult.name,R_exp.name);
		fprintf(yyout, "\tfor(gIterator = 0; gIterator < %s; gIterator++){\n", L_expSize);
		fprintf(yyout, "\t\t%s[gIterator]=%s[gIterator] %s %s[gIterator];}\n}", expressionResult.name,expressionResult.name,oper,L_exp.name);

		//Update the expressionResult size
		expressionResult.size = L_exp.size >= R_exp.size ? L_exp.size : R_exp.size;
		fprintf(yyout, "\n//L_exp.size=%d. R_exp.size=%d",L_exp.size,R_exp.size);
		fprintf(yyout, "\n//DEST - expressionResult.size=%d\n",expressionResult.size);
	}
	else
	{
		yyerror("Wrong variable type");
	}
	return expressionResult;
}

int returnValOfEi(int idx)
{
	return (ConstSclArray[idx].val);
}

int returnSizeOfInt(char* var_name)
{
	int indx = variablesIndex(var_name, GET);
	//fprintf(yyout, "// returnSizeOfInt var %s ,size= %d\n", symbols[indx].name, symbols[indx].size);
	return symbols[indx].size;
}

Expression ArrExpTranslator(Expression L_exp, char *oper, Expression R_exp)
{
	if (L_exp.type == integer || L_exp.type == constInt)
	{
		yyerror("not valid operand for integer");
	}
	Expression expressionResult;
	expressionResult.ecounter = ecounter++;
	intralVarCreator(expressionResult.ecounter, expressionResult.name);
	expressionResult.indx = -1;
	if (strcmp(oper, "@") == 0)
	{
		if (R_exp.type == integer || R_exp.type == constInt)
		{
			yyerror("not valid operand for scalar");
		}
		/*if (L_exp.size != R_exp.size)
		{
			yyerror("array size not equel");
		}*/
		else
		{
			int indxName = variablesIndex(L_exp.name, GET);
			char* enameOfSizeArr = symbols[indxName].sizeVar_E_Name;
			expressionResult.type = constInt;
			expressionResult.size = 0;
			fprintf(yyout, "\t//Dot product\n");
			fprintf(yyout, "\tint %s = 0;\n", expressionResult.name);
			fprintf(yyout, "\tfor(gIterator = 0; gIterator < %s; gIterator++){\n", enameOfSizeArr);
			//fprintf(yyout, "\tfor(gIterator = 0; gIterator < %d; gIterator++){\n", L_exp.size);
			fprintf(yyout, "\t\t%s += %s[gIterator] * %s[gIterator];\n\t}\n", expressionResult.name, L_exp.name, R_exp.name);
			fprintf(yyout, "\t//Dot product\n");
		}
	}
	else if (strcmp(oper, ":") == 0)
	{
		if (R_exp.type == integer || R_exp.type == constInt)
		{
			fprintf(yyout, "\n\n//START op:\n");	
			expressionResult.type = constInt;
			expressionResult.size = 0;
			fprintf(yyout, "\tint* %s = 0;\n", expressionResult.name);
			
			//int arrSize = returnSizeOfInt(L_exp.name);
			//fprintf(yyout, "\t//in op: var %s s = %d\n", "arrSize", arrSize);
			//fprintf(yyout, "\t//in op: var %s s = %d\n", L_exp.name, L_exp.size);
			
			//fprintf(yyout, "\tif(%s >= 0 && %s < ((sizeof(%s)/sizeof(int))-1)){\n", R_exp.name, R_exp.name, L_exp.name);
		

			//fprintf(yyout, "\tif(%s >= 0 && %s < %d){\n", R_exp.name, R_exp.name, L_exp.size);
			
			//Get the name of the uniqe size of array
			int indxName = variablesIndex(L_exp.name, GET);
			char* enameOfSizeArr = symbols[indxName].sizeVar_E_Name;

			//fprintf(yyout, "\tif(%s >= 0 && %s < %s){\n", R_exp.name, R_exp.name, arrSize.name);
			fprintf(yyout, "\tif(%s >= 0 && %s < %s){\n", R_exp.name, R_exp.name, enameOfSizeArr);

			fprintf(yyout, "\t\t%s = &%s[%s];\n\t}\n", expressionResult.name, L_exp.name, R_exp.name);
			
			//before
			//fprintf(yyout, "\telse{fprintf(stderr, \"index out of range\"); exit(0);}\n");
			
			//ELSE
			fprintf(yyout, "\telse{\n\t\t");		
			int R_expindx = variablesIndex(R_exp.name, GET);
			fprintf(yyout, "//in OP:  R_exp.name is %s\n", R_exp.name);			
			int newVal = 0;
			if (R_exp.type == constInt)
				//Get val of e-i
				newVal = returnValOfEi(R_exp.indx)+1;
				//newVal = returnValOfEi(indxName);
			else
				//Get the size of intger
				{
					int ind = variablesIndex(R_exp.name, GET);
					newVal = symbols[ind].size;
				}

			// if new val >= size of array -> set new size
			if (newVal > L_exp.size)
				setArrayNewSize(L_exp.name, newVal);
			
			fprintf(yyout, "//in OP: newVal of %s = size %d\n", L_exp.name, newVal);
			
			expressionResult.size = newVal;
			//fprintf(yyout, "\t\t%s = (int*)realloc(%s, (%s+1)*sizeof(int));\n", L_exp.name, L_exp.name, enameOfSizeArr);		
			fprintf(yyout, "%s = (int*)realloc(%s, (%s+1)*sizeof(int));\n", L_exp.name, L_exp.name, R_exp.name);					
			fprintf(yyout, "\t\t%s = &%s[%s];\n", expressionResult.name, L_exp.name, R_exp.name);
			fprintf(yyout, "\t\t%s = %s + 1;\n\t}\n", enameOfSizeArr, enameOfSizeArr);
			
			/*Notes*/
			fprintf(yyout, "\t//in op: L_exp %s = %d\n", L_exp.name, L_exp.size);
			fprintf(yyout, "\t//in op: R_exp %s = %d\n", R_exp.name, R_exp.size);
			fprintf(yyout, "\t//in op: expressionResult % s = %d\n", expressionResult.name, expressionResult.size);

			//change the expressionResult var to pointer
			snprintf(expressionResult.name, strlen(expressionResult.name) + 2, "*%s", strdup(expressionResult.name));
			fprintf(yyout, "//DONE op\n\n");			
		}
	}
	return expressionResult;
}

// Recognize ',' in statement
void statementTranslator(Expression exp)
{
	if (expArray > 1)
	{
		int i = 0;
		for (i = 0; i < expArray - 1; i++)
		{
			ExpressionTranslator(commaArray[i], 0);
			fprintf(yyout, "\tprintf(\", \");\n");
		}
		ExpressionTranslator(commaArray[expArray - 1], 1);
	}
	else
	{
		ExpressionTranslator(exp, 1);
	}
	expArray = 1;
}

void ExpressionTranslator(Expression exp, int enter)
{
	if (exp.type == array || exp.type == constArr)
	{
		fprintf(yyout, "//Print array\n");
		fprintf(yyout, "\t//var %s size = %d\n", exp.name, exp.size);
		fprintf(yyout, "\tprintf(\"[\");\n");

		//Get the name of the uniqe size of array
		int indxName = variablesIndex(exp.name, GET);
		char* enameOfSizeArr = symbols[indxName].sizeVar_E_Name;

		if (indxName == -1)
		{
			char buff[10];
			itoa(exp.size, buff, 10);
			strcpy(enameOfSizeArr, buff);
		}

		//fprintf(yyout, "//ARR SIZE IS %d\n", exp.size);
		//fprintf(yyout, "\tfor(gIterator = 0; gIterator < %d - 1; gIterator++){\n", exp.size);
		fprintf(yyout, "\tfor(gIterator = 0; gIterator < %s - 1; gIterator++){\n", enameOfSizeArr);
		fprintf(yyout, "\t\tprintf(\"%%d,\",%s[gIterator]);\n\t}\n\tprintf(\"%%d\", %s[%s - 1]);\n", exp.name, exp.name, enameOfSizeArr);
		
		if (enter == 0)
		{
			fprintf(yyout, "\tprintf(\"]\");\n");
		}
		else if (enter == 1)
		{
			fprintf(yyout, "\tprintf(\"]\\n\");\n");
		}
		fprintf(yyout, "//DONE PRINT ARRAY\n");
	}
	else if (exp.type == integer || exp.type == constInt)
	{
		if (enter == 0)
		{
			fprintf(yyout, "\tprintf(\"%%d\", %s);\n", exp.name);
		}
		else if (enter == 1)
		{
			fprintf(yyout, "\tprintf(\"%%d\\n\", %s);\n", exp.name);
		}
	}
}

void commaTranslator(Expression L_exp, Expression R_exp)
{
	commaArray[expArray - 1] = L_exp;
	expArray++;
	commaArray[expArray - 1] = R_exp;
}

// Block statements
void BlocksTranslator(Expression exp, char *stat)
{
	if (strcmp(stat, "IF") == 0)
	{
		if (exp.type == integer || exp.type == constInt)
		{
			fprintf(yyout, "\tif (%s)\n{\t\n", exp.name);
		}
		else
		{
			yyerror("Only integer allowed");
		}
	}
	else if (strcmp(stat, "loop") == 0)
	{
		if (exp.type == integer || exp.type == constInt)
		{
			fprintf(yyout, "\tfor(gIterator = 0; gIterator < %s; gIterator++){\n", exp.name);
		}
		else
		{
			yyerror("Only integer allowed");
		}
	}
}


void CondTitleTranslator(Expression condi, char *cond_kind)
{
	if (strcmp(cond_kind, "IF") == 0)
	{
		fprintf(yyout, "\t//START IF\n");
		fprintf(yyout, "\tif (%s)\n\t{\n", condi.name);
	}
	else if (strcmp(cond_kind, "WHILE") == 0)
	{
		fprintf(yyout, "\t//START WHILE\n");
		fprintf(yyout, "\twhile (%s)\n\t{\n", condi.name);
	}
}

void intralVarCreator(int count, char *result)
{
	char reserved[255] = "e";
	char reservedIndex[31];
	sprintf(reservedIndex, "%d", count);
	strcat(reserved, reservedIndex);
	strcpy(result, reserved);
	//result -> e-i
}

/* THE MAIN */
int main(int argc, char *argv[])
{
	if (argc == 2)
	{
		yyin = fopen(argv[1], "r");
		if (!yyin)
		{
			printf("The '%s' source file cannot be opened\n", argv[1]);
			printf("Try agian...");
			return 1;
		}
	}

	yyout = fopen("output.c", "w");

	/* Initialize variable table */
	int i = 0;
	for (i = 0; i < SYM_TABLE_SIZE; i++)
		strcpy(vars[i], "-1");

	arrIndxCount = -1;
	intIndxCount = -1;
	ecounter = 0;
	fprintf(yyout, "// Created by Another Language Compiler\n");
	fprintf(yyout, "#include <stdio.h>\n");
	fprintf(yyout, "#include <stdlib.h>\n");
	fprintf(yyout, "#include <string.h>\n");
	fprintf(yyout, "//Global Iterator\n");
	fprintf(yyout, "int gIterator=0;\n\n");
	fprintf(yyout, "//Start of source code translation\n");

	// Print main function
	fprintf(yyout, "\nint main(void)\n{\n");
	
	// Translate
	yyparse();
	
	//End
	fprintf(yyout, "//End of translation");
	fclose(yyout);
	fclose(yyin);

	startMsg();
	//printC_file();
	compileC_file();	
	return 0;
}

void yyerror(char *s)
{
	fprintf(stderr, "%s in line: %d", s, yylineno);
	exit(0);
}

void startMsg()
{
	delay(500);
	// Message for the user
	printf("\n\n  Another Language Complier:\n");
	delay(500);
	printf("\n  output.c C file created successfully!\n");
	delay(500);
	printf("\n  The translation process was carried out successfully\n");
	delay(500);
	int time = 30;
	//system("cls");
	delay(time); printf("\n\nCompile C file");
	delay(time); printf(".");
	delay(time); printf(".");
	delay(time); printf(".\n");
	
}

void printC_file()
{
	printf("\n\n output.c:\n\n");
	// Read contents from file
    FILE* fptr = fopen("output.c", "r");
    int time = 1;
	char c = fgetc(fptr);
	while (c != EOF)
    {
		printf ("%c", c);
		if (c=='\n')
			printf ("  ");
        c = fgetc(fptr);
		delay(time);
    }
	fclose(fptr);
}
void compileC_file()
{
	int t = 0;
	system("gcc output.c -o output.exe");
	delay(t);
	//system("cls");
	delay(t); printf("\nRun output.exe\n\n");
	delay(t);
	system("output.exe");
}