/*	Definition section */
%{
    #include "common.h" //Extern variables that communicate with lex
    // #define YYDEBUG 1
    // int yydebug = 1;

    extern int yylineno;
    extern int yylex();
    extern FILE *yyin;

    void yyerror (char const *s)
    {
        printf("error:%d: %s\n", yylineno, s);
    }

	/* Symbol table variables */
	int scope = 0;
	int address = 0;
	int isArray = 0;
	int assignable = 1;
	int assignable_result = 1;
	struct Table_List *tables = NULL;	

    /* Symbol table function - you can add new function if needed. */
    static void create_symbol();
    static void insert_symbol();
    static char *lookup_symbol();
    static void dump_symbol();
	static void type_error();
%}

%error-verbose
%left LOR
%left LAND
%left EQL NEQ GEQ LEQ '>' '<'
%left '+' '-'
%left '*' '/' '%'

/* Use variable or self-defined structure to represent
 * nonterminal and token type
 */
%union {
    int i_val;
    float f_val;
    char *s_val;
    char *b_val;
	char *type;
	char *operation;
	int scope;
}

/* Token without return */
%token VAR
%token INT FLOAT BOOL STRING
%token INC DEC
%token ADD_ASSIGN SUB_ASSIGN MUL_ASSIGN QUO_ASSIGN REM_ASSIGN
%token NEWLINE
%token PRINT PRINTLN
%token IF ELSE FOR

/* Token with return, which need to sepcify type */
%token <i_val> INT_LIT
%token <f_val> FLOAT_LIT
%token <s_val> STRING_LIT IDENTIFIER
%token <b_val> BOOL_LIT

/* Nonterminal with return, which need to sepcify type */
%type <type> Type TypeName ArrayType
%type <operation> assign_op
%type <type> Literal Operand UnaryExpr PrimaryExpr IndexExpr ConversionExpr Expression
%type <scope> DeclarationStmt

/* Yacc will start at this nonterminal */
%start Program

/* Grammar section */
%%

Program
    : StatementList
;

StatementList
    : StatementList Statement
    | Statement
;

Statement
	: SimpleStmt NEWLINE
	| DeclarationStmt NEWLINE
	| PrintStmt NEWLINE
	| Block NEWLINE
	| IfStmt NEWLINE
	| ForStmt NEWLINE
	| NEWLINE
;

DeclarationStmt
	: VAR IDENTIFIER Type { insert_symbol($2, $3); }
	| VAR IDENTIFIER Type '=' Expression { insert_symbol($2, $3); }
;

SimpleStmt
	: ExpressionStmt
	| IncDecStmt
	| AssignStmt
;

PrintStmt
	: PRINT '(' Expression ')' { printf("PRINT %s\n", $3); }
	| PRINTLN '(' Expression ')' { printf("PRINTLN %s\n", $3); }
;

Block
	: BRACE_UP StatementList BRACE_DOWN { dump_symbol(); scope--; } 
;

IfStmt
	: IF Condition Block 
	| IF Condition Block ELSE IfStmt
	| IF Condition Block ELSE Block
;

ForStmt
	: FOR Condition Block
	| FOR ForClause Block
;

ForClause
	: InitStmt ';' Condition ';' PostStmt
;

InitStmt
	: SimpleStmt
;

PostStmt
	: SimpleStmt
;

Condition
	: Expression { 
		if(strcmp($1, "bool") != 0) 
			type_error("CONDITION", $1, "-"); 
	}
;

ExpressionStmt
	: Expression 
;

IncDecStmt
	: Expression INC { printf("INC\n"); }
	| Expression DEC { printf("DEC\n"); }
;

AssignStmt
	: Expression assign_op Expression {
		if(assignable_result == 0) 
			printf("error:%d: cannot assign to %s\n", yylineno, $1);
		if(strcmp($1, $3) != 0) 
			type_error($2, $1, $3); 
		printf("%s\n", $2); 
		assignable = 1;
	}
;

Expression
	: UnaryExpr	{ $$ = $1; }
	| Expression LOR Expression 	{ 
		if(strcmp($1, "bool") != 0) 
			type_error("LOR", $1, "-");
		else if(strcmp($3, "bool") != 0) 
			type_error("LOR", $3, "-");
		printf("LOR\n");
		$$ = "bool";
		assignable = 0; 
	}
	| Expression LAND Expression 	{ 
		if(strcmp($1, "bool") != 0) 
			type_error("LAND", $1, "-");
		else if(strcmp($3, "bool") != 0) 
			type_error("LAND", $3, "-");
		printf("LAND\n"); 
		$$ = "bool"; 
		assignable = 0; 
	}
	| Expression EQL Expression 	{ printf("EQL\n"); $$ = "bool"; assignable = 0; }
	| Expression NEQ Expression 	{ printf("NEQ\n"); $$ = "bool"; assignable = 0; }
	| Expression GEQ Expression 	{ printf("GEQ\n"); $$ = "bool"; assignable = 0; }
	| Expression LEQ Expression 	{ printf("LEQ\n"); $$ = "bool"; assignable = 0; }
	| Expression '>' Expression 	{ printf("GTR\n"); $$ = "bool"; assignable = 0; }
	| Expression '<' Expression 	{ printf("LSS\n"); $$ = "bool"; assignable = 0; }
	| Expression '+' Expression 	{ if(strcmp($1, $3) != 0) type_error("ADD", $1, $3);  printf("ADD\n"); assignable = 0; }
	| Expression '-' Expression 	{ if(strcmp($1, $3) != 0) type_error("SUB", $1, $3); printf("SUB\n"); assignable = 0; }
	| Expression '*' Expression 	{ printf("MUL\n"); assignable = 0; }
	| Expression '/' Expression 	{ printf("QUO\n"); assignable = 0; }
	| Expression '%' Expression 	{ 
		if(strcmp($1, "int32") != 0) 
			type_error("REM", $1, "-");
		else if(strcmp($3, "int32") != 0) 
			type_error("REM", $3, "-");
		printf("REM\n"); 
		assignable = 0; 
	}
;

UnaryExpr
	: PrimaryExpr { $$ = $1; }
	| '+' UnaryExpr { $$ = $2; printf("POS\n"); assignable = 0; }
	| '-' UnaryExpr { $$ = $2; printf("NEG\n"); assignable = 0; }
	| '!' UnaryExpr { $$ = $2; printf("NOT\n"); assignable = 0; }
;

PrimaryExpr
	: Operand 			{ $$ = $1; }
	| IndexExpr 		{ $$ = $1; }
	| ConversionExpr 	{ $$ = $1; }
;

Operand
	: Literal { $$ = $1; assignable = 0; }
	| IDENTIFIER { $$ = lookup_symbol($1); assignable = 1; }
	| '(' Expression ')' { $$ = $2; }
;

IndexExpr : PrimaryExpr '[' Expression ']' { $$ = $1; assignable = 1; };

ConversionExpr
	: Type '(' Expression ')' { 
		if((strcmp($1, "float32") == 0) && (strcmp($3, "int32") == 0)) 
			printf("I to F\n");
		else if((strcmp($1, "int32") == 0) && (strcmp($3, "float32") == 0))
			printf("F to I\n");
		$$ = $1;
	}
;

Literal
	: INT_LIT 		{ printf("INT_LIT %d\n", $1); $$ = "int32"; }
	| FLOAT_LIT 	{ printf("FLOAT_LIT %f\n", $1); $$ = "float32"; }
	| '"' STRING_LIT '"'	{ printf("STRING_LIT %s\n", $2); $$ = "string"; }
	| BOOL_LIT		{ printf("%s\n", $1); $$ = "bool"; } 
;

assign_op
	: '='			{ $$ = "ASSIGN"; assignable_result = assignable; }
	| ADD_ASSIGN 	{ $$ = "ADD_ASSIGN"; assignable_result = assignable; }
	| SUB_ASSIGN	{ $$ = "SUB_ASSIGN"; assignable_result = assignable; }
	| MUL_ASSIGN	{ $$ = "MUL_ASSIGN"; assignable_result = assignable; }
	| QUO_ASSIGN	{ $$ = "QUO_ASSIGN"; assignable_result = assignable; }
	| REM_ASSIGN	{ $$ = "REM_ASSIGN"; assignable_result = assignable; }
;

Type
	: TypeName { $$ = $1; }
	| ArrayType { $$ = $1; }
;

TypeName
	: INT		{ $$ = "int32"; }
	| FLOAT 	{ $$ = "float32"; }
	| STRING	{ $$ = "string"; }
	| BOOL		{ $$ = "bool"; }
;

ArrayType
	: '[' Expression  ']' Type { $$ = $4; isArray = 1; }
;

BRACE_UP
	: '{' { scope++; create_symbol(); } 
;
BRACE_DOWN
	: '}'
;

%%

/* C code section */
int main(int argc, char *argv[])
{
    if (argc == 2) {
        yyin = fopen(argv[1], "r");
    } else {
        yyin = stdin;
    }

	tables = malloc(sizeof(struct Table_List));
	tables->head = tables->tail = NULL;
	create_symbol();

    yylineno = 0;
    yyparse();

	dump_symbol();

	printf("Total lines: %d\n", yylineno);
    fclose(yyin);
    return 0;
}

static void create_symbol() 
{ 	
	// Create table
	struct Table *newTable = malloc(sizeof(struct Table));
	newTable->scope = scope;

	if(tables->head)
	{
		newTable->next = tables->head;
		tables->head = newTable;
	}
	else
	{
		tables->head = tables->tail = newTable;
	}
}

static void insert_symbol(char *id, char *type) {

	struct Table *table = tables->head;

	// Check if redeclared
	struct Symbol *symbol = table->head;
	while(symbol)
	{
		if(strcmp(id, symbol->name) == 0)
		{
			printf("error:%d: %s redeclared in this block. previous declaration at line %d\n", yylineno, id, symbol->lineno);
			return;
		}
		symbol = symbol->next;
	}
	
	// Create new symbol
	struct Symbol *newSymbol = malloc(sizeof(struct Symbol));
	newSymbol->name = strdup(id);
	newSymbol->address = address++;
	newSymbol->lineno = yylineno;
	if(isArray)
	{
		newSymbol->type = strdup("array");
		newSymbol->element_type = strdup(type);
		isArray = 0;
	}
	else
	{
		newSymbol->type = strdup(type);
		newSymbol->element_type = strdup("-");
	}
	newSymbol->next = NULL;
	
	if(table->head)
	{
		newSymbol->index = table->tail->index + 1;
		table->tail->next = newSymbol;
		table->tail = newSymbol;
	}
	else
	{
		newSymbol->index = 0;
		table->head = table->tail = newSymbol;
	}		
	
	// Print message
    printf("> Insert {%s} into symbol table (scope level: %d)\n", id, scope);
}

static char* lookup_symbol(char* id)
{
	
	struct Table *table = tables->head;
	while(table)
	{
		struct Symbol *symbol = table->head;
		while(symbol)
		{
			if(strcmp(id, symbol->name) == 0)
			{
				printf("IDENT (name=%s, address=%d)\n", id, symbol->address);
				return strcmp(symbol->type, "array") == 0 ? symbol->element_type : symbol->type;
			}
			else
				symbol = symbol->next;
		}
		table = table->next;
	}
	printf("error:%d: undefined: %s\n", yylineno + 1, id);
	return "none";
}

static void dump_symbol() 
{
	struct Table *table = tables->head;
	
	// Print table info
    printf("> Dump symbol table (scope level: %d)\n", table ? table->scope : 0);
    printf("%-10s%-10s%-10s%-10s%-10s%s\n",
           "Index", "Name", "Type", "Address", "Lineno", "Element type");
	
	if(!table) return;

	// Print symbols
	struct Symbol *symbol = table->head;
	while(symbol)
	{
    	printf("%-10d%-10s%-10s%-10d%-10d%s\n",
            	symbol->index, symbol->name, symbol->type, symbol->address, symbol->lineno, symbol->element_type);
		symbol = symbol->next;
	}
	
	// Release symbols
	symbol = table->head;
	while(symbol)
	{
		struct Symbol *temp = symbol->next;
		free(symbol->name);
		free(symbol->type);
		free(symbol->element_type);
		free(symbol);
		symbol = temp;
	}
	
	// Remove table
	struct Table *newHead = tables->head->next;
	tables->head->head = tables->head->tail = NULL;
	free(tables->head);
	tables->head = newHead;
}

static void type_error(char *operator, char *typeA, char *typeB)
{
	if(
		strcmp(typeA, "none") == 0 ||
		strcmp(typeB, "none") == 0
	)
		return;

	if(
		strcmp(operator, "ADD") == 0 ||
		strcmp(operator, "SUB") == 0 ||
		strcmp(operator, "ASSIGN") == 0
	)
		printf("error:%d: invalid operation: %s (mismatched types %s and %s)\n", yylineno, operator, typeA, typeB);

	else if(
		strcmp(operator, "REM") == 0 ||
		strcmp(operator, "LAND") == 0 ||
		strcmp(operator, "LOR") == 0
	)
		printf("error:%d: invalid operation: (operator %s not defined on %s)\n", yylineno, operator, typeA);

	else if(
		strcmp(operator, "CONDITION") == 0
	)
		printf("error:%d: non-bool (type %s) used as for condition\n", yylineno + 1, typeA);
};

