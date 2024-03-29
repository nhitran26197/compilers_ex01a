  // Dalio, Brian A.
  // dalioba
  // 2024-02-01

  //---- DEFINITIONS  --------------------------------------------

%option header-file="lex.yy.h"

/* Our input is not from an interactive source. */
%option never-interactive
/* Don't generate the default rule. */
%option nodefault
/* We don't directly read the input. */
%option noinput
/* Don't include <unistd.h>. */
%option nounistd
/* We don't 'unput' a character back. */
%option nounput
/* Don't call yywrap() on EOF. */
%option noyywrap

/* These two options are doubled to get more detailed reports. */
/* Write performance report to stderr. */
%option perf-report perf-report
/* Write statistics summary to stderr. */
%option verbose verbose

/* Generate warning messages for goofs. */
%option warn

/* Maintain current line number in yylineno. */
%option yylineno

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Token IDs.  Theses are usually defined by bison.  Since this is
//    a simple flex-only solution, we define them ourselves.
//    The numbers start at 256 to avoid clashing with the literal
//    'single character' token categories.  (See the flex notes
//    for more info on that kind of token category.)
enum {
  tok_ID = 256,
  tok_INT_LIT,
  tok_STR_LIT,
  tok_REAL,
  tok_HEX,
  tok_BIT,
  tok_OCT,
  tok_SCI,

  // The two-character operators
  tok_EQ,
  tok_GE,
  tok_LE,
  tok_NE,



  // C's keywords (kind of :)
  tok_AUTO,
  tok_BREAK,
  tok_CASE,
  tok_CHAR,
  tok_CONST,
  tok_CONTINUE,
  tok_DEFAULT,
  tok_DO,
  tok_DOUBLE,
  tok_ELSE,
  tok_ENUM,
  tok_EXTERN,
  tok_FLOAT,
  tok_FOR,
  tok_GOTO,
  tok_IF,
  tok_INLINE,
  tok_INT,
  tok_LONG,
  tok_READ,
  tok_REGISTER,
  tok_RESTRICT,
  tok_RETURN,
  tok_SHORT,
  tok_SIGNED,
  tok_SIZEOF,
  tok_STATIC,
  tok_STRUCT,
  tok_SWITCH,
  tok_TYPEDEF,
  tok_TYPEOF,
  tok_UNION,
  tok_UNSIGNED,
  tok_VAR,
  tok_VOID,
  tok_VOLATILE,
  tok_WHILE,
  tok_WRITE,
};

// yylval is the union of all possible attributes that can be
//    returned by any category of token.  This is usually defined
//    for us by bison.  Since this is a simple flex-only solution,
//    we define it ourselves.
union {
  int   intval;
  char *strval;
  double realval;
} yylval;

// yylloc is the location of the token.  This is usually defined
//    for us by bison.  Since this is a simple flex-only solution,
//    we define it ourselves.
typedef struct {
  int first_line, first_column;
  int last_line, last_column;
} YYLTYPE;

YYLTYPE yylloc;

// flex doesn't track the column number automatically.  We keep
//    this up-to-date ourselves.
int yycolno;

// This action is peformed by yylex() at the beginning of every
//    action routine after yytext and yyleng are set but before
//    any user code is run.
// We use it to set the location of the token that was just
//    scanned and to keep yycolno up to date.
#define YY_USER_ACTION                              \
  yylloc.first_line = yylloc.last_line = yylineno;  \
  yylloc.first_column = yycolno;                    \
  yylloc.last_column = yycolno + yyleng - 1;        \
  yycolno += yyleng;

// Forward decls for functions used in action routines ...
int isKeyword( const char *txt );
int getOperatorToken (const char *txt);
%}

/* Some definitions to make the REs below easier to understand. */
DIGIT       [0-9]
WORD_CHAR   [_a-zA-Z0-9]
SINGLE_OP   [+-*/^!><=]
TWO_CHAR_OP   "=="|"<="|">="|"<>"
INLINE_COM  "//".*
STRING      ["][^"\n]*["]
REAl   [0-9]*([0-9]+\.|\.[0-9]+)[0-9]*
HEXIT [0-9a-fA-F]
BITIT [01]
OCTIT [0-7]
MUL_COM "/*"([])*"*/"




%% //---- RULES --------------------------------------------------

[(){}[\],\.;:]      { return yytext[0]; }

{DIGIT}+  {
  // An integer literal has the decimal value of the string of
  //  digits as its attribute.
  yylval.intval = (int) strtol( yytext, NULL, 10 );

  // We successfully scanned an integer literal.
  return tok_INT_LIT;
}
[0-9]*([0-9]+\.|\.[0-9]+)[0-9]*[eE][-+]?[0-9]+? {
  yylval.strval = strdup(yytext);
  return tok_SCI;
}
{REAl} {
  yylval.realval = atof(yytext);
  return tok_REAL;
}
0[xX]{HEXIT}+ {
  yylval.intval = (int) strtol(yytext+2, NULL, 16);
  return tok_HEX;
}
0[bB]{BITIT}+ {
  yylval.intval = (int) strtol(yytext+2, NULL, 2);
  return tok_BIT;
}
0[oO]{OCTIT}+ {
  yylval.intval = (int) strtol(yytext +2, NULL, 8);
  return tok_OCT;
}


{STRING} {
  yylval.strval = strdup(yytext);
  return tok_STR_LIT;
}

[_a-zA-Z]{WORD_CHAR}*  {
  // Have to distinguish keywords from IDs.
  int kw = isKeyword( yytext );

  if ( kw ) {
    // It _is_ a keyword.  Return which one.
    return kw;
  }


  // It isn't a keyword;  treat it as an ID.
  // An id has a MALLOCed copy of the characters that make it up
  //  as its attribute.  Remember to free() this somewhere so you
  //  don't leak memory!
  yylval.strval = strdup( yytext );

  // We successfully scanned an id.
  return tok_ID;
}

{TWO_CHAR_OP} {
  int token = getOperatorToken(yytext);
  yylval.strval= strdup(yytext);
  return token;
}
[*+-/^!<>] {
  return (yytext[0]);
}
{INLINE_COM} {}


[ \f\t\v]+  { /* Ignore intertoken whitespace */ }

[\r\n]+     {
  // \r and \n start new lines, so the column number has to be
  //  reset to 1.
  yycolno = 1; }

.       {
  // Ignore illegal characters after printing a spiffy and
  //  informative message.
  printf( "(%d:%d) Illegal character '%s' (0x%02x)\n",
    yylloc.first_line, yylloc.first_column, yytext, yytext[0] );
}

%% //---- USER CODE ----------------------------------------------

char *getFileContents( const char *fName )
{
  FILE *fp = fopen( fName, "r" );
  if ( fp == NULL ) {
    printf( "Unable to open '%s' for read.\n", fName );
    exit( -1 );
  }

  char   *buffer = NULL;
  size_t  len;
  ssize_t numBytes = getdelim( &buffer, &len, '\0', fp );

  fclose( fp );

  if ( numBytes == -1) {
    printf( "No contents read from '%s'?\n", fName );

    return strdup( "" );

  } else {
    printf( "%d byte%s read from '%s'.\n",
      (int) len, len == 1 ? "" : "s", fName );

    return buffer;
  }
}

//----------------------------------------------------------------
typedef struct {
  char *kw;
  int   tok;
} Keyword;

Keyword keywords[] = {
  { "auto", tok_AUTO },
  { "break", tok_BREAK },
  { "case", tok_CASE },
  { "char", tok_CHAR },
  { "const", tok_CONST },
  { "continue", tok_CONTINUE },
  { "default", tok_DEFAULT },
  { "do", tok_DO },
  { "double", tok_DOUBLE },
  { "else", tok_ELSE },
  { "enum", tok_ENUM },
  { "extern", tok_EXTERN },
  { "float", tok_FLOAT },
  { "for", tok_FOR },
  { "goto", tok_GOTO },
  { "if", tok_IF },
  { "inline", tok_INLINE },
  { "int", tok_INT },
  { "long", tok_LONG },
  { "read", tok_READ },
  { "register", tok_REGISTER },
  { "restrict", tok_RESTRICT },
  { "return", tok_RETURN },
  { "short", tok_SHORT },
  { "signed", tok_SIGNED },
  { "sizeof", tok_SIZEOF },
  { "static", tok_STATIC },
  { "struct", tok_STRUCT },
  { "switch", tok_SWITCH },
  { "typedef", tok_TYPEDEF },
  { "typeof", tok_TYPEOF },
  { "union", tok_UNION },
  { "unsigned", tok_UNSIGNED },
  { "var", tok_VAR },
  { "void", tok_VOID },
  { "volatile", tok_VOLATILE },
  { "while", tok_WHILE },
  { "write", tok_WRITE },

};


#define NUM_KEYWORDS ( sizeof(keywords) / sizeof(Keyword) )

int isKeyword( const char *txt )
{
  for ( size_t i=0; i < NUM_KEYWORDS; i++ ) {
    if ( strcmp( txt, keywords[i].kw ) == 0 ) {
      return keywords[i].tok;
    }
  }

  return 0;
}

char *tokToKW( int tok )
{
  for ( size_t i=0; i < NUM_KEYWORDS; i++ ) {
    if ( keywords[i].tok == tok ) {
      return keywords[i].kw;
    }
  }

  return NULL;
}

typedef struct{
  char *operator;
  int tok;

}Operator;

Operator operators[]={
  {"==", tok_EQ},
  {"<=", tok_LE},
  {">=", tok_GE},
  {"<>", tok_NE},
};
#define NUM_OPERATORS (sizeof(operators)/sizeof(Operator))

int getOperatorToken( const char *txt)
{
  for ( size_t i=0; i< NUM_OPERATORS; i++)
  {
    if (strcmp(txt, operators[i].operator)==0){
      return operators[i].tok;
    }
  }
  return 0;

}
//----------------------------------------------------------------
void printTokLoc()
{
  if ( yylloc.first_line == yylloc.last_line ) {
    if ( yylloc.first_column == yylloc.last_column ) {
      printf( "(%d:%d) ",
        yylloc.first_line, yylloc.first_column );
    } else {
      printf( "(%d:%d-%d) ",
        yylloc.first_line,
        yylloc.first_column, yylloc.last_column );
    }
  } else {
    printf( "(%d:%d-%d:%d) ",
      yylloc.first_line, yylloc.first_column,
      yylloc.last_line, yylloc.last_column );
  }
}

//----------------------------------------------------------------
int main( int argc, char *argv[] )
{
  char *inStr;

  switch ( argc ) {
    case 1 :
      inStr = strdup( "fred _ 15 1234.345 \"bob\" Maddog87" );
      break;

    case 2 :
      inStr = getFileContents( argv[1] );
      break;

    default :
      printf( "Usage: %s [ <inFileName> ]\n", argv[0] );
      return 0;
  }

  printf( "Tokens for\n%s\n\n", inStr );

  //--------------------------------------
  // Initialize the current location.
  //   flex updates yylineno automatically.
  //   We have to keep track of yycolno ourselves.
  yylineno = 1;
  yycolno  = 1;

  //--------------------------------------
  // Tell flex to use this char * as the source of the characters
  //  it should be scanning.
  yy_scan_string( inStr );

  //--------------------------------------
  // Get the tokens one-by-one.
  int tok;

  while ( ( tok = yylex() ) ) {
    printTokLoc();

    switch ( tok ) {
      case tok_ID :
        printf( "ID '%s'\n", yylval.strval );
        free( yylval.strval );
        break;

      case tok_INT_LIT :
        printf( "INTEGER_LITERAL %d\n", yylval.intval );
        break;
      case tok_REAL:
        printf("REAL LITERAL %f\n", yylval.realval);
        break;
      case tok_HEX:
        printf("HEX LITERAL %d\n", yylval.intval);
        break;
      case tok_BIT:
        printf("BIT LITERAL %d\n", yylval.intval);
        break;
      case tok_OCT:
        printf("OCT LITERAL %d\n", yylval.intval);
        break;
      case tok_SCI:
        printf("SCIENTIFIC %s\n", yylval.strval);
        free(yylval.strval);
        break;
      case tok_STR_LIT:
        printf(" STRING_LITERAL %s\n", yylval.strval);
        free(yylval.strval);
        break;
      
      

      case '(' : case ')': case '{': case'}': case '[': case ']' :
      case ',':
      case ';':
      case ':':
        printf( "Punctuation '%c' (%d)\n", tok, tok );
        break;

      case tok_BREAK:
      case tok_CASE:
      case tok_CHAR:
      case tok_CONST:
      case tok_CONTINUE:
      case tok_DEFAULT:
      case tok_DO:
      case tok_DOUBLE:
      case tok_ELSE:
      case tok_ENUM:
      case tok_EXTERN:
      case tok_FLOAT:
      case tok_FOR:
      case tok_GOTO:
      case tok_IF:
      case tok_INLINE:
      case tok_INT:
      case tok_LONG:
      case tok_READ:
      case tok_REGISTER:
      case tok_RESTRICT:
      case tok_RETURN:
      case tok_SHORT:
      case tok_SIGNED:
      case tok_SIZEOF:
      case tok_STATIC:
      case tok_STRUCT:
      case tok_SWITCH:
      case tok_TYPEDEF:
      case tok_TYPEOF:
      case tok_UNION:
      case tok_UNSIGNED:
      case tok_VAR:
      case tok_VOID:
      case tok_VOLATILE:
      case tok_WHILE:
      case tok_WRITE:
      case tok_AUTO :
        printf( "Keyword '%s' (%d)\n", tokToKW( tok ), tok );
        break;

      case tok_EQ:
      case tok_NE:
      case tok_GE:
      case tok_LE:
        printf("Two character operator '%s' (%d)\n", yylval.strval, tok);
        free(yylval.strval);
        break;

      case '+':
      case '-':
      case '/':
      case '*':
      case '!':
      case '<':
      case '>':
      case '^':
        printf( "Single operator '%c' (%d)\n", tok, tok );
        break;



      default :
        printf( "Unknown token category %d?\n", tok );
        break;
    }
  }

  //--------------------------------------
  // Get rid of the input string.
  free( inStr );

  //--------------------------------------
  // No errors!
  return 0;
}

//----------------------------------------------------------------
