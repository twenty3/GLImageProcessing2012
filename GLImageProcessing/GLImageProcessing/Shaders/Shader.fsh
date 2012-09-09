//
//  Shader.fsh
//  GLImageProcessing
//
//  Created by 23 on 9/8/12.
//  Copyright (c) 2012 Aged & Distilled. All rights reserved.
//

varying lowp vec4 colorVarying;

void main()
{
    gl_FragColor = colorVarying;
}
