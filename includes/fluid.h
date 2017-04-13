#ifndef FLUID_H
#define FLUID_H

#include <math.h>
#include <stdlib.h>

#define IX(x, y, z) ((x) + (y) * N + (z) * N * N)

struct FluidCube {
    int size;
    double dt;
    double diff;
    double visc;
    
    double *s;
    double *density;
    
    double *Vx;
    double *Vy;
    double *Vz;

    double *Vx0;
    double *Vy0;
    double *Vz0;
};
typedef struct FluidCube FluidCube;

FluidCube *FluidCubeCreate(int size, int diffusion, int viscosity, double dt);
void FluidCubeFree(FluidCube *cube);
void FluidCubeStep(FluidCube *cube);
void FluidCubeAddDensity(FluidCube *cube, int x, int y, int z, double amount);
void FluidCubeAddVelocity(FluidCube *cube, int x, int y, int z, 
                          double amountX, double amountY, double amountZ);


#endif