// pixman A/B 探针：只用公开 API，走 fill / composite / linear gradient 三条真实路径，
// 把结果哈希后打印，并落一份 PPM。任一像素不同，哈希就不同。
#include <pixman.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#define W 129   // 非 2 的幂，逼出尾部路径
#define H 97

static uint64_t fnv1a(const void *p, size_t n)
{
    const uint8_t *b = p;
    uint64_t h = 1469598103934665603ULL;
    for (size_t i = 0; i < n; i++) { h ^= b[i]; h *= 1099511628211ULL; }
    return h;
}

int main(int argc, char **argv)
{
    const char *ppm = argc > 1 ? argv[1] : NULL;
    uint32_t *dst = calloc((size_t)W * H, 4);
    uint32_t *src = malloc((size_t)W * H * 4);
    if (!dst || !src) return 2;

    for (int y = 0; y < H; y++)
        for (int x = 0; x < W; x++)
            src[(size_t)y * W + x] = (uint32_t)(0x80000000u | ((x * 7 + y) & 0xff) << 16 |
                                                ((y * 13 + x) & 0xff) << 8 | ((x + y * 3) & 0xff));

    pixman_image_t *d = pixman_image_create_bits(PIXMAN_a8r8g8b8, W, H, dst, W * 4);
    pixman_image_t *s = pixman_image_create_bits(PIXMAN_a8r8g8b8, W, H, src, W * 4);

    /* 1. 实心填充（走 fill fast path） */
    pixman_color_t c = { 0x8000, 0x2000, 0x1000, 0xC000 };
    pixman_box32_t box = { 0, 0, W, H };
    pixman_image_fill_boxes(PIXMAN_OP_SRC, d, &c, 1, &box);

    /* 2. 源图 OVER 合成（走 composite fast path / 通用路径） */
    pixman_image_composite32(PIXMAN_OP_OVER, s, NULL, d, 0, 0, 0, 0, 0, 0, W, H);

    /* 3. 线性渐变 OVER，检验定点插值与 alpha 混合 */
    pixman_point_fixed_t p1 = { 0, 0 };
    pixman_point_fixed_t p2 = { pixman_int_to_fixed(W), pixman_int_to_fixed(H) };
    pixman_gradient_stop_t stops[2] = {
        { 0, { 0x0000, 0x0000, 0x0000, 0x8000 } },
        { pixman_int_to_fixed(1), { 0xffff, 0x8000, 0x0000, 0xc000 } },
    };
    pixman_image_t *g = pixman_image_create_linear_gradient(&p1, &p2, stops, 2);
    pixman_image_composite32(PIXMAN_OP_OVER, g, NULL, d, 0, 0, 0, 0, 0, 0, W, H);

    printf("size=%dx%d fnv=%016llx\n", W, H, (unsigned long long)fnv1a(dst, (size_t)W * H * 4));

    if (ppm) {
        FILE *f = fopen(ppm, "wb");
        if (!f) return 3;
        fprintf(f, "P6\n%d %d\n255\n", W, H);
        for (int i = 0; i < W * H; i++) {
            unsigned char px[3] = { (unsigned char)(dst[i] >> 16),
                                    (unsigned char)(dst[i] >> 8),
                                    (unsigned char)dst[i] };
            fwrite(px, 1, 3, f);
        }
        fclose(f);
    }

    pixman_image_unref(g);
    pixman_image_unref(s);
    pixman_image_unref(d);
    free(src);
    free(dst);
    return 0;
}
