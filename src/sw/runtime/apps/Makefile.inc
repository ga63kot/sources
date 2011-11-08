OR32_PREFIX = or32-elf
OR32_CFLAGS =-std=gnu99 -O2 -Wall -I ../../librts/ -ffixed-r31
OR32_LDFLAGS = 

%.o: %.S
	$(OR32_PREFIX)-gcc $(OR32_CFLAGS) -c $< -o $@

%.o: %.c %.h
	$(OR32_PREFIX)-gcc $(OR32_CFLAGS) -c $< -o $@

%.o: %.c
	$(OR32_PREFIX)-gcc $(OR32_CFLAGS) -c $< -o $@