#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#define PI 3.1415926535898
int count1(int n){
    int res = 0;
    while (n){
        res += (n & 0x1);
        n >>= 1;
    }
    return res;
}
int main(int argc,char **argv){
    int depth;
    int width;
    FILE *fp1;
    FILE *fp2;
    FILE *fp3;
    FILE *fp4;
    FILE *fp5;
    FILE *fp6;
    if(argc != 3){
        printf("Argv ERROR\nUsage: dsp_nco_rom <mem depth(n points)> <mem width>\n");
        return 0;
    }
    depth = atoi(argv[1]);
    width = atoi(argv[2]);
    int cnt = count1(depth);
    if(cnt != 1){
        printf("Error, memory depth illegal: %d\n",cnt);
        return 0;
    }
    const char* filename1="dsp_nco_rom_sin90.txt";
    const char* filename2="dsp_nco_rom_sin360.txt";
    const char* filename3="dsp_nco_rom_cos90.txt";
    const char* filename4="dsp_nco_rom_cos360.txt";
    const char* filename5="dsp_nco_rom_sin45.txt";
    const char* filename6="dsp_nco_rom_cos45.txt";
    fp1 = fopen(filename1,"w");   
    fp2 = fopen(filename2,"w");
    fp3 = fopen(filename3,"w");
    fp4 = fopen(filename4,"w");
    fp5 = fopen(filename5,"w");
    fp6 = fopen(filename6,"w");
    if(NULL==fp1 || NULL==fp2 || NULL==fp3 || NULL==fp4 || NULL==fp5 || NULL==fp6) 
	printf("Can not creat file!\r\n");
    else
    {
        printf("ROM File created successfully!\n");
        for(int i=0;i<depth;i++)
        {
            float y =  sin(2 * PI * i / depth);    
            y       =  1 * y * ((float)( (1<<(width-1))-1) );
            y       = round(y);
            int z   = (int)y;
            if(i != 0 && i <= depth / 4)
                fprintf(fp1,"%x\n", z & ((1<<width)-1) );
            if(i != 0 && i <= depth / 8)
                fprintf(fp5,"%x\n", z & ((1<<width)-1) );
            fprintf(fp2,"%x\n", z & ((1<<width)-1) );
            
            y       =  cos(2 * PI * i / depth);
            y       =  1 * y * ((float)( (1<<(width-1))-1) );
            y       = round(y);
            z       = (int)y;
            if(i != 0 && i <= depth / 4)
                fprintf(fp3,"%x\n", z & ((1<<width)-1) );
            if(i != 0 && i <= depth / 8)
                fprintf(fp6,"%x\n", z & ((1<<width)-1) );
            fprintf(fp4,"%x\n", z & ((1<<width)-1) );
	}
	printf("Write file to \n%s\n%s\n%s\n%s\n%s\n%s\n\n",filename1,filename2,filename3,filename4,filename5,filename6);
    fclose(fp1);
	fclose(fp2);
	fclose(fp3);
	fclose(fp4);
	fclose(fp5);
	fclose(fp6);
    }
}
