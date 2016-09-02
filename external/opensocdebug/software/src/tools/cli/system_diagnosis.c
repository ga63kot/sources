/* Copyright (c) 2016 by the author(s)
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 * ============================================================================
 *
 * Author(s):
 *   Stefan Wallentowitz <stefan@wallentowitz.de>
 */

#include "cli.h"

#include <assert.h>

int write_configreg(struct osd_context *ctx) {
    // Get list of memories
    uint16_t *memories;
    size_t num_memories;
    int success = 1;
    printf("My TEST\n");
    osd_get_memories(ctx, &memories, &num_memories);

    uint16_t temp_read;
    osd_reg_write16(ctx, 3, 0x200, 0x2030);		// First Event LSB
    osd_reg_write16(ctx, 3, 0x201, 0x0000);		// First Event MSB
    osd_reg_write16(ctx, 3, 0x202, 0x8001);		// First Event valid and Event ID 1

    osd_reg_write16(ctx, 3, 0x203, 0xd758);		// Second Event LSB
    osd_reg_write16(ctx, 3, 0x204, 0x0000);		// Second Event MSB
    osd_reg_write16(ctx, 3, 0x205, 0x8002);		// Second Event valid and Event ID 2

    osd_reg_write16(ctx, 3, 0x206, 0xd74c);		// Third Event LSB
    osd_reg_write16(ctx, 3, 0x207, 0x0000);		// Third Event MSB
    osd_reg_write16(ctx, 3, 0x208, 0x8003);		// Third Event valid and Event ID 3
 
    osd_reg_write16(ctx, 3, 0x209, 0xffff);		// Configuration GPR selection vector (LSB)
    osd_reg_write16(ctx, 3, 0x20a, 0x0000);		// Configuration GPR selection vector (MSB)
    osd_reg_write16(ctx, 3, 0x20b, 0x8fc1);		// Configuration First Event valid and Event ID 1

    osd_reg_write16(ctx, 3, 0x20c, 0xffff);		// Configuration Second Event LSB
    osd_reg_write16(ctx, 3, 0x20d, 0x0000);		// Configuration Second Event MSB
    osd_reg_write16(ctx, 3, 0x20e, 0x8fc2);		// Configuration Second Event valid and Event ID 2

    osd_reg_write16(ctx, 3, 0x20f, 0xffff);		// Configuration Third Event LSB
    osd_reg_write16(ctx, 3, 0x210, 0x0000);		// Configuration Third Event MSB
    osd_reg_write16(ctx, 3, 0x211, 0x8fc3);		// Configuration Third Event valid and Event ID 3



    osd_reg_read16(ctx, 3, 0x200, &temp_read);
    
    printf("Currently defined events: %d\n", temp_read);
    return success;
}