#include <fluid.h>
#include <unistd.h>

FluidCube *FluidCubeCreate(int size, int diffusion, int viscosity, double dt)
{
    FluidCube *cube = (FluidCube *) malloc(sizeof(*cube));
    size_t N = (size_t) size;

    cube->size = size;
    cube->dt = dt;
    cube->diff = diffusion;
    cube->visc = viscosity;

    cudaMallocManaged((void **) &cube->s, N * N * N * sizeof(double));
    cudaMallocManaged((void **) &cube->density, N * N * N * sizeof(double));

    cudaMallocManaged((void **) &cube->Vx, N * N * N * sizeof(double));
    cudaMallocManaged((void **) &cube->Vy, N * N * N * sizeof(double));
    cudaMallocManaged((void **) &cube->Vz, N * N * N * sizeof(double));

    cudaMallocManaged((void **) &cube->Vx0, N * N * N * sizeof(double));
    cudaMallocManaged((void **) &cube->Vy0, N * N * N * sizeof(double));
    cudaMallocManaged((void **) &cube->Vz0, N * N * N * sizeof(double));

    return cube;
}

void FluidCubeFree(FluidCube *cube)
{
    cudaFree(cube->s);
    cudaFree(cube->density);

    cudaFree(cube->Vx);
    cudaFree(cube->Vy);
    cudaFree(cube->Vz);

    cudaFree(cube->Vx0);
    cudaFree(cube->Vy0);
    cudaFree(cube->Vz0);

    free(cube);
}

static void set_bnd(int b, double *x, int N)
{
    set_bnd_kernel <<< N-2, N-2 >>> (b, x, N);
    cudaDeviceSynchronize();
    printf("   %p\n", x);

    x[IX(0, 0, 0)]       = 0.33f * (x[IX(1, 0, 0)]
                                  + x[IX(0, 1, 0)]
                                  + x[IX(0, 0, 1)]);
    printf("fa\n");
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

static void lin_solve(int b, double *x, double *x0, double a, double c, int iter, int N)
{
    double cRecip = 1.0 / c;
    for (int k = 0; k < iter; k++) {
        for (int m = 1; m < N - 1; m++) {
            for (int j = 1; j < N - 1; j++) {
                for (int i = 1; i < N - 1; i++) {
                    x[IX(i, j, m)] =
                        (x0[IX(i, j, m)]
                            + a*(    x[IX(i+1, j  , m  )]
                                    +x[IX(i-1, j  , m  )]
                                    +x[IX(i  , j+1, m  )]
                                    +x[IX(i  , j-1, m  )]
                                    +x[IX(i  , j  , m+1)]
                                    +x[IX(i  , j  , m-1)]
                           )) * cRecip;
                }
            }
        }
        set_bnd(b, x, N);
    }
}

static void diffuse (int b, double *x, double *x0, double diff, double dt, int iter, int N)
{
    double a = dt * diff * (N - 2) * (N - 2);
    lin_solve(b, x, x0, a, 1 + 6 * a, iter, N);
}

static void advect(int b, double *d, double *d0,  double *velocX,
                   double *velocY, double *velocZ, double dt, int N)
{
    printf("%f\n", d[IX(0, 0, 0)]);
    double *d_d;
    cudaMalloc((void **) &d_d, N*N*N*sizeof(double));
    cudaMemcpy(d_d, d, sizeof(double)*N*N*N, cudaMemcpyHostToDevice);

    for (int k = 1; k < N - 1; k++) {
        advect_kernel <<< N - 2, N - 2 >>> (d_d, d0, velocX, velocY, velocZ, dt, N, k);
    }
    cudaDeviceSynchronize();
    cudaMemcpy(d, d_d, sizeof(double)*N*N*N, cudaMemcpyDeviceToHost);
    printf("%f\n", d[IX(0, 0, 0)]);

    cudaFree(d_d);

    set_bnd(b, d, N);
}

static void project(double *velocX, double *velocY, double *velocZ,
                    double *p, double *div, int iter, int N)
{
    double N_recip = 1 / N;
    for (int k = 1; k < N - 1; k++) {
        //project_kernel <<< N-1, N-1 >>> (velocX, velocY, velocZ, p, div, iter, N, N_recip, k);

         for (int j = 1; j < N - 1; j++) {
             for (int i = 1; i < N - 1; i++) {
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
         }
    }
    cudaDeviceSynchronize();
    printf("something\n");

    set_bnd(0, div, N);
    set_bnd(0, p, N);
    lin_solve(0, p, div, 1, 6, iter, N);

    for (int k = 1; k < N - 1; k++) {
        for (int j = 1; j < N - 1; j++) {
            for (int i = 1; i < N - 1; i++) {
                velocX[IX(i, j, k)] -= 0.5f * (  p[IX(i+1, j, k)]
                                                -p[IX(i-1, j, k)]) * N;
                velocY[IX(i, j, k)] -= 0.5f * (  p[IX(i, j+1, k)]
                                                -p[IX(i, j-1, k)]) * N;
                velocZ[IX(i, j, k)] -= 0.5f * (  p[IX(i, j, k+1)]
                                                -p[IX(i, j, k-1)]) * N;
            }
        }
    }
    set_bnd(1, velocX, N);
    set_bnd(2, velocY, N);
    set_bnd(3, velocZ, N);

    printf("awd\n");
}

void FluidCubeStep(FluidCube *cube, perf_t *perf_struct)
{
    int N          = cube->size;
    double visc     = cube->visc;
    double diff     = cube->diff;
    double dt       = cube->dt;
    double *Vx      = cube->Vx;
    double *Vy      = cube->Vy;
    double *Vz      = cube->Vz;
    double *Vx0     = cube->Vx0;
    double *Vy0     = cube->Vy0;
    double *Vz0     = cube->Vz0;
    double *s       = cube->s;
    double *density = cube->density;

    double start = 0, end = 0;

    start = get_time();
    diffuse(1, Vx0, Vx, visc, dt, 4, N);
    end = get_time();
    perf_struct->timeDiffuse += end - start;

    start = get_time();
    diffuse(2, Vy0, Vy, visc, dt, 4, N);
    end = get_time();
    perf_struct->timeDiffuse += end - start;

    start = get_time();
    diffuse(3, Vz0, Vz, visc, dt, 4, N);
    end = get_time();
    perf_struct->timeDiffuse += end - start;

    start = get_time();
    project(Vx0, Vy0, Vz0, Vx, Vy, 4, N);
    end = get_time();
    perf_struct->timeProject += end - start;

    start = get_time();
    advect(1, Vx, Vx0, Vx0, Vy0, Vz0, dt, N);
    end = get_time();
    perf_struct->timeAdvect += end - start;

    start = get_time();
    advect(2, Vy, Vy0, Vx0, Vy0, Vz0, dt, N);
    end = get_time();
    perf_struct->timeAdvect += end - start;

    start = get_time();
    advect(3, Vz, Vz0, Vx0, Vy0, Vz0, dt, N);
    end = get_time();
    perf_struct->timeAdvect += end - start;

    start = get_time();
    project(Vx, Vy, Vz, Vx0, Vy0, 4, N);
    end = get_time();
    perf_struct->timeProject += end - start;

    start = get_time();
    diffuse(0, s, density, diff, dt, 4, N);
    end = get_time();
    perf_struct->timeDiffuse += end - start;

    start = get_time();
    advect(0, density, s, Vx, Vy, Vz, dt, N);
    end = get_time();
    perf_struct->timeAdvect += end - start;

    perf_struct->totalDiffuse += 4;
    perf_struct->totalAdvect += 4;
    perf_struct->totalProject += 2;
}

void FluidCubeAddDensity(FluidCube *cube, int x, int y, int z, double amount)
{
    int N = cube->size;
    cube->density[IX(x, y, z)] += amount;
}

void FluidCubeAddVelocity(FluidCube *cube, int x, int y, int z,
                          double amountX, double amountY, double amountZ)
{
    int N = cube->size;
    int index = IX(x, y, z);

    cube->Vx[index] += amountX;
    cube->Vy[index] += amountY;
    cube->Vz[index] += amountZ;
}
