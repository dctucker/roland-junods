#include "cmap.h"

static const capmix_mem_t *scale[] = {
	&(const capmix_mem_t){.offset = 0x00000000, .name = "c", .kind = TByte, .low = 0, .high = 127, },
	&(const capmix_mem_t){.offset = 0x00000001, .name = "c#", .kind = TByte, .low = 0, .high = 127, },
	&(const capmix_mem_t){.offset = 0x00000002, .name = "d", .kind = TByte, .low = 0, .high = 127, },
	&(const capmix_mem_t){.offset = 0x00000003, .name = "d#", .kind = TByte, .low = 0, .high = 127, },
	&(const capmix_mem_t){.offset = 0x00000004, .name = "e", .kind = TByte, .low = 0, .high = 127, },
	&(const capmix_mem_t){.offset = 0x00000005, .name = "f", .kind = TByte, .low = 0, .high = 127, },
	&(const capmix_mem_t){.offset = 0x00000006, .name = "f#", .kind = TByte, .low = 0, .high = 127, },
	&(const capmix_mem_t){.offset = 0x00000007, .name = "g", .kind = TByte, .low = 0, .high = 127, },
	&(const capmix_mem_t){.offset = 0x00000008, .name = "g#", .kind = TByte, .low = 0, .high = 127, },
	&(const capmix_mem_t){.offset = 0x00000009, .name = "a", .kind = TByte, .low = 0, .high = 127, },
	&(const capmix_mem_t){.offset = 0x0000000a, .name = "a#", .kind = TByte, .low = 0, .high = 127, },
	&(const capmix_mem_t){.offset = 0x0000000b, .name = "b", .kind = TByte, .low = 0, .high = 127, },
};