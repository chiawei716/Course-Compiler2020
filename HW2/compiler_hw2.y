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
	struct Table_List *tables = NULL;
		
	//tables.head = tables->tail = malloc(sizeof(struct Table));
	//(tables.head)->head = (tables.head)->tail = NULL;

    /* Symbol table function - you can add new function if needed. */
    static void create_symbol();
    static void insert_symbol();
    static char *lookup_symbol();
    static void dump_symbol();
	static void printAll();
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
%type <type> Expression
%type <type> Literal Operand UnaryExpr PrimaryExpr
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

ExpressionStmt : Expression ;

IncDecStmt
	: Expression INC { printf("INC\n"); }
	| Expression DEC { printf("DEC\n"); }
;

AssignStmt
	: Expression assign_op Expression { printf("%s\n", $2); }
;

Expression
	: UnaryExpr	{ $$ = $1; }
	| Expression LOR Expression 	{ printf("LOR\n"); $$ = "bool"; }
	| Expression LAND Expression 	{ printf("LAND\n"); $$ = "bool"; }
	| Expression EQL Expression 	{ printf("EQL\n"); }
	| Expression NEQ Expression 	{ printf("NEQ\n"); }
	| Expression GEQ Expression 	{ printf("GEQ\n"); }
	| Expression LEQ Expression 	{ printf("LEQ\n"); }
	| Expression '>' Expression 	{ printf("GTR\n"); }
	| Expression '<' Expression 	{ printf("LTR\n"); }
	| Expression '+' Expression 	{ printf("ADD\n"); }
	| Expression '-' Expression 	{ printf("SUB\n"); }
	| Expression '*' Expression 	{ printf("MUL\n"); }
	| Expression '/' Expression 	{ printf("QUO\n"); }
	| Expression '%' Expression 	{ printf("REM\n"); }
;

UnaryExpr
	: PrimaryExpr { $$ = $1; }
	| '+' UnaryExpr { printf("POS\n"); }
	| '-' UnaryExpr { printf("NEG\n"); }
	| '!' UnaryExpr { printf("NOT\n"); }
;

PrimaryExpr
	: Operand { $$ = $1; }
	| IndexExpr
	| ConversionExpr
;

Operand
	: Literal { $$ = $1; }
	| IDENTIFIER { $$ = lookup_symbol($1); }
	| '(' Expression ')' { $$ = $2; }
;

IndexExpr : PrimaryExpr '[' Expression ']' ;

ConversionExpr
	: Type '(' Expression ')' { 
		if((strcmp($1, "float32") == 0) && (strcmp($3, "int32") == 0)) 
			printf("I to F\n");
		else if((strcmp($1, "int32") == 0) && (strcmp($3, "float32") == 0))
			printf("F to I\n");
	}
;

Literal
	: INT_LIT 		{ printf("INT_LIT %d\n", $1); $$ = "int32"; }
	| FLOAT_LIT 	{ printf("FLOAT_LIT %f\n", $1); $$ = "float32"; }
	| '"' STRING_LIT '"'	{ printf("STRING_LIT %s\n", $2); $$ = "string"; }
	| BOOL_LIT		{ printf("%s\n", $1); $$ = "bool"; } 
;

assign_op
	: '='			{ $$ = "ASSIGN"; }
	| ADD_ASSIGN 	{ $$ = "ADD_ASSIGN"; }
	| SUB_ASSIGN	{ $$ = "SUB_ASSIGN"; }
	| MUL_ASSIGN	{ $$ = "MUL_ASSIGN"; }
	| QUO_ASSIGN	{ $$ = "QUO_ASSIGN"; }
	| REM_ASSIGN	{ $$ = "REM_ASSIGN"; }
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
	return NULL;
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

static void printAll()
{
	struct Table *table = tables->head;
	while(table)
	{
		struct Symbol *symbol = table->head;
		while(symbol)
		{
			printf("%-10d%-10s%-10s%-10d%-10d%s\n",
            	symbol->index, symbol->name, symbol->type, symbol->address, symbol->lineno, symbol->element_type);
				symbol = symbol->next;
		}
		table = table->next;
	}
}
