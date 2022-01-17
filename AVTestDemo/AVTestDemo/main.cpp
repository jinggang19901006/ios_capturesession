//
//  main.cpp
//  AVTestDemo
//
//  Created by tony.jing on 2021/12/3.
//

#include <iostream>
#include <string.h>
#include <stdio.h>
#include "AVMediaData_H264_Parser.hpp"
#include "AVMediaData_YUV420_Split.hpp"

int main(int argc, const char * argv[]) {

    avmediadata_h264_parser("sintel.h264");
    
    avmediadata_yuv420_split("", 256, 256, 1);
    return 0;
}
