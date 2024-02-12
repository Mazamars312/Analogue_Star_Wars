/*
 * Copyright 2022 Murray Aickin
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 */
 // #include <stdint.h>
 // #include <unistd.h>
 // #include <stdio.h>
 // #include <stdlib.h>

// #include "interrupts.h"
#include "hardware.h"
// #include "uart.h"
// #include "apf.h"
// #include "printf.h"
// #include "spi.h"
// #include "core.h"
// #include "osd_menu.h"

bool VGGO = 0; 
bool VGRESET = 0; 
bool VGHALT = 1;

void init()
{
	// this makes the core go in to the reset state and halts the bus so we can upload the bios if required
	// This setups the timers and the CPU clock rate on the system.

	// Setup the core to know what MHZ the CPU is running at.
	//DisableInterrupts();
	SetTimer();
	SetUART();
	ResetTimer();
	riscusleep(500000);
	mainprintf("\033[0m");
	// printf_register(riscputc);
	// This is where you setup the core startup dataslots that the APT loads up for your core.
	// core_interupt_update();
}

void mainloop()
{
	mainprintf("RISC MPU Startup core\r\n");
	mainprintf("Created By Mazamars312\r\n");
	mainprintf("Make in 2023\r\n");
	mainprintf("I hate this debugger LOL\r\n");
	mainprintf("For Star wars\r\n");
	int16_t frame_number = 0;
	timer_printer = 0;
	write_word(0x14000000) = 0xffffffff;
	clearpixel();
	vg_set_halt(0);
	video_start();
	while(true){
		
	}
}

int main()
{

	init();
	riscusleep(2000000); // I want the core to wait a bit.
	mainloop();

	return(0);
}

void irqCallback(){
}
