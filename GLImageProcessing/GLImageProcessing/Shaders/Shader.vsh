//
//  Shader.vsh
//  GLImageProcessing
//
//  Created by 23 on 9/8/12.
//  Copyright (c) 2012 Aged & Distilled. All rights reserved.
//

attribute vec4 position;
    // This attribute comes from the client application
    // represents the location of each vertex to render

attribute vec2 textureCoordinate;
    // This attribute comes from the client application
    // represents the texture coordinates to use for this vertex

varying vec2 interpolatedTextureCoordinate;
    // This varible is interpolated for each fragment from the contributing vertices

uniform mat4    mvpMatrix;
    // a tranformation matrix supplied by the client to go from model and view space to clip space

void main()
{
    // use the current model view projection to transform all the vertices
    gl_Position = mvpMatrix * position;
    
    // make the color attribute the client set for this vertex available to the fragment shader
    interpolatedTextureCoordinate = textureCoordinate;
}
