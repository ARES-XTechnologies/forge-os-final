/*
 * FORGE OS — forge-pointer: lets the controller drive mouse-and-keyboard apps
 * (Heroic, Firefox, anything added as an App) through a virtual mouse + keyboard.
 *
 * It creates one virtual input device with /dev/uinput (the same way Steam Input does), so
 * Gamescope sees a real mouse and keyboard and delivers them to whatever app is in front.
 * The FORGE UI reads the controller and sends simple commands on stdin, one per line:
 *
 *   m <dx> <dy>        move the pointer by dx, dy pixels
 *   d <l|r|m>          press a mouse button        u <l|r|m>   release it
 *   s <n>              scroll n notches (positive = down)
 *   h <n>              scroll sideways n notches
 *   t <text>           type text (US layout: letters, digits, punctuation, space)
 *   k <name>           tap a key: enter backspace tab esc up down left right home end
 *                      pageup pagedown f5 f11 space delete
 *   c <name>           tap a key with Ctrl held (e.g. "c l" = Ctrl+L, address bar)
 *   a <name>           tap a key with Alt held  (e.g. "a left" = browser Back)
 *   q                  quit
 *
 * Build: gcc -O2 -o forge-pointer forge-pointer.c   (no libraries needed)
 */
#include <linux/uinput.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <ctype.h>

static int fd = -1;

static void emit(int type, int code, int val) {
	struct input_event ie;
	memset(&ie, 0, sizeof(ie));
	ie.type = type;
	ie.code = code;
	ie.value = val;
	if (write(fd, &ie, sizeof(ie)) < 0) { /* ignore */ }
}
static void syn(void) { emit(EV_SYN, SYN_REPORT, 0); }
static void tap(int key, int mod) {
	if (mod) { emit(EV_KEY, mod, 1); syn(); }
	emit(EV_KEY, key, 1); syn();
	emit(EV_KEY, key, 0); syn();
	if (mod) { emit(EV_KEY, mod, 0); syn(); }
	usleep(4000);
}

/* US layout: character -> key code, *shift = needs Shift */
static int char_key(int c, int *shift) {
	static const char *row_lower = "abcdefghijklmnopqrstuvwxyz";
	static const int letters[26] = {KEY_A,KEY_B,KEY_C,KEY_D,KEY_E,KEY_F,KEY_G,KEY_H,KEY_I,KEY_J,KEY_K,KEY_L,KEY_M,
		KEY_N,KEY_O,KEY_P,KEY_Q,KEY_R,KEY_S,KEY_T,KEY_U,KEY_V,KEY_W,KEY_X,KEY_Y,KEY_Z};
	static const int digits[10] = {KEY_0,KEY_1,KEY_2,KEY_3,KEY_4,KEY_5,KEY_6,KEY_7,KEY_8,KEY_9};
	*shift = 0;
	if (c >= 'a' && c <= 'z') return letters[strchr(row_lower, c) - row_lower];
	if (c >= 'A' && c <= 'Z') { *shift = 1; return letters[c - 'A']; }
	if (c >= '0' && c <= '9') return digits[c - '0'];
	switch (c) {
	case ' ': return KEY_SPACE;      case '\n': return KEY_ENTER;    case '\t': return KEY_TAB;
	case '-': return KEY_MINUS;      case '_': *shift = 1; return KEY_MINUS;
	case '=': return KEY_EQUAL;      case '+': *shift = 1; return KEY_EQUAL;
	case '[': return KEY_LEFTBRACE;  case '{': *shift = 1; return KEY_LEFTBRACE;
	case ']': return KEY_RIGHTBRACE; case '}': *shift = 1; return KEY_RIGHTBRACE;
	case ';': return KEY_SEMICOLON;  case ':': *shift = 1; return KEY_SEMICOLON;
	case '\'': return KEY_APOSTROPHE; case '"': *shift = 1; return KEY_APOSTROPHE;
	case '`': return KEY_GRAVE;      case '~': *shift = 1; return KEY_GRAVE;
	case '\\': return KEY_BACKSLASH; case '|': *shift = 1; return KEY_BACKSLASH;
	case ',': return KEY_COMMA;      case '<': *shift = 1; return KEY_COMMA;
	case '.': return KEY_DOT;        case '>': *shift = 1; return KEY_DOT;
	case '/': return KEY_SLASH;      case '?': *shift = 1; return KEY_SLASH;
	case '!': *shift = 1; return KEY_1; case '@': *shift = 1; return KEY_2;
	case '#': *shift = 1; return KEY_3; case '$': *shift = 1; return KEY_4;
	case '%': *shift = 1; return KEY_5; case '^': *shift = 1; return KEY_6;
	case '&': *shift = 1; return KEY_7; case '*': *shift = 1; return KEY_8;
	case '(': *shift = 1; return KEY_9; case ')': *shift = 1; return KEY_0;
	}
	return -1;
}

static int named_key(const char *n) {
	struct { const char *name; int key; } t[] = {
		{"enter", KEY_ENTER}, {"backspace", KEY_BACKSPACE}, {"tab", KEY_TAB}, {"esc", KEY_ESC},
		{"up", KEY_UP}, {"down", KEY_DOWN}, {"left", KEY_LEFT}, {"right", KEY_RIGHT},
		{"home", KEY_HOME}, {"end", KEY_END}, {"pageup", KEY_PAGEUP}, {"pagedown", KEY_PAGEDOWN},
		{"f5", KEY_F5}, {"f11", KEY_F11}, {"space", KEY_SPACE}, {"delete", KEY_DELETE},
		{"l", KEY_L}, {"t", KEY_T}, {"w", KEY_W}, {"r", KEY_R}, {"a", KEY_A}, {"c", KEY_C}, {"v", KEY_V},
		{NULL, 0}};
	for (int i = 0; t[i].name; i++)
		if (strcmp(n, t[i].name) == 0) return t[i].key;
	return -1;
}

static int button(const char *b) {
	if (b[0] == 'r') return BTN_RIGHT;
	if (b[0] == 'm') return BTN_MIDDLE;
	return BTN_LEFT;
}

int main(void) {
	fd = open("/dev/uinput", O_WRONLY | O_NONBLOCK);
	if (fd < 0) { perror("forge-pointer: /dev/uinput"); return 1; }
	ioctl(fd, UI_SET_EVBIT, EV_KEY);
	ioctl(fd, UI_SET_EVBIT, EV_REL);
	ioctl(fd, UI_SET_EVBIT, EV_SYN);
	ioctl(fd, UI_SET_RELBIT, REL_X);
	ioctl(fd, UI_SET_RELBIT, REL_Y);
	ioctl(fd, UI_SET_RELBIT, REL_WHEEL);
	ioctl(fd, UI_SET_RELBIT, REL_HWHEEL);
	ioctl(fd, UI_SET_KEYBIT, BTN_LEFT);
	ioctl(fd, UI_SET_KEYBIT, BTN_RIGHT);
	ioctl(fd, UI_SET_KEYBIT, BTN_MIDDLE);
	for (int k = 1; k < 249; k++) ioctl(fd, UI_SET_KEYBIT, k);

	struct uinput_setup us;
	memset(&us, 0, sizeof(us));
	us.id.bustype = BUS_VIRTUAL;
	us.id.vendor = 0xf0f0;
	us.id.product = 0x0001;
	strcpy(us.name, "FORGE controller pointer");
	if (ioctl(fd, UI_DEV_SETUP, &us) < 0 || ioctl(fd, UI_DEV_CREATE) < 0) {
		perror("forge-pointer: create device");
		return 1;
	}
	setvbuf(stdin, NULL, _IOLBF, 0);

	char line[4096];
	while (fgets(line, sizeof(line), stdin)) {
		size_t n = strlen(line);
		while (n && (line[n - 1] == '\n' || line[n - 1] == '\r')) line[--n] = 0;
		if (n == 0) continue;
		char cmd = line[0];
		const char *arg = n > 2 ? line + 2 : "";
		if (cmd == 'q') break;
		if (cmd == 'm') {
			int dx = 0, dy = 0;
			if (sscanf(arg, "%d %d", &dx, &dy) == 2) {
				if (dx) emit(EV_REL, REL_X, dx);
				if (dy) emit(EV_REL, REL_Y, dy);
				syn();
			}
		} else if (cmd == 'd' || cmd == 'u') {
			emit(EV_KEY, button(arg), cmd == 'd'); syn();
		} else if (cmd == 's' || cmd == 'h') {
			int v = atoi(arg);
			/* positive = down / right; the wheel axis is the other way round */
			emit(EV_REL, cmd == 's' ? REL_WHEEL : REL_HWHEEL, cmd == 's' ? -v : v); syn();
		} else if (cmd == 't') {
			for (const char *p = arg; *p; p++) {
				int sh, k = char_key((unsigned char)*p, &sh);
				if (k >= 0) tap(k, sh ? KEY_LEFTSHIFT : 0);
			}
		} else if (cmd == 'k' || cmd == 'c' || cmd == 'a') {
			int k = named_key(arg);
			if (k >= 0) tap(k, cmd == 'c' ? KEY_LEFTCTRL : cmd == 'a' ? KEY_LEFTALT : 0);
		}
	}
	ioctl(fd, UI_DEV_DESTROY);
	close(fd);
	return 0;
}
