# Simple-Language-for-Bitwise-Processing
## Description

In this project, I implemented an expression language, conveniently named P1. The P1 language was meticulously designed to simplify bitwise processing, offering a more intuitive approach compared to C. One notable feature was the ability to assign a variable to a specific bit of another variable by specifying the bit number at the end of the variable name.

```none
x = 5  // x2=1, x1=0, x0=1
y = x2 // set y to the third bit (index of 2) of variable x
final y // y = 1
```
```
x = 15             // x3=1, x2=1, x1=1, x0=1
y = x3, x2, 0, x1, x0  // now y = 27
final y
```
## Tokens
| Keyword/Regular Expression | Token Name | Description                              |
|---------------------------|------------|------------------------------------------|
| in                        | IN         | Keyword used to specify parameters.     |
| none                      | NONE       | Keyword that indicates no parameters.   |
| reduce                    | REDUCE     | Keyword for reduce operations.           |
| expand                    | EXPAND     | Keyword for bitwise-expand operations.   |
| final                     | FINAL      | Indicates return value.                  |
| [a-zA-Z]+                 | ID         | These hold temporary results.            |
| [0-9]+                    | NUMBER     | A decimal number.                        |
| =                         | ASSIGN     | Assignment.                              |
| ~                         | INV        | Bitwise-invert operation.                |
| !                         | BINV       | Single-bit invert operation.             |
| &                         | AND        | Bitwise-and operation.                   |
| \|                        | OR         | Bitwise-or operation.                    |
| ^                         | XOR        | Bitwise-xor operation.                   |
| -                         | MINUS      | Unary minus operation.                   |
| +                         | PLUS       | Addition operation.                      |
| *                         | MULTIPLY   | Multiply operation.                      |
| /                         | DIVIDE     | Unsigned divide operation.               |
| %                         | MOD        | Modulo operation.                        |
| (                         | LPAREN     | Open parentheses.                       |
| )                         | RPAREN     | Close parentheses.                      |
| [                         | LBRACKET   | Open bracket.                            |
| ]                         | RBRACKET   | Close bracket.                           |
| ,                         | COMMA      | Comma.                                   |
| :                         | COLON      | Used by ensembles to construct numbers. |
| \n                        | ENDLINE    | Newline marker.                         |
| "//".*\n                  | COMMENT    | Comment in source code.                  |

## Grammar
```
program: inputs statements_opt final;

inputs:   IN params_list ENDLINE
        | IN NONE ENDLINE;

params_list:    ID
              | params_list COMMA ID;

final: FINAL ensemble endline_opt;

endline_opt: %empty | ENDLINE;            

statements_opt:   %empty
                | statements;

statements:   statement 
            | statements statement ;

statement:   ID ASSIGN ensemble ENDLINE
           | ID NUMBER ASSIGN ensemble ENDLINE
           | ID LBRACKET ensemble RBRACKET ASSIGN ensemble ENDLINE;

ensemble:   expr
          | expr COLON NUMBER // 566 only
          | ensemble COMMA expr
          | ensemble COMMA expr COLON NUMBER; //566 only

expr:   ID
      | ID NUMBER
      | NUMBER
      | expr PLUS expr   // addition
      | expr MINUS expr  // subtraction
      | expr XOR expr    // bitwise-XOR
      | expr AND expr    // bitwise-AND
      | expr OR expr     // bitwise-OR
      | INV expr         // bitwise-invert
      | BINV expr        // least-significant bit invert
      | expr MUL expr    // multiply
      | expr DIV expr    // divide
      | expr MOD expr    // modulo
      | ID LBRACKET ensemble RBRACKET
      | LPAREN ensemble RPAREN
      | LPAREN ensemble RPAREN LBRACKET ensemble RBRACKET
      | REDUCE AND LPAREN ensemble RPAREN
      | REDUCE OR LPAREN ensemble RPAREN
      | REDUCE XOR LPAREN ensemble RPAREN
      | REDUCE PLUS LPAREN ensemble RPAREN
      | EXPAND  LPAREN ensemble RPAREN;
```
## Explanation of each rule

| Rule                                  | Snippet                       | Description                                                                                                                                                                                                                                                                                                                                                                               |
|---------------------------------------|-------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| program                               | in none                       | Declare the input parameters of the program. If none, it’s like a void function in LLVM IR.                                                                                                                                                                                                                                                                                              |
| program                               | in a, b, c                    | Declare the input parameters of the program.                                                                                                                                                                                                                                                                                                                                             |
| params_list                           | a                             | Single argument in a list.                                                                                                                                                                                                                                                                                                |
| params_list                           | a, b                          | Multiple arguments in a list.                                                                                                                                                                                                                                                                                             |
| final                                 | final 1                       | Return 1.                                                                                                                                                                                                                                                                                                                   |
| final                                 | final 1,1,1,1                  | Return 15.                                                                                                                                                                                                                                                                                                                  |
| statements_opt                        |                               | A program may have zero or more statements.                                                                                                                                                                                                                                                                               |
| statement: ID ASSIGN ensemble ENDLINE | x = y+z                       | Assign a variable an ensemble. An ensemble is usually just an expression, but ensembles allow us to put expressions together in new ways. See next example.                                                                                                                                                                                                                             |
| ensemble                              | 1,1,0,1                       | A way of piecing bitwise values together to make new values. This ensemble evaluates to 13. It can be seen as a binary vector converted to int. The least-significant bit is always on the far right. The result of any ensemble is always a 32-bit integer. x, y, z Each comma means shift over one bit. So, this expression means (z<<0) | (y<<1) | (x<<2). x:4, y:2, z:1 We can modify the shifting amount using the colon operator: (z<<1) | (y<<4) | (x<<9). Note, the colons plus commas are cumulative. |
| expr                                  | x = 5                         | Every expression is interpreted as producing a 32 bit integer. But, in some cases, only the least-significant bit matters.                                                                                                                                                                                                                                                                |
| expr: ID                              | x = y                         | y is an ID used in an expression. If y has not yet been assigned, it’s treated as 0 and a warning is printed to stderr, e.g., fprintf(stderr,“%s is used without first being defined. Assuming 0.”,%1). The variable name must appear in the warning.                                                                                                                              |
| expr: NUMBER                          | x = 1                         | Expr can be NUMBER by itself.                                                                                                                                                                                                                                                                                              |
| expr: ID NUMBER                       | y = 5                         | y1 will parse as ID NUMBER. This means get bit at index=1 from y and move it to be the least significant bit of the expression. So, z will become 0, but w will become 1. Bit indices in integers always start at 0, so in this case y1 is equal to 0. Because y is a 32-bit integer, the only legal indices are 0 to 31. If an out-of-range value is given, its behavior is left unspecified. In this case, choose an appropriate non-failing interpretation.               |
| expr: INV expr                        | y = 0                         | Invert all of the bits in y. This flips all 32 bits. Here, x becomes an int with all bits 1, equivalent to -1.                                                                                                                                                                                                                                                                           |
| expr: BINV expr                       | y = 0                         | Invert only the least-significant bit of y. In this case, x becomes 1.                                                                                                                                                                                                                                                                                                                   |
| expr: ID LBRACKET ensemble RBRACKET   | y = 5                         | The bracket notation allows us to access a specific bit using an index. Here y[2] gets the bit with index=2 from y and puts it in x. This means that a single bit from y is put in the LS-bit of x. All other bits of x are 0. Because y is a 32-bit integer, the only legal indices are 0 to 31. If an out-of-range value is given, its behavior is left unspecified. In this case, choose an appropriate non-failing interpretation.                   |
| EXPAND LPAREN ensemble RPAREN         | x = expand(1)                 | The expand operator will fill up all 32-bits of an integer with the LS-bit of its argument. In this case, x will become an integer with all ones.                                                                                                                                                                                                                                       |
| expr: REDUCE AND LPAREN ensemble RPAREN | z = expand(1)                | The reduce& operation loops over all of the values in z and &’s them together into a single bit. Then, it sets the LS-bit of the resulting expression. In this case, y gets the result, and &-ing a bunch of 1s produces 1, so y = 1. We also have reduce| and reduce^ and reduce+ variants. For reduce|, w = 1 as well. For reduce+, s would equal 32.                                                                                                           |
| statement: ID NUMBER ASSIGN ensemble ENDLINE | p = 0                    | Set a single bit of a variable. p1 on the left means to set only the bit at index=1 using the LS-bit of the right-hand size expression. After these two statements, p = 2. Note, it’s illegal to set a bit of p before defining p.                                                                                                                                                      |
| statement: ID LBRACKET ensemble RBRACKET ASSIGN ensemble ENDLINE | p = 0 | This statement rule is similar to the previous one except that it allows an arbitrary index specified in brackets rather than a constant index.                                                                                                                                                                                                                                       |
