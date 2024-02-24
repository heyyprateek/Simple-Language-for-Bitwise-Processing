%{
#include <stdio.h>
#include <math.h>
#include <cstdio>
#include <list>
#include <iostream>
#include <string>
#include <memory>
#include <stdexcept>

#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/Value.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/Type.h"
#include "llvm/IR/IRBuilder.h"

#include "llvm/Bitcode/BitcodeReader.h"
#include "llvm/Bitcode/BitcodeWriter.h"
#include "llvm/Support/SystemUtils.h"
#include "llvm/Support/ToolOutputFile.h"
#include "llvm/Support/FileSystem.h"

using namespace std;
using namespace llvm;  

#include "p1.y.hpp"

%}

%%

[ \r\t]         //ignore space or tab

in            { return IN; }
final         { return FINAL; }
none          { return NONE;  }
reduce        { return REDUCE; }
expand        { return EXPAND; }
[a-zA-Z]+     { yylval.id = new string(yytext); return ID; }
[0-9]+        { yylval.number = atoi(yytext); return NUMBER; }
"["           { return LBRACKET; }
"]"           { return RBRACKET; }
"("           { return LPAREN; }
")"           { return RPAREN; }
"="           { return ASSIGN; }
"*"           { return MUL; }
"%"           { return MOD; }
"/"           { return DIV; }
"+"           { return PLUS; }
"-"           { return MINUS; }
"^"           { return XOR; }
"|"           { return OR; }
"&"           { return AND; }
"~"           { return INV; }
"!"           { return BINV; }
","           { return COMMA; }
":"           { return COLON; }
\n            { return ENDLINE; }


"//".*\n      { }

.             { printf("syntax error!\n"); exit(1); }
%%

int yywrap()
{
  return 1;
}
