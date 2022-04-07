#include <stdio.h>
#include <inttypes.h>

typedef enum {
	None
} capmix_type_t;
typedef uint32_t capmix_addr_t; ///< 32-bit value holding a four-byte device address

typedef struct capmix_memory_area_s {
	capmix_addr_t offset;   ///< device memory address offset of current area
	capmix_type_t type;     ///< type of value stored at this address
	const char *const name; ///< name of this area of memory
	const struct capmix_memory_area_s **const area; ///< areas of memory contained within this area
} capmix_mem_t;

static const capmix_mem_t const *my_area[] = {
	&(const capmix_mem_t){.offset = 0, .name = "first", .area = (const capmix_mem_t*[]){
		&(const capmix_mem_t){.offset=1, .name="second"},
		&(const capmix_mem_t){ .offset=-1 }
	}},
	&(const capmix_mem_t){ .offset=-1 }
};

int main(char **args, int argv)
{
	const capmix_mem_t *area1 = my_area[0];
	const capmix_mem_t *area2 = area1->area[0];
	printf("%s %s %d\n", area1->name, area2->name, area1->area[1]->offset);
}
