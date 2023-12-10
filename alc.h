#define SYM_TABLE_SIZE 52
#define ARR_LEN 255
#define ID_LEN 31
#include <stdbool.h>

//Action modes for get/set values
#define SET 0
#define GET 1

//Variables types
typedef enum {
    none, integer,array, constArr, constInt
} varType; 

typedef struct 
 {
    char name[ARR_LEN];
    int indx;
    varType type;
    int ecounter;
    int size;
 } Expression;

typedef struct 
{
    varType type;
    int size;
    int indx;
    char name[ID_LEN];
    char sizeVar_E_Name[ID_LEN];
} ST_Var;

typedef struct 
{
    int size;
    int indx;
    char val[ARR_LEN];
} ConstArrST_Var;

typedef struct 
{
    int indx;
    int val;
} ConstIntST_Var;

