//
//  AVMediaData_YUV420_Split.hpp
//  AVTestDemo
//
//  Created by tony.jing on 2021/12/3.
//

#ifndef AVMediaData_YUV420_Split_hpp
#define AVMediaData_YUV420_Split_hpp

#include <stdio.h>

/**
 * Split Y, U, V planes in YUV420P file.
 * @param url  Location of Input YUV file.
 * @param w    Width of Input YUV file.
 * @param h    Height of Input YUV file.
 * @param num  Number of frames to process.
 *
 */
int avmediadata_yuv420_split(const char *url , int w , int h , int num);

#endif /* AVMediaData_YUV420_Split_hpp */
