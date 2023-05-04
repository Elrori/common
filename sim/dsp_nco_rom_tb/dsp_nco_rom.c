#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#define PI 3.1415926
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
    fp1 = fopen("dsp_nco_rom.txt","w");   
    fp2 = fopen("dsp_nco_rom_full.log","w");   
    if(NULL==fp1 || NULL==fp2) printf("Can not creat file!\r\n");
    else
    {
        printf("File created successfully!\n");
        for(int i=0;i<depth;i++)
        {
            float y =  sin(2 * PI * i / depth);    
            y       =  1 * y * ((float)( (1<<(width-1))-1) );
            y       = round(y);
            int z   = (int)y;
            if(i != 0 && i <= depth / 4)
                fprintf(fp1,"%x\n", z & ((1<<width)-1) );
            fprintf(fp2,"%x\n", z & ((1<<width)-1) );
        }
		printf("Write file to: \ndsp_nco_rom.txt\ndsp_nco_rom_full.log\n\n");
        fclose(fp1);
	fclose(fp2);
    }
}
