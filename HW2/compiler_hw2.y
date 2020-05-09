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
	struct Table_List *tables = NULL;
		
	//tables.head = tables->tail = malloc(sizeof(struct Table));
	//(tables.head)->head = (tables.head)->tail = NULL;

    /* Symbol table function - you can add new function if needed. */
    static void create_symbol();
    static void insert_symbol();
    static char *lookup_symbol();
    static void dump_symbol();
%}

%error-verbose

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
}

/* Token without return */
%token VAR
%token INT FLOAT BOOL STRING
%token INC DEC
%token GEQ LEQ EQL NEQ
%token ADD_ASSIGN SUB_ASSIGN MUL_ASSIGN QUO_ASSIGN REM_ASSIGN
%token LAND LOR
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
%type <operation> add_op mul_op cmp_op binary_op unary_op
%type <type> Expression SecExpr ThirdExpr ForthExpr FifthExpr
%type <type> Literal Operand UnaryExpr PrimaryExpr

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
	: DeclarationStmt NEWLINE
	| SimpleStmt NEWLINE
	| PrintStmt NEWLINE
	| NEWLINE
;

DeclarationStmt
	: VAR IDENTIFIER Type { insert_symbol($2, $3, "-"); }
;

SimpleStmt
	: ExpressionStmt
	| IncDecStmt
;

PrintStmt
	: PRINT '(' Expression ')' { printf("PRINT %s\n", $3); }
	| PRINTLN '(' Expression ')' { printf("PRINTLN %s\n", $3); }
;

ExpressionStmt : Expression ;

IncDecStmt
	: Expression INC { printf("INC\n"); }
	| Expression DEC { printf("DEC\n"); }
;

Expression
	: Expression LOR SecExpr { printf("LOR\n"); }
	| SecExpr { $$ = "bool"; }
;

SecExpr
	: SecExpr LAND ThirdExpr { printf("LAND\n"); }
	| ThirdExpr { $$ = "bool"; }
;

ThirdExpr
	: ThirdExpr cmp_op  ForthExpr { printf("%s\n", $2); }
	| ForthExpr { $$ = $1; }
;

ForthExpr
	: ForthExpr add_op FifthExpr { printf("%s\n", $2); }
	| FifthExpr { $$ = $1; }
;

FifthExpr
	: FifthExpr mul_op UnaryExpr { printf("%s\n", $2); }
	| UnaryExpr { $$ = $1; }
;

UnaryExpr
	: PrimaryExpr { $$ = $1; }
	| unary_op UnaryExpr { printf("%s\n", $1); }
;

PrimaryExpr
	: Operand { $$ = $1; }
	| IndexExpr
	| ConversionExpr
;

Operand
	: Literal
	| IDENTIFIER { $$ = lookup_symbol($1); }
	| '(' Expression ')' { $$ = $2; }
;

IndexExpr : PrimaryExpr '[' Expression ']' ;
ConversionExpr : Type '(' Expression ')' ;

Literal
	: INT_LIT 		{ printf("INT_LIT %d\n", $1); $$ = "int32"; }
	| FLOAT_LIT 	{ printf("FLOAT_LIT %f\n", $1); $$ = "float32"; }
	| STRING_LIT 	{ printf("STRING_LIT %s\n", $1); $$ = "string"; }
	| BOOL_LIT		{ printf("%s\n", $1); $$ = "bool"; } 
;

binary_op
	: mul_op { $$ = $1; }
	| add_op { $$ = $1; } 
	| cmp_op
	| LAND
	| LOR
;

cmp_op
	: EQL	{ $$ = "EQL"; }
	| NEQ 	{ $$ = "NEQ"; }
	| GEQ 	{ $$ = "GEQ"; }
	| LEQ 	{ $$ = "LEQ"; }
	| '>' 	{ $$ = "GTR"; }
	| '<' 	{ $$ = "LTR"; }
;

add_op
	: '+' { $$ = "ADD"; }
	| '-' { $$ = "SUB"; }
;

mul_op
	: '*' { $$ = "MUL"; }
	| '/' { $$ = "QUO"; }
	| '%' { $$ = "REM"; }
;

unary_op
	: '+' { $$ = "POS"; }
	| '-' { $$ = "NEG"; }
	| '!' { $$ = "NOT"; }
;

Type
	: TypeName { $$ = $1; }
	| ArrayType
;

TypeName
	: INT		{ $$ = "int32"; }
	| FLOAT 	{ $$ = "float32"; }
	| STRING	{ $$ = "string"; }
	| BOOL		{ $$ = "bool"; }
;

ArrayType
	: '['  ']' Type
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

    yylineno = 0;
    yyparse();

	dump_symbol();

	printf("Total lines: %d\n", yylineno);
    fclose(yyin);
    return 0;
}

static void create_symbol(char* id, char* type, char* element_type) 
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

	// Call insert again
	insert_symbol(id, type, element_type);
}

static void insert_symbol(char *id, char *type, char *element_type) {

	struct Table *table = tables->head;	

	// Find specific scope
	if(table)
		if(table->scope == scope)
		{
			// Create new symbol
			struct Symbol *newSymbol = malloc(sizeof(struct Symbol));
			newSymbol->name = strdup(id);
			newSymbol->type = strdup(type);
			newSymbol->address = address++;
			newSymbol->lineno = yylineno + 1;
			newSymbol->element_type = strdup(element_type);
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
		}
		// If no table matches scope level, create one
		else
		{
			create_symbol(id, type, element_type);
			return;
		}
	else
	{
		create_symbol(id, type, element_type);
		return;
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
				return symbol->name;
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
	free(tables->head);
	tables->head = newHead;
}
