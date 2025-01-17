//
// Created by quan on 4/16/17.
//

#ifndef FLUID_SIMULATION_FLUID_KERNELS_H
#define FLUID_SIMULATION_FLUID_KERNELS_H

#include <math.h>
#include <utility.h>
#include <stdio.h>

__global__ void advect_kernel(double *d, double *d0, double *vecX, double *velocY,
                              double *lo, double dt, int N, int k);
__global__ void set_bnd_kernel1(int b, double *x, int N);
__global__ void set_bnd_kernel2(double *x, int N);
__global__ void project_kernel1(double *velocX, double *velocY, double *velocZ,
                               double *p, double *div, int N,
                               double N_recip, int k);
__global__ void project_kernel2(double *velocX, double *velocY, double *velocZ,
                               double *p, int N, int k);
__global__ void lin_solve_kernel(double *x_next, double *x, double *x0, double a,
                                 double cRecip, int N, int m);
__global__ void set_values_kernel(double *x_next, double *x, int m, int N);

#endif //FLUID_SIMULATION_FLUID_KERNELS_H
