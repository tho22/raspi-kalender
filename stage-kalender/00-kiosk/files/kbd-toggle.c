#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/mman.h>
#include <wayland-client.h>
#include "wlr-layer-shell-unstable-v1-client-protocol.h"

#define BTN_SIZE 42

static struct wl_display *display;
static struct wl_compositor *compositor;
static struct wl_shm *shm;
static struct zwlr_layer_shell_v1 *layer_shell;
static struct wl_seat *seat;
static struct wl_output *output;

static struct wl_surface *surface;
static struct zwlr_layer_surface_v1 *layer_surface;
static struct wl_pointer *pointer;
static struct wl_touch *touch;

static void
toggle_keyboard(void)
{
	system("pkill -RTMIN -x wvkbd-mobintl");
}

static void
draw_button(void)
{
	int width = BTN_SIZE, height = BTN_SIZE;
	int stride = width * 4;
	int size = stride * height;
	char name[] = "/tmp/kbdtoggle-XXXXXX";
	int fd = mkstemp(name);
	unlink(name);
	if (ftruncate(fd, size) != 0) {
		close(fd);
		return;
	}
	uint32_t *pixels = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);

	/* simple keyboard glyph: blue rounded-ish square with a grid of "keys" */
	for (int y = 0; y < height; y++) {
		for (int x = 0; x < width; x++) {
			int border = (x < 2 || y < 2 || x >= width - 2 || y >= height - 2);
			uint32_t color = 0xFF2D6CDF;
			if (border) {
				color = 0xFFFFFFFF;
			} else {
				int kx = (x - 6) % 9;
				int ky = (y - 6) % 9;
				if (x > 5 && x < width - 5 && y > 5 && y < height - 5 &&
				    kx < 6 && ky < 6) {
					color = 0xFF6E96EA;
				}
			}
			pixels[y * width + x] = color;
		}
	}

	struct wl_shm_pool *pool = wl_shm_create_pool(shm, fd, size);
	struct wl_buffer *buffer =
	    wl_shm_pool_create_buffer(pool, 0, width, height, stride, WL_SHM_FORMAT_ARGB8888);
	wl_shm_pool_destroy(pool);
	close(fd);
	munmap(pixels, size);

	wl_surface_attach(surface, buffer, 0, 0);
	wl_surface_damage_buffer(surface, 0, 0, width, height);
	wl_surface_commit(surface);
}

static void
pointer_enter(void *d, struct wl_pointer *p, uint32_t s, struct wl_surface *surf,
              wl_fixed_t x, wl_fixed_t y)
{
	(void)d; (void)p; (void)s; (void)surf; (void)x; (void)y;
}
static void
pointer_leave(void *d, struct wl_pointer *p, uint32_t s, struct wl_surface *surf)
{
	(void)d; (void)p; (void)s; (void)surf;
}
static void
pointer_motion(void *d, struct wl_pointer *p, uint32_t t, wl_fixed_t x, wl_fixed_t y)
{
	(void)d; (void)p; (void)t; (void)x; (void)y;
}
static void
pointer_button(void *d, struct wl_pointer *p, uint32_t s, uint32_t t, uint32_t button,
               uint32_t state)
{
	(void)d; (void)p; (void)s; (void)t; (void)button;
	if (state == WL_POINTER_BUTTON_STATE_PRESSED)
		toggle_keyboard();
}
static void
pointer_axis(void *d, struct wl_pointer *p, uint32_t t, uint32_t axis, wl_fixed_t v)
{
	(void)d; (void)p; (void)t; (void)axis; (void)v;
}
static const struct wl_pointer_listener pointer_listener = {
    .enter = pointer_enter,
    .leave = pointer_leave,
    .motion = pointer_motion,
    .button = pointer_button,
    .axis = pointer_axis,
};

static void
touch_down(void *d, struct wl_touch *t, uint32_t serial, uint32_t time,
           struct wl_surface *surf, int32_t id, wl_fixed_t x, wl_fixed_t y)
{
	(void)d; (void)t; (void)serial; (void)time; (void)surf; (void)id; (void)x; (void)y;
	toggle_keyboard();
}
static void
touch_up(void *d, struct wl_touch *t, uint32_t serial, uint32_t time, int32_t id)
{
	(void)d; (void)t; (void)serial; (void)time; (void)id;
}
static void
touch_motion(void *d, struct wl_touch *t, uint32_t time, int32_t id, wl_fixed_t x, wl_fixed_t y)
{
	(void)d; (void)t; (void)time; (void)id; (void)x; (void)y;
}
static void
touch_frame(void *d, struct wl_touch *t)
{
	(void)d; (void)t;
}
static void
touch_cancel(void *d, struct wl_touch *t)
{
	(void)d; (void)t;
}
static const struct wl_touch_listener touch_listener = {
    .down = touch_down,
    .up = touch_up,
    .motion = touch_motion,
    .frame = touch_frame,
    .cancel = touch_cancel,
};

static void
seat_capabilities(void *data, struct wl_seat *s, uint32_t caps)
{
	(void)data;
	if ((caps & WL_SEAT_CAPABILITY_POINTER) && !pointer) {
		pointer = wl_seat_get_pointer(s);
		wl_pointer_add_listener(pointer, &pointer_listener, NULL);
	}
	if ((caps & WL_SEAT_CAPABILITY_TOUCH) && !touch) {
		touch = wl_seat_get_touch(s);
		wl_touch_add_listener(touch, &touch_listener, NULL);
	}
}
static void
seat_name(void *data, struct wl_seat *s, const char *name)
{
	(void)data; (void)s; (void)name;
}
static const struct wl_seat_listener seat_listener = {
    .capabilities = seat_capabilities,
    .name = seat_name,
};

static void
registry_global(void *data, struct wl_registry *r, uint32_t name, const char *interface,
                uint32_t version)
{
	(void)data; (void)version;
	if (strcmp(interface, wl_compositor_interface.name) == 0) {
		compositor = wl_registry_bind(r, name, &wl_compositor_interface, 4);
	} else if (strcmp(interface, wl_shm_interface.name) == 0) {
		shm = wl_registry_bind(r, name, &wl_shm_interface, 1);
	} else if (strcmp(interface, zwlr_layer_shell_v1_interface.name) == 0) {
		layer_shell = wl_registry_bind(r, name, &zwlr_layer_shell_v1_interface, 1);
	} else if (strcmp(interface, wl_seat_interface.name) == 0) {
		seat = wl_registry_bind(r, name, &wl_seat_interface, 5);
		wl_seat_add_listener(seat, &seat_listener, NULL);
	} else if (strcmp(interface, wl_output_interface.name) == 0 && !output) {
		output = wl_registry_bind(r, name, &wl_output_interface, 1);
	}
}
static void
registry_global_remove(void *data, struct wl_registry *r, uint32_t name)
{
	(void)data; (void)r; (void)name;
}
static const struct wl_registry_listener registry_listener = {
    .global = registry_global,
    .global_remove = registry_global_remove,
};

static void
layer_surface_configure(void *data, struct zwlr_layer_surface_v1 *ls, uint32_t serial,
                         uint32_t w, uint32_t h)
{
	(void)data; (void)w; (void)h;
	zwlr_layer_surface_v1_ack_configure(ls, serial);
	draw_button();
}
static void
layer_surface_closed(void *data, struct zwlr_layer_surface_v1 *ls)
{
	(void)data; (void)ls;
	exit(0);
}
static const struct zwlr_layer_surface_v1_listener layer_surface_listener = {
    .configure = layer_surface_configure,
    .closed = layer_surface_closed,
};

int
main(void)
{
	display = wl_display_connect(NULL);
	if (!display) {
		fprintf(stderr, "kbd-toggle: no wayland display\n");
		return 1;
	}
	struct wl_registry *registry = wl_display_get_registry(display);
	wl_registry_add_listener(registry, &registry_listener, NULL);
	wl_display_roundtrip(display);
	wl_display_roundtrip(display);

	if (!compositor || !shm || !layer_shell) {
		fprintf(stderr, "kbd-toggle: missing required wayland globals\n");
		return 1;
	}

	surface = wl_compositor_create_surface(compositor);
	layer_surface = zwlr_layer_shell_v1_get_layer_surface(
	    layer_shell, surface, output, ZWLR_LAYER_SHELL_V1_LAYER_OVERLAY, "kbd-toggle");
	zwlr_layer_surface_v1_set_size(layer_surface, BTN_SIZE, BTN_SIZE);
	zwlr_layer_surface_v1_set_anchor(
	    layer_surface, ZWLR_LAYER_SURFACE_V1_ANCHOR_TOP | ZWLR_LAYER_SURFACE_V1_ANCHOR_RIGHT);
	zwlr_layer_surface_v1_set_margin(layer_surface, 12, 12, 0, 0);
	zwlr_layer_surface_v1_set_keyboard_interactivity(layer_surface, 0);
	zwlr_layer_surface_v1_add_listener(layer_surface, &layer_surface_listener, NULL);
	wl_surface_commit(surface);

	while (wl_display_dispatch(display) != -1) {
	}

	return 0;
}
