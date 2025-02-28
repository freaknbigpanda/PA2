/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1024
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr = string_buf;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

/*
 *  Add Your own definitions here
 */

//#define DEBUG

// String Constant Helpers

enum StringScannerState {
//  NotScanning,
  Normal,
  TooLong,
  ContainsNullChar
};

//StringScannerState stringScannerState = StringScannerState::NotScanning;
StringScannerState stringScannerState = StringScannerState::Normal;

void ExitStringConstantStartState()
{
  BEGIN 0; // Should be BEGIN INITIAL but flex doesn't define INITIAL early enough so we can't use it here
  string_buf_ptr = string_buf;
  stringScannerState = StringScannerState::Normal;
}

// End String Constant Helpers

// Comment Helpers

int CommentOpenBraketDepth = 0;

void ExitCommentState()
{
  BEGIN 0;
  CommentOpenBraketDepth = 0;
}

// End Comment Helpers

void PossiblyIncrementLineNum()
{
  for(int i = 0; i < yyleng; ++i)
  {
    if (yytext[i] == '\n') curr_lineno++;
  }
}

%}

/*
 * Define names for regular expressions here.
 */

%option noyywrap
%Start StringConstant MultiLineComment SingleLineComment

DARROW =>
ASSIGN <-
DIGIT [0-9]
TYPEIDENTIFIER [A-Z][a-zA-z0-9_]*
OBJIDENTIFIER [a-z][a-zA-z0-9_]*
SINGLECHARACTER [.;(){},:+=\-\/*~<@]

CLASS [c|C][l|L][a|A][s|S][s|S]
ELSE [e|E][l|L][s|S][e|E]
FALSE_RULE f[a|A][l|L][s|S][e|E]
FI [f|F][i|I]
IF [i|I][f|F]
IN [i|I][n|N]
INHERITS [i|I][n|N][h|H][e|E][r|R][i|I][t|T][s|S]
ISVOID [i|I][s|S][v|V][o|O][i|I][d|D]
LET [l|L][e|E][t|T]
LOOP [l|L][o|O][o|O][p|P]
POOL [p|P][o|O][o|O][l|L]
THEN [t|T][h|H][e|E][n|N]
WHILE [w|W][h|H][i|I][l|L][e|E]
CASE [c|C][a|A][s|S][e|E]
ESAC [e|E][s|S][a|A][c|C]
NEW [n|N][e|E][w|W]
OF [o|O][f|F]
NOT [n|N][o|O][t|T]
TRUE_RULE t[r|R][u|U][e|E]


WHITESPACE [ \n\f\r\t\v]

%%
<INITIAL>--.*$|--.* {
  // Comment
#ifdef DEBUG
  ECHO;
  printf("\nmatched comment\n");
#endif
}

 /*
  *  Nested comments
  */

<INITIAL,MultiLineComment>"(*" {
  BEGIN MultiLineComment;
#ifdef DEBUG
  printf("Increasing comment depth\n");
#endif
  CommentOpenBraketDepth++;
}

<MultiLineComment>(.|{WHITESPACE}) {
  // Multiline comment body, just eat all the input
  PossiblyIncrementLineNum();
}

<MultiLineComment><<EOF>> {
  ExitCommentState();
  cool_yylval.error_msg = "EOF in comment";
  return (ERROR);
}

<MultiLineComment>"*)" {
  if (CommentOpenBraketDepth > 1)
  {
    // Nested comments
    #ifdef DEBUG
      printf("Decreasing comment depth\n");
    #endif
    CommentOpenBraketDepth--;
  } 
  else if (CommentOpenBraketDepth == 1)
  {
    // End comment
    #ifdef DEBUG
      printf("Matched multiline comment\n");
    #endif
    ExitCommentState();
  }
  else
  {
    printf("Should never enter this rule with CommentOpenBraketDepth < 1\n");
  }
}

<INITIAL>"*)" {
  cool_yylval.error_msg = "Unmatched *)";
  return (ERROR);
}

 /*
  *  The multiple-character operators.
  */
<INITIAL>{DARROW}		{ return (DARROW); }
<INITIAL>{ASSIGN}    { return (ASSIGN); }
<INITIAL>"<="        { return (LE); }


 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */

<INITIAL>{CLASS}		  { return (CLASS); }
<INITIAL>{ELSE}		  { return (ELSE); }
<INITIAL>{FI}		    { return (FI); }
<INITIAL>{IF}		    { return (IF); }
<INITIAL>{IN}		    { return (IN); }
<INITIAL>{INHERITS}	{ return (INHERITS); }
<INITIAL>{ISVOID}		{ return (ISVOID); }
<INITIAL>{LET}		    { return (LET); }
<INITIAL>{LOOP}		  { return (LOOP); }
<INITIAL>{POOL}		  { return (POOL); }
<INITIAL>{THEN}		  { return (THEN); }
<INITIAL>{WHILE}		  { return (WHILE); }
<INITIAL>{CASE}		  { return (CASE); }
<INITIAL>{ESAC}		  { return (ESAC); }
<INITIAL>{NEW}		    { return (NEW); }
<INITIAL>{OF}		    { return (OF); }
<INITIAL>{NOT}		    { return (NOT); }

<INITIAL>{FALSE_RULE} { 
  cool_yylval.boolean = false;
  return (BOOL_CONST); 
}
<INITIAL>{TRUE_RULE} { 
  cool_yylval.boolean = true;
  return (BOOL_CONST); 
}
<INITIAL>{SINGLECHARACTER} { 
  return ((int)(*yytext)); 
}

 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for 
  *  \n \t \b \f, the result is c.
  *
  */

<INITIAL>\"[^"]* {
  //TODO: I think this could be simplified to a regex that matches everything instead of using states
  BEGIN StringConstant;
  stringScannerState = StringScannerState::Normal;

  bool isLastBackslashEscaped = yyleng > 1 ? yytext[yyleng-2] == '\\' : false;
  if (yytext[yyleng-1] == '\\' && isLastBackslashEscaped == false) 
  {
    // This covers the case where we have an escaped " (\") in the input
    // "abc\"def" will be parsed as "abc"def
    BEGIN INITIAL;
    yymore();
  }
  else
  {
    PossiblyIncrementLineNum();
    // i == 1 because the first character is a double quote
    bool escape = false;
    for(int i = 1; i < yyleng; ++i)
    {
      if (string_buf_ptr >= string_buf + MAX_STR_CONST)
      {
        // We are at the limit of the buffer, set the error flag so that we return the ERROR token after parsing the rest of the string
        // Reset the buffer so we don't start writing memory outside of the array
        string_buf_ptr = string_buf;
        stringScannerState = StringScannerState::TooLong;
      }

      if (yytext[i] == '\0')
      {
        stringScannerState = StringScannerState::ContainsNullChar;
      }

      if (yytext[i] == '\n' && escape == false)
      {
        ExitStringConstantStartState();
        cool_yylval.error_msg = "Unterminated string constant";
        yyless(i);
        return (ERROR);
      }

      if (yytext[i] == '\\' && escape == false) // backslash character
      {
        escape = true;
        continue;
      }

      char newCharacter = yytext[i];
      
      if (escape == true)
      {
        switch(yytext[i])
        {
          case 'n': 
            newCharacter = '\n';
            break;
          case 't':
            newCharacter = '\t';
            break;
          case 'b':
            newCharacter = '\b';
            break;
          case 'f':
            newCharacter = '\f';
            break;
          default:
            break;
        }
        escape = false;
      }

      *string_buf_ptr++ = newCharacter;
    }    
  }
}

<StringConstant><<EOF>> {
  ExitStringConstantStartState();
  cool_yylval.error_msg = "EOF in string constant";
  return (ERROR);
}

<StringConstant>\" {
  int retVal;
  switch (stringScannerState) {
    case StringScannerState::Normal:
    {
      cool_yylval.symbol = stringtable.add_string(string_buf, string_buf_ptr - string_buf);
      retVal = STR_CONST;
      break;
    }
    case StringScannerState::TooLong:
    {
      cool_yylval.error_msg = "String constant too long";
      retVal = ERROR;
      break;
    }
    case StringScannerState::ContainsNullChar:
    {
      cool_yylval.error_msg = "String contains null character";
      retVal = ERROR;
      break;
    }
    default:
    {
      printf("Should never end string constant while not in one of the above states \n");
      break;
    }
  }
  ExitStringConstantStartState();
  return (retVal);
}

<INITIAL>{DIGIT}+ {
    cool_yylval.symbol = inttable.add_string(yytext);
    return INT_CONST;
}

<INITIAL>{TYPEIDENTIFIER}  {
  cool_yylval.symbol = idtable.add_string(yytext);
  return (TYPEID); 
}
<INITIAL>{OBJIDENTIFIER} {
  cool_yylval.symbol = idtable.add_string(yytext);
  return (OBJECTID);
}

<INITIAL>{WHITESPACE}+ {
  PossiblyIncrementLineNum();
}

<INITIAL>. {
  // Failure case for unable to match any character
  cool_yylval.error_msg = yytext;
  return ERROR;
}
%%
