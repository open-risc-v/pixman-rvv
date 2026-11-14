/* OVER 合成吞吐基准：真机上跑 A（RVV 内核）/ B（标量）各一次，取中位数。
   qemu 下只能验证能跑通，数字不作性能结论。 */
#include <pixman.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#define W 1024
#define H 1024

static double now_ns(void)
{
	struct timespec ts;
	clock_gettime(CLOCK_MONOTONIC, &ts);
	return (double)ts.tv_sec * 1e9 + (double)ts.tv_nsec;
}

int main(int argc, char **argv)
{
	int reps = argc > 1 ? atoi(argv[1]) : 5;
	uint32_t *dst = calloc((size_t)W * H, 4);
	uint32_t *src = malloc((size_t)W * H * 4);
	if (!dst || !src) return 2;
	for (size_t i = 0; i < (size_t)W * H; i++)
		src[i] = (uint32_t)(0x60000000u | (uint32_t)((i * 2654435761u) & 0x00ffffffu));

	pixman_image_t *d = pixman_image_create_bits(PIXMAN_a8r8g8b8, W, H, dst, W * 4);
	pixman_image_t *s = pixman_image_create_bits(PIXMAN_a8r8g8b8, W, H, src, W * 4);

	double best = 1e30;
	for (int r = 0; r < reps; r++) {
		double t0 = now_ns();
		pixman_image_composite32(PIXMAN_OP_OVER, s, NULL, d, 0, 0, 0, 0, 0, 0, W, H);
		double dt = now_ns() - t0;
		if (dt < best) best = dt;
	}
	double px = (double)W * H;
	printf("over %dx%d best_ns=%.0f ns_per_px=%.3f mpx_s=%.1f\n",
	       W, H, best, best / px, px / best * 1e3);

	pixman_image_unref(s);
	pixman_image_unref(d);
	free(src);
	free(dst);
	return 0;
}
