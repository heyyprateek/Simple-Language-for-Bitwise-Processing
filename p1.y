%{
#include <cstdio>
#include <list>
#include <vector>
#include <map>
#include <iostream>
#include <string>
#include <memory>
#include <stdexcept>

#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/Value.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/Type.h"
#include "llvm/IR/Verifier.h"

#include "llvm/Bitcode/BitcodeReader.h"
#include "llvm/Bitcode/BitcodeWriter.h"
#include "llvm/Support/SystemUtils.h"
#include "llvm/Support/ToolOutputFile.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/Support/FileSystem.h"

using namespace llvm;
using namespace std;

// Need for parser and scanner
extern FILE *yyin;
int yylex();
void yyerror(const char*);
int yyparse();
 
// Needed for LLVM
string funName;
Module *M;
LLVMContext TheContext;
IRBuilder<> Builder(TheContext);

// I will need data structures to represent a variety of expressions


// struct EnsembleMaker {
//   Value *val;
//   int colonValue;
// };

// struct FullEnsemble {
//   vector<EnsembleMaker> ensembles;
//   int sizeOfEnsemble; // Or a pointer to an element
// };

// Value *getInputArgument(string name) {
//   Function *F = Builder.GetInsertBlock()->getParent();
//   for (auto &arg : F->args()) {
//     if (arg.getName() == name) {
//       return &arg;
//     }
//   }
//   return nullptr;
// }
map<string, Value*> variables;

%}

%union {
  vector<string> *params_list;
  int number;
  string* id;
  Value *val;
  // FullEnsemble ensemble;

};

/*%define parse.trace*/

%type <params_list> params_list
%type <val> ensemble
/* %type <val> final */
%type <val> expr statement statements statements_opt
/* %type  statement statements statements_opt */

%token IN FINAL
%token ERROR 
/* %token RETURN */
%token <number> NUMBER
%token <id> ID 
%token BINV INV PLUS MINUS XOR AND OR MUL DIV MOD
%token COMMA ENDLINE ASSIGN LBRACKET RBRACKET LPAREN RPAREN NONE COLON
%token REDUCE EXPAND

%precedence BINV
%precedence INV
%left PLUS MINUS OR
%left MUL DIV AND XOR MOD

%start program

%%

program: inputs statements_opt final  { YYACCEPT; };

inputs:   IN params_list ENDLINE      {  
                                        std::vector<Type*> param_types;
                                        for(auto s: *$2)
                                          {
                                            param_types.push_back(Builder.getInt32Ty());
                                          }
                                        ArrayRef<Type*> Params (param_types);

                                        // Create int function type with no arguments
                                        FunctionType *FunType = 
                                          FunctionType::get(Builder.getInt32Ty(),Params,false);

                                        // Create a main function
                                        Function *Function = Function::Create(FunType,GlobalValue::ExternalLinkage,funName,M);

                                        int arg_no=0;
                                        for(auto &a: Function->args()) {
                                          // iterate over arguments of function
                                          // match name to position
                                          variables[(*$2)[arg_no]] = &a;
                                          arg_no++;
                                        }
                                        
                                        //Add a basic block to main to hold instructions, and set Builder
                                        //to insert there
                                        Builder.SetInsertPoint(BasicBlock::Create(TheContext, "entry", Function));
                                      }
          | IN NONE ENDLINE           { 
                                        // Create int function type with no arguments
                                        FunctionType *FunType = 
                                          FunctionType::get(Builder.getInt32Ty(),false);

                                        // Create a main function
                                        Function *Function = Function::Create(FunType,  
                                              GlobalValue::ExternalLinkage,funName,M);

                                        //Add a basic block to main to hold instructions, and set Builder
                                        //to insert there
                                        Builder.SetInsertPoint(BasicBlock::Create(TheContext, "entry", Function));
                                      };
params_list:  ID                      {
                                        $$ = new vector<string>;
                                        // add ID to vector
                                        $$->push_back(string(*$1));
                                      }
              | params_list COMMA ID  {
                                        // add ID to $1
                                        $1->push_back(string(*$3));
                                      };

final:  FINAL ensemble endline_opt  { Builder.CreateRet($2); return 0;};

endline_opt:  %empty | ENDLINE;
            

statements_opt: %empty 
                | statements {$$ = $1;};

statements:   statement 
              | statements statement {$$ = $2;};

statement:  ID ASSIGN ensemble ENDLINE                                {
                                                                        // check if *$1 is in variables
                                                                        if(variables.count(*$1) == 0)  // ID not declared
                                                                          {
                                                                            variables[*$1] = $3;
                                                                            Value* result = Builder.CreateGlobalStringPtr(*$1, " ");
                                                                            $$ = result;
                                                                          }
                                                                          else {
                                                                            variables[*$1] = $3;
                                                                            $$ = variables[*$1];
                                                                          }
                                                                      }
            | ID NUMBER ASSIGN ensemble ENDLINE                       {
                                                                        // check if *$1 is in variables
                                                                        if(variables.count(*$1) != 0)  // ID found
                                                                          {
                                                                            // variables[*$1] = $4;
                                                                            // Value* result = Builder.CreateGlobalStringPtr(*$1, " ");
                                                                            Value* ensembleLastBit = Builder.CreateAnd($4,1);
                                                                            Value* shifted = Builder.CreateShl(ensembleLastBit, $2);
                                                                            Value* result = Builder.CreateOr(variables[*$1], shifted);
                                                                            variables[*$1] = result;
                                                                            $$ = result;
                                                                          }
                                                                          else {
                                                                            printf("Variable %s not declared\n", (*$1).c_str());                                                        
                                                                            YYABORT;
                                                                          }
                                                                      }
            | ID LBRACKET ensemble RBRACKET ASSIGN ensemble ENDLINE   {
                                                                        // check if *$1 is in variables
                                                                        if(variables.count(*$1) != 0)  // ID found
                                                                          {
                                                                            // variables[*$1] = $4;
                                                                            // Value* result = Builder.CreateGlobalStringPtr(*$1, " ");
                                                                            Value* ensembleLastBit = Builder.CreateAnd($6, 1);
                                                                            Value* shifted = Builder.CreateShl(ensembleLastBit, $3);
                                                                            Value* mask = Builder.CreateNot(Builder.CreateShl(Builder.getInt32(1), $3));
                                                                            Value* masked = Builder.CreateAnd(variables[*$1], mask);
                                                                            Value* result = Builder.CreateOr(masked, shifted);
                                                                            // Value* result = Builder.CreateOr(variables[*$1], shifted);
                                                                            variables[*$1] = result;
                                                                            $$ = result;
                                                                          }
                                                                          else {
                                                                            printf("Variable %s not declared\n", (*$1).c_str());                                                        
                                                                          }
                                                                      };

ensemble:  expr                                 {$$ = $1;}
          | expr COLON NUMBER                   {$$ = Builder.CreateShl($1, $3);} // 566 only
          | ensemble COMMA expr                 { // Ensemble = Ensemble << revPos | expr
                                                  // $$ = $1 << 1 | $3
                                                  $$ = Builder.CreateOr(Builder.CreateShl($1, 1), $3);
                                                }
          | ensemble COMMA expr COLON NUMBER    {// Ensemble = Ensemble << (revPos + NUMBER + 1) | expr << NUMBER
                                                  auto num = Builder.getInt32($5);
                                                  $$ = Builder.CreateOr(Builder.CreateShl($1, num + 1), Builder.CreateShl($3, num));
                                                };

expr:   ID                                                  { // Get the function arguments
                                                              // check if *$1 is in variables
                                                              if(variables.count(*$1) == 0)  // ID not found
                                                                {
                                                                  variables[*$1] = Builder.getInt32(0);
                                                                  fprintf(stderr,"%s is used without first being defined. Assuming 0.",(*$1).c_str());                                     
                                                                }
                                                                $$ = variables[*$1];
                                                            }
        | ID NUMBER                                         { // Get the bitIndex-th bit of the argument
                                                              if (variables.count(*$1) != 0) {
                                                                if ($2 < 0 || $2 > 31) {
                                                                  printf("Bit index %d out of range\n", $2);
                                                                }
                                                                else {
                                                                  auto value = variables[*$1];
                                                                  $$ = Builder.CreateAnd(Builder.CreateLShr(value, $2), 1);
                                                                }
                                                              } 
                                                              else {
                                                                printf("Variable %s not found\n", (*$1).c_str());
                                                              }
                                                            }
        | NUMBER                                            { $$ = Builder.getInt32($1); }
        | expr PLUS expr                                    { $$ = Builder.CreateAdd($1, $3); }
        | expr MINUS expr                                   { $$ = Builder.CreateSub($1, $3); }
        | expr XOR expr                                     { $$ = Builder.CreateXor($1, $3); }
        | expr AND expr                                     { $$ = Builder.CreateAnd($1, $3); }
        | expr OR expr                                      { $$ = Builder.CreateOr($1, $3); }
        | INV expr                                          { $$ = Builder.CreateNot($2); }  
        | BINV expr                                         { $$ = Builder.CreateXor($2, Builder.getInt32(1));}
        | expr MUL expr                                     { $$ = Builder.CreateMul($1, $3);}
        | expr DIV expr                                     { $$ = Builder.CreateSDiv($1, $3);}
        | expr MOD expr                                     { $$ = Builder.CreateSRem($1, $3);}
        | ID LBRACKET ensemble RBRACKET                     { // Get the bitIndex-th bit of the argument
                                                              auto value = variables[*$1];
                                                              $$ = Builder.CreateAnd(Builder.CreateLShr(value, $3), 1);
                                                            }
        | LPAREN ensemble RPAREN                            { $$ = $2;}
        /* 566 only */
        | LPAREN ensemble RPAREN LBRACKET ensemble RBRACKET {
                                                              $$ = Builder.CreateAnd(Builder.CreateLShr($2, $5), 1);
                                                            }
        | REDUCE AND LPAREN ensemble RPAREN                 {
                                                              // // Create a vector with all right-shifted versions of $4
                                                              // Value *vec = UndefValue::get(VectorType::get(Builder.getInt32Ty(), 32));
                                                              // for (int i = 0; i < 32; i++) {
                                                              //   Value *shifted = Builder.CreateLShr($4, i);
                                                              //   vec = Builder.CreateInsertElement(vec, shifted, i);
                                                              // }
                                                              // // Perform a reduction operation using the and operator
                                                              // Function *reduce_and = Intrinsic::getDeclaration(M, Intrinsic::reduce_and, Builder.getInt32Ty());
                                                              // $$ = Builder.CreateCall(reduce_and, vec);

                                                              Value *var = $4; // Assuming $1 is the 32-bit integer
                                                              Value *notVar = Builder.CreateNot(var); // Flip all the bits
                                                              Value *isZeroBitPresent = Builder.CreateICmpNE(notVar, Builder.getInt32(0)); // Check if the result is not zero
                                                              // if isZeroBitPresent is true, then the result is 0, otherwise it is 1
                                                              $$ = Builder.CreateNot(Builder.CreateZExt(isZeroBitPresent, Builder.getInt32Ty()));
                                                            }
        | REDUCE OR LPAREN ensemble RPAREN                  {
                                                              // Check if value is greater than 1
                                                              Value* result = Builder.CreateICmpUGT($4, Builder.getInt32(0));
                                                              // Convert boolean result to integer
                                                              $$ = Builder.CreateZExt(result, Builder.getInt32Ty());
                                                            }
        | REDUCE XOR LPAREN ensemble RPAREN                 {
                                                              Function *ctpop = Intrinsic::getDeclaration(M, Intrinsic::ctpop, Builder.getInt32Ty());
                                                              Value *count = Builder.CreateCall(ctpop, $4);
                                                              $$ = Builder.CreateAnd(count, 1);
                                                            }
        | REDUCE PLUS LPAREN ensemble RPAREN                {
                                                                // Create a vector with all right-shifted versions of $4
                                                                // Value *vec = UndefValue::get(VectorType::get(Builder.getInt32Ty(), Builder.getInt32Ty()));
                                                                // for (int i = 0; i < 32; i++) {
                                                                //   Value *shifted = Builder.CreateLShr($4, i);
                                                                //   vec = Builder.CreateInsertElement(vec, shifted, i);
                                                                // }
                                                                // // Perform a reduction operation using the add operator
                                                                // Function *reduce_add = Intrinsic::getDeclaration(M, Intrinsic::vp_reduce_add, {Builder.getInt32Ty()});
                                                                // $$ = Builder.CreateCall(reduce_add, vec);

                                                                Function* ctpop = M->getFunction("llvm.ctpop.i32");
                                                                vector<Type*>ctpop_args;
                                                                ctpop_args.push_back(Builder.getInt32Ty());
                                                                FunctionType *ctpop_type = FunctionType::get(Builder.getInt32Ty(), ctpop_args, false);
                                                                ctpop = llvm::Function::Create(ctpop_type, GlobalValue::ExternalLinkage, "llvm.ctpop.i32", M);
                                                                Value* ctpop_call = Builder.CreateCall(ctpop, $4);
                                                                $$ = ctpop_call;
                                                              }
        | EXPAND  LPAREN ensemble RPAREN                    {
                                                              // Extract the last bit of $3
                                                              Value *lastBit = Builder.CreateAnd($3, Builder.getInt32(1));

                                                              // Create a 32-bit value consisting of the last bit
                                                              $$ = Builder.CreateSelect(Builder.CreateICmpEQ(lastBit, Builder.getInt32(1)),
                                                                                        Builder.getInt32(0xFFFFFFFF),
                                                                                        Builder.getInt32(0));
                                                            };
%%

unique_ptr<Module> parseP1File(const string &InputFilename)
{
  funName = InputFilename;
  if (funName.find_last_of('/') != string::npos)
    funName = funName.substr(funName.find_last_of('/')+1);
  if (funName.find_last_of('.') != string::npos)
    funName.resize(funName.find_last_of('.'));
    
  //errs() << "Function will be called " << funName << ".\n";
  
  // unique_ptr will clean up after us, call destructor, etc.
  unique_ptr<Module> Mptr(new Module(funName.c_str(), TheContext));

  // set global module
  M = Mptr.get();
  
  /* this is the name of the file to generate, you can also use
     this string to figure out the name of the generated function */
  yyin = fopen(InputFilename.c_str(),"r");

  //yydebug = 1;
  if (yyparse() != 0)
    // errors, so discard module
    Mptr.reset();
  else
    // Dump LLVM IR to the screen for debugging
    M->print(errs(),nullptr,false,true);
  
  return Mptr;
}

void yyerror(const char* msg)
{
  printf("%s\n",msg);
}
