/*	Definition section */
%{
    #include "common.h" //Extern variables that communicate with lex
    // #define YYDEBUG 1
    // int yydebug = 1;

    extern int yylineno;
    extern int yylex();
    extern FILE *yyin;

	FILE *fp;

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
	int current_addr = 0;
	int label_count = 0;
	int array_index = 0;
	int variable_count = 0;
	char assign_op = '\0';
	int has_error = 0;

	struct Stack *if_for_stack = NULL;
	struct Stack *else_stack = NULL;
	int if_label_count = 0;
	int for_label_count = 0;
	int else_label_count = 0;
	int forClause = 0;

    /* Symbol table function - you can add new function if needed. */
    static void create_symbol();
    static void insert_symbol();
    static char *lookup_symbol();
	static char *lookup_symbol_type();
	static int lookup_symbol_addr();
    static void dump_symbol();
	static void type_error();
	static struct Stack_Return pop_stack();
	static struct Stack *push_stack();
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
%token IF ELSE FOR
%token PRINTLN PRINT

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
    : StatementList Statement { variable_count = 0; isArray = 0;}
    | Statement { variable_count = 0; isArray = 0;}
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
	: VAR IDENTIFIER Type {
		insert_symbol($2, $3);
		int addr = lookup_symbol_addr($2);
		if(isArray)
		{
			char type[10];
			if($3[0] == 'i') strcpy(type, "int");
			else if($3[0] == 'f') strcpy(type, "float");
			fprintf(fp, "\tnewarray %s\n", type);
			fprintf(fp, "\tastore %d\n", addr);
		}
		else if($3[0] == 'i')
		{
			fprintf(fp, "\tldc 0\n");
			fprintf(fp, "\t%cstore %d\n", $3[0], addr);
		}
		else if($3[0] == 'f')
		{
			fprintf(fp, "\tldc 0.0\n");
			fprintf(fp, "\t%cstore %d\n", $3[0], addr);
		}
		else if($3[0] == 'b')
		{
			fprintf(fp, "\ticonst_0\n");
			fprintf(fp, "\tistore %d\n", addr);
		}
		else if($3[0] == 's')
		{
			fprintf(fp, "\tldc \"\"\n");
			fprintf(fp, "\tastore %d\n", addr);
		}
		isArray = 0;
		variable_count = 1;
	}
	| VAR IDENTIFIER Type '=' Expression { 
		insert_symbol($2, $3); 
		int addr = lookup_symbol_addr($2);
		if(isArray)
		{
			char type[10];
			if($3[0] == 'i') strcpy(type, "int");
			else if($3[0] == 'f') strcpy(type, "float");
			fprintf(fp, "\tnewarray %s\n", type);
			fprintf(fp, "\tastore %d\n", addr);
		}
		else if($3[0] == 'f' || $3[0] == 'i')
			fprintf(fp, "\t%cstore %d\n", $3[0], addr);
		else if($3[0] == 'b')
			fprintf(fp, "\tistore %d\n", addr);		
		else
			fprintf(fp, "\tastore %d\n", addr);
		variable_count = 1;
	}
;

SimpleStmt
	: ExpressionStmt
	| IncDecStmt
	| AssignStmt
;

PrintStmt
	: PRINT_token '(' Expression ')' { 
		printf("PRINT %s\n", $3);
		if(isArray)
		{
			fprintf(fp, "\tgetstatic java/lang/System/out Ljava/io/PrintStream;\n");
			fprintf(fp, "\tswap\n");
			fprintf(fp, "\tinvokevirtual java/io/PrintStream/print(%c)V\n\n", toupper($3[0]));
		}
		else if($3[0] == 'i' || $3[0] == 'f')
		{
			fprintf(fp, "\tgetstatic java/lang/System/out Ljava/io/PrintStream;\n");
			fprintf(fp, "\tswap\n");
			fprintf(fp, "\tinvokevirtual java/io/PrintStream/print(%c)V\n\n", toupper($3[0]));
		}
		else if($3[0] == 'b')
		{			
			fprintf(fp, "\tifne label_%d\n", label_count);
			fprintf(fp, "\tldc \"false\"\n");
			fprintf(fp, "\tgoto label_%d\n", label_count + 1);
			fprintf(fp, "label_%d:\n", label_count);
			fprintf(fp, "\tldc \"true\"\n");
			fprintf(fp, "\tgoto label_%d\n", label_count + 1);
			fprintf(fp, "label_%d:\n\n", label_count + 1);
			fprintf(fp, "\tgetstatic java/lang/System/out Ljava/io/PrintStream;\n");
			fprintf(fp, "\tswap\n");
			fprintf(fp, "\tinvokevirtual java/io/PrintStream/print(Ljava/lang/String;)V\n\n");
			label_count += 2;
		}
		else if($3[0] == 's')
		{
			fprintf(fp, "\tgetstatic java/lang/System/out Ljava/io/PrintStream;\n");
			fprintf(fp, "\tswap\n");
			fprintf(fp, "\tinvokevirtual java/io/PrintStream/print(Ljava/lang/String;)V\n\n");
		}
	}
	| PRINTLN_token '(' Expression ')' { 
		printf("PRINTLN %s\n", $3); 		
		if(isArray)
		{
			fprintf(fp, "\tgetstatic java/lang/System/out Ljava/io/PrintStream;\n");
			fprintf(fp, "\tswap\n");
			fprintf(fp, "\tinvokevirtual java/io/PrintStream/println(%c)V\n\n", toupper($3[0]));
		}
		else if($3[0] == 'i' || $3[0] == 'f')
		{
			fprintf(fp, "\tgetstatic java/lang/System/out Ljava/io/PrintStream;\n");
			fprintf(fp, "\tswap\n");
			fprintf(fp, "\tinvokevirtual java/io/PrintStream/println(%c)V\n\n", toupper($3[0]));
		}
		else if($3[0] == 'b')
		{
			fprintf(fp, "\tifne label_%d\n", label_count);
			fprintf(fp, "\tldc \"false\"\n");
			fprintf(fp, "\tgoto label_%d\n", label_count + 1);
			fprintf(fp, "label_%d:\n", label_count);
			fprintf(fp, "\tldc \"true\"\n");
			fprintf(fp, "\tgoto label_%d\n", label_count + 1);
			fprintf(fp, "label_%d:\n\n", label_count + 1);
			fprintf(fp, "\tgetstatic java/lang/System/out Ljava/io/PrintStream;\n");
			fprintf(fp, "\tswap\n");
			fprintf(fp, "\tinvokevirtual java/io/PrintStream/println(Ljava/lang/String;)V\n\n");
			label_count += 2;
		}
		else if($3[0] == 's')
		{
			fprintf(fp, "\tgetstatic java/lang/System/out Ljava/io/PrintStream;\n");
			fprintf(fp, "\tswap\n");
			fprintf(fp, "\tinvokevirtual java/io/PrintStream/println(Ljava/lang/String;)V\n\n");
		}
	}
;

PRINT_token
	: PRINT {variable_count = 2;}
;

PRINTLN_token
	: PRINTLN {variable_count = 2; }
;

Block
	: BRACE_UP StatementList BRACE_DOWN {
		dump_symbol();
		scope--;	
	}
;

IfStmt
	: IF Condition Block {
		struct Stack *temp = if_for_stack->last;
		struct Stack_Return result = pop_stack(if_for_stack);
		fprintf(fp, "if_label_%d:\n\n", result.number);		
		if_for_stack = temp;	
	}
	| IF Condition Block ELSE_token IfStmt {
		struct Stack *temp = else_stack->last;
		struct Stack_Return result = pop_stack(else_stack);
		else_stack = temp;
		fprintf(fp, "else_label_%d:\n\n", result.number);
	}
	| IF Condition Block ELSE_token Block {
		struct Stack *temp = else_stack->last;
		struct Stack_Return result = pop_stack(else_stack);
		else_stack = temp;
		fprintf(fp, "else_label_%d:\n\n", result.number);
	}
;

ELSE_token
	: ELSE {
		struct Stack *temp = if_for_stack->last;
		struct Stack_Return result = pop_stack(if_for_stack); 
		fprintf(fp, "\tgoto else_label_%d\n", else_label_count);
		fprintf(fp, "if_label_%d:\n\n", result.number);		
		else_stack = push_stack(else_stack, else_label_count, 0, 0);
		else_label_count++;
		if_for_stack = temp;
	}
;

ForStmt
	: FOR_token Condition Block {
		struct Stack *temp = if_for_stack->last;
		struct Stack_Return result_if = pop_stack(if_for_stack);
		if_for_stack = temp;
		temp = if_for_stack->last;
		struct Stack_Return result_for = pop_stack(if_for_stack);
		if_for_stack = temp;
		fprintf(fp, "\tgoto for_label_%d\n", result_for.number);
		fprintf(fp, "if_label_%d:\n", result_if.number);
	}
	| FOR_token ForClause Block {
		struct Stack *temp = if_for_stack->last;
		struct Stack_Return result_for = pop_stack(if_for_stack);
		if_for_stack = temp;
		temp = if_for_stack->last;
		struct Stack_Return result_if = pop_stack(if_for_stack);
		if_for_stack = temp;
		fprintf(fp, "\tgoto for_label_%d\n", result_for.number);
		fprintf(fp, "if_label_%d:\n", result_if.number);
	}
;

FOR_token
	: FOR {
		fprintf(fp, "for_label_%d:\n", for_label_count);
		if_for_stack = push_stack(if_for_stack, for_label_count, 0, 1);
		for_label_count++;
	}
;

ForClause
	: InitStmt ';' Condition ';' PostStmt {
		forClause = 0;
	}
;

InitStmt
	: SimpleStmt {
		struct Stack *temp = if_for_stack->last;
		pop_stack(if_for_stack);
		if_for_stack = temp;
		fprintf(fp, "for_label_%d:\n", for_label_count);		
		forClause = 1;
	}
;

PostStmt
	: SimpleStmt {
		fprintf(fp, "\tgoto for_label_%d\n", for_label_count);
		fprintf(fp, "for_label_%d:\n", for_label_count + 2);	
		for_label_count += 3;
	}
;

Condition
	: Expression { 
		if(strcmp($1, "bool") != 0) 
			type_error("CONDITION", $1, "-"); 
		variable_count = 0;
		if(forClause)
		{
			fprintf(fp, "\tifeq if_label_%d\n", if_label_count);
			if_for_stack = push_stack(if_for_stack, if_label_count, 1, 0);
			if_label_count++;
			fprintf(fp, "\tgoto for_label_%d\n", for_label_count + 2);
			fprintf(fp, "for_label_%d:\n", for_label_count + 1);
			if_for_stack = push_stack(if_for_stack, for_label_count + 1, 0, 1);
		}
		else
		{
			fprintf(fp, "\tifeq if_label_%d\n", if_label_count);
			if_for_stack = push_stack(if_for_stack, if_label_count, 1, 0);
			if_label_count++;
		}
	}
;

ExpressionStmt
	: Expression 
;

IncDecStmt
	: Expression INC { 
		printf("INC\n"); 
		fprintf(fp, "\tldc 1%s\n", $1[0] == 'f' ? ".0" : "");
		fprintf(fp, "\t%cadd\n", $1[0]);
		fprintf(fp, "\t%cstore %d\n", $1[0], current_addr);
		variable_count = 0;
	}
	| Expression DEC { 
		printf("DEC\n");
		fprintf(fp, "\tldc 1%s\n", $1[0] == 'f' ? ".0" : "");
		fprintf(fp, "\t%csub\n", $1[0]);
		fprintf(fp, "\t%cstore %d\n", $1[0], current_addr);
		variable_count = 0;
	}
;

AssignStmt
	: Expression assign_op Expression {
		if(assignable_result == 0) 
			printf("error:%d: cannot assign to %s\n", yylineno, $1);
		if(strcmp($1, $3) != 0) 
			type_error($2, $1, $3); 
		printf("%s\n", $2); 
		assignable = 1;
		switch(assign_op)
		{
			case 'a': { fprintf(fp, "\t%cadd\n", $1[0]); break; }
			case 's': { fprintf(fp, "\t%csub\n", $1[0]); break; }
			case 'm': { fprintf(fp, "\t%cmul\n", $1[0]); break; }
			case 'd': { fprintf(fp, "\t%cdiv\n", $1[0]); break; }
			case 'r': { fprintf(fp, "\t%crem\n", $1[0]); break; }
			default: break;
		}
		if(isArray)
			fprintf(fp, "\t%castore\n", $1[0]);
		else if($1[0] == 'i' || $1[0] == 'f')
			fprintf(fp, "\t%cstore %d\n", $1[0], current_addr);
		else if($1[0] == 's')
			fprintf(fp, "\tastore %d\n", current_addr);
		else if($1[0] == 'b')
			fprintf(fp, "\tistore %d\n", current_addr);
		variable_count = 0;
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
		fprintf(fp, "\tior\n");
	}
	| Expression LAND Expression 	{ 
		if(strcmp($1, "bool") != 0) 
			type_error("LAND", $1, "-");
		else if(strcmp($3, "bool") != 0) 
			type_error("LAND", $3, "-");
		printf("LAND\n"); 
		$$ = "bool"; 
		assignable = 0;
		fprintf(fp, "\tiand\n");
	}
	| Expression EQL Expression 	{ 
		printf("EQL\n"); 
		$$ = "bool"; 
		assignable = 0; 
		fprintf(fp, "\t%csub\n", $1[0]);
		if($1[0] == 'f') fprintf(fp, "\tf2i\n");
		fprintf(fp, "\tifeq label_%d\n", label_count);
		fprintf(fp, "\ticonst_0\n");
		fprintf(fp, "\tgoto label_%d\n", label_count + 1);
		fprintf(fp, "label_%d:\n", label_count);
		fprintf(fp, "\ticonst_1\n");
		fprintf(fp, "\tgoto label_%d\n", label_count + 1);
		fprintf(fp, "label_%d:\n\n", label_count + 1);
		label_count += 2;
	}
	| Expression NEQ Expression 	{ 
		printf("NEQ\n");
		$$ = "bool"; 
		assignable = 0; 
		fprintf(fp, "\t%csub\n", $1[0]);
		if($1[0] == 'f') fprintf(fp, "\tf2i\n");
		fprintf(fp, "\tifne label_%d\n", label_count);
		fprintf(fp, "\ticonst_0\n");
		fprintf(fp, "\tgoto label_%d\n", label_count + 1);
		fprintf(fp, "label_%d:\n", label_count);
		fprintf(fp, "\ticonst_1\n");
		fprintf(fp, "\tgoto label_%d\n", label_count + 1);
		fprintf(fp, "label_%d:\n\n", label_count + 1);
		label_count += 2;

	}
	| Expression GEQ Expression 	{ 
		printf("GEQ\n"); 
		$$ = "bool"; 
		assignable = 0; 
		fprintf(fp, "\t%csub\n", $1[0]);
		if($1[0] == 'f') fprintf(fp, "\tf2i\n");
		fprintf(fp, "\tifge label_%d\n", label_count);
		fprintf(fp, "\ticonst_0\n");
		fprintf(fp, "\tgoto label_%d\n", label_count + 1);
		fprintf(fp, "label_%d:\n", label_count);
		fprintf(fp, "\ticonst_1\n");
		fprintf(fp, "\tgoto label_%d\n", label_count + 1);
		fprintf(fp, "label_%d:\n\n", label_count + 1);
		label_count += 2;

	}
	| Expression LEQ Expression 	{ 
		printf("LEQ\n"); 
		$$ = "bool"; 
		assignable = 0; 
		fprintf(fp, "\t%csub\n", $1[0]);
		if($1[0] == 'f') fprintf(fp, "\tf2i\n");
		fprintf(fp, "\tifle label_%d\n", label_count);
		fprintf(fp, "\ticonst_0\n");
		fprintf(fp, "\tgoto label_%d\n", label_count + 1);
		fprintf(fp, "label_%d:\n", label_count);
		fprintf(fp, "\ticonst_1\n");
		fprintf(fp, "\tgoto label_%d\n", label_count + 1);
		fprintf(fp, "label_%d:\n\n", label_count + 1);
		label_count += 2;

	}
	| Expression '>' Expression 	{ 
		printf("GTR\n"); 
		$$ = "bool"; 
		assignable = 0;
		fprintf(fp, "\t%csub\n", $1[0]);
		if($1[0] == 'f') fprintf(fp, "\tf2i\n");
		fprintf(fp, "\tifgt label_%d\n", label_count);
		fprintf(fp, "\ticonst_0\n");
		fprintf(fp, "\tgoto label_%d\n", label_count + 1);
		fprintf(fp, "label_%d:\n", label_count);
		fprintf(fp, "\ticonst_1\n");
		fprintf(fp, "\tgoto label_%d\n", label_count + 1);
		fprintf(fp, "label_%d:\n\n", label_count + 1);
		label_count += 2;
	}
	| Expression '<' Expression 	{ 
		printf("LSS\n"); 
		$$ = "bool"; 
		assignable = 0; 
		fprintf(fp, "\t%csub\n", $1[0]);
		if($1[0] == 'f') fprintf(fp, "\tf2i\n");
		fprintf(fp, "\tiflt label_%d\n", label_count);
		fprintf(fp, "\ticonst_0\n");
		fprintf(fp, "\tgoto label_%d\n", label_count + 1);
		fprintf(fp, "label_%d:\n", label_count);
		fprintf(fp, "\ticonst_1\n");
		fprintf(fp, "\tgoto label_%d\n", label_count + 1);
		fprintf(fp, "label_%d:\n\n", label_count + 1);
		label_count += 2;

	}
	| Expression '+' Expression 	{ 
		if(strcmp($1, $3) != 0) type_error("ADD", $1, $3); 
		printf("ADD\n"); 
		assignable = 0;
		fprintf(fp, "\t%cadd\n", $1[0]);
	}
	| Expression '-' Expression 	{ 
		if(strcmp($1, $3) != 0) type_error("SUB", $1, $3); 
		printf("SUB\n"); 
		assignable = 0; 
		fprintf(fp, "\t%csub\n", $1[0]);
	}
	| Expression '*' Expression 	{ 
		printf("MUL\n"); 
		assignable = 0;
		fprintf(fp, "\t%cmul\n", $1[0]);
	}
	| Expression '/' Expression 	{ 
		printf("QUO\n"); 
		assignable = 0; 
		fprintf(fp, "\t%cdiv\n", $1[0]);
	}
	| Expression '%' Expression 	{ 
		if(strcmp($1, "int32") != 0) 
			type_error("REM", $1, "-");
		else if(strcmp($3, "int32") != 0) 
			type_error("REM", $3, "-");
		printf("REM\n"); 
		assignable = 0; 
		fprintf(fp, "\t%crem\n", $1[0]);
	}
;

UnaryExpr
	: PrimaryExpr { $$ = $1; }
	| '+' UnaryExpr { $$ = $2; printf("POS\n"); assignable = 0; }
	| '-' UnaryExpr { $$ = $2; printf("NEG\n"); assignable = 0; fprintf(fp, "\t%cneg\n", $2[0]);}
	| '!' UnaryExpr { 
		$$ = $2; printf("NOT\n"); 
		assignable = 0; 
		fprintf(fp, "\ticonst_1\n");
		fprintf(fp, "\tixor\n");
	}
;

PrimaryExpr
	: Operand 			{ $$ = $1; }
	| IndexExpr 		{ $$ = $1; }
	| ConversionExpr 	{ $$ = $1; }
;

Operand
	: Literal { $$ = $1; assignable = 0; }
	| IDENTIFIER {
		$$ = lookup_symbol($1);
		int addr = lookup_symbol_addr($1);
		assignable = 1; 
		char* type = strdup(lookup_symbol_type($1));
		if(type[0] == 'f' || type[0] == 'i')
			fprintf(fp, "\t%cload %d\n", type[0], addr);
		else if(type[0] == 'b')
			fprintf(fp, "\tiload %d\n", addr);		
		else
			fprintf(fp, "\taload %d\n", addr);
		if(variable_count == 0)
			current_addr = addr;
		variable_count++;
	}
	| '(' Expression ')' { $$ = $2; }
;

IndexExpr : PrimaryExpr '[' Expression ']' { 
		$$ = $1; 
		assignable = 1;
		if(variable_count >= 2)
			fprintf(fp, "\t%caload\n", $1[0]); 
		variable_count++;
	}
;

ConversionExpr
	: Type '(' Expression ')' { 
		if((strcmp($1, "float32") == 0) && (strcmp($3, "int32") == 0)) 
		{
			printf("I to F\n");
			fprintf(fp, "\ti2f\n");
		}
		else if((strcmp($1, "int32") == 0) && (strcmp($3, "float32") == 0))
		{
			printf("F to I\n");
			fprintf(fp, "\tf2i\n");
		}
		$$ = $1;
	}
;

Literal
	: INT_LIT 		{ array_index = $1; fprintf(fp, "\tldc %d\n", $1); printf("INT_LIT %d\n", $1); $$ = "int32"; }
	| FLOAT_LIT 	{ fprintf(fp, "\tldc %f\n", $1); printf("FLOAT_LIT %f\n", $1); $$ = "float32"; }
	| '"' STRING_LIT '"'	{ fprintf(fp, "\tldc \"%s\"\n", $2); printf("STRING_LIT %s\n", $2); $$ = "string"; }
	| BOOL_LIT		{ fprintf(fp, "\ticonst_%d\n", strcmp($1, "TRUE") == 0 ? 1 : 0); printf("%s\n", $1); $$ = "bool"; } 
;

assign_op
	: '='			{ $$ = "ASSIGN"; assignable_result = assignable; assign_op = '\0';}
	| ADD_ASSIGN 	{ $$ = "ADD_ASSIGN"; assignable_result = assignable; assign_op = 'a';}
	| SUB_ASSIGN	{ $$ = "SUB_ASSIGN"; assignable_result = assignable; assign_op = 's';}
	| MUL_ASSIGN	{ $$ = "MUL_ASSIGN"; assignable_result = assignable; assign_op = 'm';}
	| QUO_ASSIGN	{ $$ = "QUO_ASSIGN"; assignable_result = assignable; assign_op = 'd';}
	| REM_ASSIGN	{ $$ = "REM_ASSIGN"; assignable_result = assignable; assign_op = 'r';}
;

Type
	: TypeName { $$ = $1; }
	| ArrayType { $$ = $1; variable_count = 0;}
;

TypeName
	: INT		{ $$ = "int32";}
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

	fp = fopen("hw3.j", "w");
	fprintf(fp, ".source hw3.j\n");
	fprintf(fp, ".class public Main\n");
	fprintf(fp, ".super java/lang/Object\n");
	fprintf(fp, ".method public static main([Ljava/lang/String;)V\n");
	fprintf(fp, ".limit stack 100 ; Define your storage size.\n");
	fprintf(fp, ".limit locals 100 ; Define your local space number.\n");

	tables = malloc(sizeof(struct Table_List));
	tables->head = tables->tail = NULL;
	create_symbol();

	if_for_stack = malloc(sizeof(struct Stack));
	if_for_stack->last = NULL;
	if_for_stack->isFor = 0;
	if_for_stack->isIf = 0;
	if_for_stack->number = 0;

	else_stack = malloc(sizeof(struct Stack));
	else_stack->last = NULL;
	else_stack->isFor = 0;
	else_stack->isIf = 0;
	else_stack->number = 0;

	yylineno = 0;
    yyparse();

	dump_symbol();

	printf("Total lines: %d\n", yylineno);

	fprintf(fp, "\treturn\n");
	fprintf(fp, ".end method");

	free(tables);
	free(if_for_stack);
	free(else_stack);

    fclose(yyin);
	fclose(fp);

	if(has_error)
		remove("hw3.j");

    return 0;
}

static void create_symbol() 
{ 	
	// Create table
	struct Table *newTable = malloc(sizeof(struct Table));
	newTable->scope = scope;
	newTable->head = NULL;
	newTable->tail = NULL;
	newTable->next = NULL;

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
			has_error = 1;
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
				if(symbol->type[0] == 'a')
					isArray = 1;
				else
					isArray = 0;
				return strcmp(symbol->type, "array") == 0 ? symbol->element_type : symbol->type;
			}
			else
				symbol = symbol->next;
		}
		table = table->next;
	}
	printf("error:%d: undefined: %s\n", yylineno + 1, id);
	has_error = 1;
	return "none";
}

static char* lookup_symbol_type(char* id)
{
	
	struct Table *table = tables->head;
	while(table)
	{
		struct Symbol *symbol = table->head;
		while(symbol)
		{
			if(strcmp(id, symbol->name) == 0)
			{
				if(symbol->type[0] == 'a')
					isArray = 1;
				else
					isArray = 0;
				return symbol->type;
			}
			else
				symbol = symbol->next;
		}
		table = table->next;
	}
	printf("error:%d: undefined: %s\n", yylineno + 1, id);
	has_error = 1;
	return "none";
}


static int lookup_symbol_addr(char* id)
{
	
	struct Table *table = tables->head;
	while(table)
	{
		struct Symbol *symbol = table->head;
		while(symbol)
		{
			if(strcmp(id, symbol->name) == 0)
			{
				if(symbol->type[0] == 'a')					
					isArray = 1;
				else
					isArray = 0;
				return symbol->address;
			}
			else
				symbol = symbol->next;
		}
		table = table->next;
	}
	printf("error:%d: undefined: %s\n", yylineno + 1, id);
	has_error = 1;
	return 0;
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
	{
		printf("error:%d: invalid operation: %s (mismatched types %s and %s)\n", yylineno, operator, typeA, typeB);
		has_error = 1;
	}

	else if(
		strcmp(operator, "REM") == 0 ||
		strcmp(operator, "LAND") == 0 ||
		strcmp(operator, "LOR") == 0
	)
	{
		printf("error:%d: invalid operation: (operator %s not defined on %s)\n", yylineno, operator, typeA);
		has_error = 1;
	}

	else if(
		strcmp(operator, "CONDITION") == 0
	)
	{
		printf("error:%d: non-bool (type %s) used as for condition\n", yylineno + 1, typeA);
		has_error = 1;
	}
};

struct Stack_Return pop_stack(struct Stack *stack)
{
	struct Stack_Return result;
	result.isIf = 0;
	result.isFor = 0;
	result.number = 0;

	if(stack->last != NULL)
	{
		result.isIf = stack->isIf;
		result.isFor = stack->isFor;
		result.number = stack->number;
		struct Stack *temp = stack;
		stack = stack->last;
		free(temp);
		return result;
	}
	else 
		return result;
}

struct Stack* push_stack(struct Stack *stack, int number, int isIf, int isFor)
{
	struct Stack *newElement = malloc(sizeof(struct Stack));
	newElement->number = number;
	newElement->last = stack;
	newElement->isIf = isIf;
	newElement->isFor = isFor;
	return newElement;
}
