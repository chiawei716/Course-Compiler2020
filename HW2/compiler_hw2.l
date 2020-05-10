/* Definition section */
%{
    #include "common.h"
    #include "y.tab.h"	/* header file generated by bison */
    extern YYSTYPE yylval;

    #define YY_NO_UNPUT
    #define YY_NO_INPUT
%}

/* Define regular expression label */
letter [a-zA-Z_]
digit [0-9]
id {letter}+({letter}|{digit})*
inumber {digit}+
fnumber ({digit}*\.{digit}+)

%x CMT
%x STR
%option yylineno

/* Rules section */
%%

"/*"        { BEGIN(CMT); }
<CMT>"*/"   { BEGIN(INITIAL); }
<CMT>\n     {;}
<CMT>.      {;}
"//".*      {;}
"\""        { BEGIN(STR);
                return '"';
            }
<STR>"\""   { BEGIN(INITIAL);
                return '"';
            }
<STR>[^\"]* { yylval.s_val = strdup(yytext);
                return STRING_LIT;
            }
"+"         { return '+'; }
"-"         { return '-'; }
"*"         { return '*'; }
"/"         { return '/'; }
"%"         { return '%'; }
"++"        { return INC; }
"--"        { return DEC; }

">"         { return '>'; }
"<"         { return '<'; }
">="        { return GEQ; }
"<="        { return LEQ; }
"=="        { return EQL; }
"!="        { return NEQ; }

"="         { return '='; }
"+="        { return ADD_ASSIGN; }
"-="        { return SUB_ASSIGN; }
"*="        { return MUL_ASSIGN; }
"/="        { return QUO_ASSIGN; }
"%="        { return REM_ASSIGN; }

"&&"        { return LAND; }
"||"        { return LOR; }
"!"         { return '!'; }

"("         { return '('; }
")"         { return ')'; }
"["         { return '['; }
"]"         { return ']'; }
"{"         { return '{'; }
"}"         { return '}'; }

";"         { return ';'; }
","         { return ','; }
"\n"        { return NEWLINE; }

"print"     { return PRINT; }
"println"   { return PRINTLN; }
"if"        { return IF; }
"else"      { return ELSE; }
"for"       { return FOR; }

"int32"     { return INT; }
"float32"   { return FLOAT;}
"string"    { return STRING; }
"bool"      { return BOOL; }
"true"      { yylval.b_val = strdup("TRUE"); return BOOL_LIT; }
"false"     { yylval.b_val = strdup("FALSE"); return BOOL_LIT; }
"var"       { return VAR; }

{inumber}   { yylval.i_val = atoi(yytext); return INT_LIT; }
{fnumber}   { yylval.f_val = atof(yytext); return FLOAT_LIT; }
{id}        { yylval.s_val = strdup(yytext); return IDENTIFIER; }

<<EOF>>     { static int once = 0;
                if (once++) {
                    yyterminate();
                }
                yylineno++;
                return NEWLINE;
            }
[ \t]+      {;}
.           {;}
%%

/*  C Code section */
int yywrap(void)
{
    return 1;
}