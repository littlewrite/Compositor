#ifndef NoisePixels_h
#define NoisePixels_h
#include <stdint.h>
#include <stddef.h>
// Adds noise to the color of premultiplied RGBA pixels (4 bytes per pixel, `stride` bytes per
// row), leaving alpha untouched and fully transparent pixels alone. `amount` is Photoshop's
// percentage: uniform noise spans ±amount% of half the range, Gaussian noise has a standard
// deviation of two thirds of that. Monochromatic adds the same value to all three channels.
// Each pixel's noise depends only on its position and `seed`, so the same seed gives the same grain.
void noise_add(uint8_t *rgba, size_t width, size_t height, size_t stride,
               float amount, int gaussian, int monochromatic, uint32_t seed);
void noise_add_at(uint8_t *rgba, size_t width, size_t height, size_t stride,
                  float amount, int gaussian, int monochromatic, uint32_t seed,
                  int64_t origin_x, int64_t origin_y);
// Fills premultiplied RGBA pixels with fractal value-noise clouds, in gray, opaque. `scale` is the
// size of the largest cloud in pixels and `detail` 0–100 the number of finer octaves below it; the
// same seed gives the same clouds.
void noise_clouds(uint8_t *rgba, size_t width, size_t height, size_t stride,
                  float scale, float detail, uint32_t seed);
#endif
