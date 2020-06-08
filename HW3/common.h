#ifndef COMMON_H
#define COMMON_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

typedef enum { false, true } bool;

struct Symbol
{
	int index;
	char *name;
	char *type;
	int address;
	int lineno;
	char *element_type;
	struct Symbol *next;
};

struct Table
{
	int scope;
	struct Symbol *head;
	struct Symbol *tail;
	struct Table *next;
};

struct Table_List
{
	struct Table *head;
	struct Table *tail;
};

struct Stack
{
	int number;
	int isIf;
	int isFor;
	struct Stack *last;
};

struct Stack_Return
{
	int isIf;
	int isFor;
	int number;
};

#endif /* COMMON_H */
