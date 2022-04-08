#include <inttypes.h>

typedef enum {
	TByte
} capmix_type_t;
typedef uint32_t capmix_addr_t; ///< 32-bit value holding a four-byte device address

typedef struct capmix_memory_area_s {
	capmix_addr_t offset;   ///< device memory address offset of current area
	capmix_type_t kind;     ///< type of value stored at this address
	int low, high;
	void *values;
	const char *const name; ///< name of this area of memory
	const struct capmix_memory_area_s **const area; ///< areas of memory contained within this area
} capmix_mem_t;

