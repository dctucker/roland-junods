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
static const capmix_mem_t *voice_reserves[] = {
	&(const capmix_mem_t){ .name = "1", .kind = TByte, .low = 0, .high = 64,  }, &(const capmix_mem_t){ .name = "2", .kind = TByte, .low = 0, .high = 64,  }, &(const capmix_mem_t){ .name = "3", .kind = TByte, .low = 0, .high = 64,  }, &(const capmix_mem_t){ .name = "4", .kind = TByte, .low = 0, .high = 64,  }, &(const capmix_mem_t){ .name = "5", .kind = TByte, .low = 0, .high = 64,  }, &(const capmix_mem_t){ .name = "6", .kind = TByte, .low = 0, .high = 64,  }, &(const capmix_mem_t){ .name = "7", .kind = TByte, .low = 0, .high = 64,  }, &(const capmix_mem_t){ .name = "8", .kind = TByte, .low = 0, .high = 64,  }, &(const capmix_mem_t){ .name = "9", .kind = TByte, .low = 0, .high = 64,  }, &(const capmix_mem_t){ .name = "10", .kind = TByte, .low = 0, .high = 64,  }, &(const capmix_mem_t){ .name = "11", .kind = TByte, .low = 0, .high = 64,  }, &(const capmix_mem_t){ .name = "12", .kind = TByte, .low = 0, .high = 64,  }, &(const capmix_mem_t){ .name = "13", .kind = TByte, .low = 0, .high = 64,  }, &(const capmix_mem_t){ .name = "14", .kind = TByte, .low = 0, .high = 64,  }, &(const capmix_mem_t){ .name = "15", .kind = TByte, .low = 0, .high = 64,  }, &(const capmix_mem_t){ .name = "16", .kind = TByte, .low = 0, .high = 64,  }, 
};
static const capmix_mem_t *parameters_20[] = {
	&(const capmix_mem_t){ .name = "1", .kind = TNibbleQuad, .low = 12768, .high = 52768,  }, &(const capmix_mem_t){ .name = "2", .kind = TNibbleQuad, .low = 12768, .high = 52768,  }, &(const capmix_mem_t){ .name = "3", .kind = TNibbleQuad, .low = 12768, .high = 52768,  }, &(const capmix_mem_t){ .name = "4", .kind = TNibbleQuad, .low = 12768, .high = 52768,  }, &(const capmix_mem_t){ .name = "5", .kind = TNibbleQuad, .low = 12768, .high = 52768,  }, &(const capmix_mem_t){ .name = "6", .kind = TNibbleQuad, .low = 12768, .high = 52768,  }, &(const capmix_mem_t){ .name = "7", .kind = TNibbleQuad, .low = 12768, .high = 52768,  }, &(const capmix_mem_t){ .name = "8", .kind = TNibbleQuad, .low = 12768, .high = 52768,  }, &(const capmix_mem_t){ .name = "9", .kind = TNibbleQuad, .low = 12768, .high = 52768,  }, &(const capmix_mem_t){ .name = "10", .kind = TNibbleQuad, .low = 12768, .high = 52768,  }, &(const capmix_mem_t){ .name = "11", .kind = TNibbleQuad, .low = 12768, .high = 52768,  }, &(const capmix_mem_t){ .name = "12", .kind = TNibbleQuad, .low = 12768, .high = 52768,  }, &(const capmix_mem_t){ .name = "13", .kind = TNibbleQuad, .low = 12768, .high = 52768,  }, &(const capmix_mem_t){ .name = "14", .kind = TNibbleQuad, .low = 12768, .high = 52768,  }, &(const capmix_mem_t){ .name = "15", .kind = TNibbleQuad, .low = 12768, .high = 52768,  }, &(const capmix_mem_t){ .name = "16", .kind = TNibbleQuad, .low = 12768, .high = 52768,  }, &(const capmix_mem_t){ .name = "17", .kind = TNibbleQuad, .low = 12768, .high = 52768,  }, &(const capmix_mem_t){ .name = "18", .kind = TNibbleQuad, .low = 12768, .high = 52768,  }, &(const capmix_mem_t){ .name = "19", .kind = TNibbleQuad, .low = 12768, .high = 52768,  }, &(const capmix_mem_t){ .name = "20", .kind = TNibbleQuad, .low = 12768, .high = 52768,  }, 
};
static const capmix_mem_t *midi_n[] = {
	
	&(const capmix_mem_t){.offset = 0x0000000a, .name = "phase_lock", .kind = TBool, },
	&(const capmix_mem_t){.offset = 0x0000000b, .name = "velocity_curve_type", .kind = TByte, .low = 0, .high = 4, },
};
static const capmix_mem_t *midis[] = {
	&(const capmix_mem_t){ .name = "1", .kind = midi_n,  }, &(const capmix_mem_t){ .name = "2", .kind = midi_n,  }, &(const capmix_mem_t){ .name = "3", .kind = midi_n,  }, &(const capmix_mem_t){ .name = "4", .kind = midi_n,  }, &(const capmix_mem_t){ .name = "5", .kind = midi_n,  }, &(const capmix_mem_t){ .name = "6", .kind = midi_n,  }, &(const capmix_mem_t){ .name = "7", .kind = midi_n,  }, &(const capmix_mem_t){ .name = "8", .kind = midi_n,  }, &(const capmix_mem_t){ .name = "9", .kind = midi_n,  }, &(const capmix_mem_t){ .name = "10", .kind = midi_n,  }, &(const capmix_mem_t){ .name = "11", .kind = midi_n,  }, &(const capmix_mem_t){ .name = "12", .kind = midi_n,  }, &(const capmix_mem_t){ .name = "13", .kind = midi_n,  }, &(const capmix_mem_t){ .name = "14", .kind = midi_n,  }, &(const capmix_mem_t){ .name = "15", .kind = midi_n,  }, &(const capmix_mem_t){ .name = "16", .kind = midi_n,  }, 
};