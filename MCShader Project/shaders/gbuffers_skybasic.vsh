#version 120

varying vec4 color;

void main(){
    gl_Position = ftransform();
    //gl_Position /= gl_Position.w;
    //gl_Position.z= 0.999;
    color = gl_Color;
}