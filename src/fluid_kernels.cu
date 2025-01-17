//
// Created by quan on 4/16/17.
//

#include <fluid_kernels.h>

__global__ void advect_kernel(double *d, double *d0, double *velocX, double *velocY,
                              double *velocZ, double dt, int N, int k)
{
    double Ndouble = (double) N;
    double dtx = dt * (N - 2);
    double dty = dt * (N - 2);
    double dtz = dt * (N - 2);

    int j = blockIdx.x + 1;
    int i = threadIdx.x + 1;
    double idouble = (double) i;
    double jdouble = (double) j;
    double kdouble = (double) k;

    double s0, s1, t0, t1, u0, u1;
    double tmp1, tmp2, tmp3, x, y, z;
    double i0, i1, j0, j1, k0, k1;

    tmp1 = dtx * velocX[IX(i, j, k)];
    tmp2 = dty * velocY[IX(i, j, k)];
    tmp3 = dtz * velocZ[IX(i, j, k)];
    x    = idouble - tmp1;
    y    = jdouble - tmp2;
    z    = kdouble - tmp3;

    if(x < 0.5f) x = 0.5f;
    if(x > Ndouble + 0.5f) x = Ndouble + 0.5f;
    i0 = floor(x);
    i1 = i0 + 1.0f;
    if(y < 0.5f) y = 0.5f;
    if(y > Ndouble + 0.5f) y = Ndouble + 0.5f;
    j0 = floor(y);
    j1 = j0 + 1.0f;
    if(z < 0.5f) z = 0.5f;
    if(z > Ndouble + 0.5f) z = Ndouble + 0.5f;
    k0 = floor(z);
    k1 = k0 + 1.0f;

    s1 = x - i0;
    s0 = 1.0f - s1;
    t1 = y - j0;
    t0 = 1.0f - t1;
    u1 = z - k0;
    u0 = 1.0f - u1;

    int i0i = (int) i0;
    int i1i = (int) i1;
    int j0i = (int) j0;
    int j1i = (int) j1;
    int k0i = (int) k0;
    int k1i = (int) k1;

    d[IX(i, j, k)] =

            s0 * ( t0 * (u0 * d0[IX(i0i, j0i, k0i)]
                         +u1 * d0[IX(i0i, j0i, k1i)])
                   +( t1 * (u0 * d0[IX(i0i, j1i, k0i)]
                            +u1 * d0[IX(i0i, j1i, k1i)])))
            +s1 * ( t0 * (u0 * d0[IX(i1i, j0i, k0i)]
                          +u1 * d0[IX(i1i, j0i, k1i)])
                    +( t1 * (u0 * d0[IX(i1i, j1i, k0i)]
                             +u1 * d0[IX(i1i, j1i, k1i)])));
}

__global__ void set_bnd_kernel1(int b, double *x, int N)
{
    int j = blockIdx.x + 1;
    int i = threadIdx.x + 1;

    x[IX(i, j, 0  )] = b == 3 ? -x[IX(i, j, 1  )] : x[IX(i, j, 1  )];
    x[IX(i, j, N-1)] = b == 3 ? -x[IX(i, j, N-2)] : x[IX(i, j, N-2)];

    x[IX(i, 0  , j)] = b == 2 ? -x[IX(i, 1  , j)] : x[IX(i, 1  , j)];
    x[IX(i, N-1, j)] = b == 2 ? -x[IX(i, N-2, j)] : x[IX(i, N-2, j)];

    x[IX(0  , i, j)] = b == 1 ? -x[IX(1  , i, j)] : x[IX(1  , i, j)];
    x[IX(N-1, i, j)] = b == 1 ? -x[IX(N-2, i, j)] : x[IX(N-2, i, j)];
}

__global__ void set_bnd_kernel2(double *x, int N)
{
    x[IX(0, 0, 0)]       = 0.33f * (x[IX(1, 0, 0)]
                                  + x[IX(0, 1, 0)]
                                  + x[IX(0, 0, 1)]);
    x[IX(0, N-1, 0)]     = 0.33f * (x[IX(1, N-1, 0)]
                                  + x[IX(0, N-2, 0)]
                                  + x[IX(0, N-1, 1)]);
    x[IX(0, 0, N-1)]     = 0.33f * (x[IX(1, 0, N-1)]
                                  + x[IX(0, 1, N-1)]
                                  + x[IX(0, 0, N)]);
    x[IX(0, N-1, N-1)]   = 0.33f * (x[IX(1, N-1, N-1)]
                                  + x[IX(0, N-2, N-1)]
                                  + x[IX(0, N-1, N-2)]);
    x[IX(N-1, 0, 0)]     = 0.33f * (x[IX(N-2, 0, 0)]
                                  + x[IX(N-1, 1, 0)]
                                  + x[IX(N-1, 0, 1)]);
    x[IX(N-1, N-1, 0)]   = 0.33f * (x[IX(N-2, N-1, 0)]
                                  + x[IX(N-1, N-2, 0)]
                                  + x[IX(N-1, N-1, 1)]);
    x[IX(N-1, 0, N-1)]   = 0.33f * (x[IX(N-2, 0, N-1)]
                                  + x[IX(N-1, 1, N-1)]
                                  + x[IX(N-1, 0, N-2)]);
    x[IX(N-1, N-1, N-1)] = 0.33f * (x[IX(N-2, N-1, N-1)]
                                  + x[IX(N-1, N-2, N-1)]
                                  + x[IX(N-1, N-1, N-2)]);
}

__global__ void project_kernel1(double *velocX, double *velocY, double *velocZ,
                               double *p, double *div, int N, double N_recip, int k)
{
    int j = blockIdx.x + 1;
    int i = threadIdx.x + 1;

    div[IX(i, j, k)] = -0.5f*(
             velocX[IX(i+1, j  , k  )]
            -velocX[IX(i-1, j  , k  )]
            +velocY[IX(i  , j+1, k  )]
            -velocY[IX(i  , j-1, k  )]
            +velocZ[IX(i  , j  , k+1)]
            -velocZ[IX(i  , j  , k-1)]
        ) * N_recip;
    p[IX(i, j, k)] = 0;
}

__global__ void project_kernel2(double *velocX, double *velocY, double *velocZ,
                                double *p, int N, int k)
{
    int j = blockIdx.x + 1;
    int i = threadIdx.x + 1;

    velocX[IX(i, j, k)] -= 0.5f * (  p[IX(i+1, j, k)]
                                    -p[IX(i-1, j, k)]) * N;
    velocY[IX(i, j, k)] -= 0.5f * (  p[IX(i, j+1, k)]
                                    -p[IX(i, j-1, k)]) * N;
    velocZ[IX(i, j, k)] -= 0.5f * (  p[IX(i, j, k+1)]
                                    -p[IX(i, j, k-1)]) * N;
}

__global__ void lin_solve_kernel(double *x_next, double *x, double *x0, double a,
                                 double cRecip, int N, int m)
{
    int j = blockIdx.x + 1;
    int i = threadIdx.x + 1;

    x_next[IX(i, j, m)] = (x0[IX(i, j, m)]
                           + a * (x[IX(i+1, j  , m  )]
                                 + x[IX(i-1, j  , m  )]
                                 + x[IX(i  , j+1, m  )]
                                 + x[IX(i  , j-1, m  )]
                                 + x[IX(i  , j  , m+1)]
                                 + x[IX(i  , j  , m-1)]))
                          * cRecip;
}

__global__ void set_values_kernel(double *x_next, double *x, int m, int N)
{
    int j = blockIdx.x + 1;
    int i = threadIdx.x + 1;

    x[IX(i, j, m)] = x_next[IX(i, j, m)];
}


