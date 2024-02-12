#include "hardware.h"
#include "video_bios.h"
#define VGSLICE      (10000)

	uint16_t m_pc;
	uint8_t m_sp;
	uint16_t m_dvx;
	uint16_t m_dvy;
	uint16_t m_stack[4];
	uint8_t m_stack_index;
	uint16_t m_data;
	uint8_t m_bin_scale;
	uint8_t m_state_latch;
	uint8_t m_scale;
	uint8_t m_intensity;
	uint32_t cycles;
	uint16_t color_mux;
	uint8_t m_halt;
	uint8_t m_op;

	int16_t m_xpos_old;
	int16_t m_ypos_old;
	int16_t m_xpos;
	int16_t m_ypos;
	int m_xmax, m_ymax;

	uint8_t m_dvy12;
	uint8_t m_dvx12;
	uint16_t m_timer;

	uint8_t m_int_latch;
	uint8_t m_color;

	uint16_t m_xdac_xor;
	uint16_t m_ydac_xor;

    int16_t m_xmin, m_ymin;
	int16_t m_xcenter, m_ycenter;

void clearpixel(){
	uint32_t i = 0;
	for(i=0;i<(720*721);i++){
		write_half((i<<1 & 0xFFFFFFFE) | 0x10000000) = 0x0000;
		// mainprintf("tmp_address: %0.8x \r\n", i);
	}
	
}

void set_color (int8_t color){
	switch (color){
		case 0 : color_mux = 0x0000; break;
		case 1 : color_mux = 0x001f; break;
		case 2 : color_mux = 0x07E0; break;
		case 3 : color_mux = 0x07ff; break;
		case 4 : color_mux = 0xf800; break;
		case 5 : color_mux = 0xf81f; break;
		case 6 : color_mux = 0xFFE0; break;
		case 7 : color_mux = 0xffff; break;
	}
}

void putpixel(int x, int y){
	uint32_t tmp = 0;
	uint32_t tmp_address = 0;
	

	tmp_address = ((y * 720) + x) << 1;
	tmp_address = (tmp_address & 0xFFFFFFFE) | 0x10000000;
	
	// Wait for being able to write to pixel fifo
	
	// mainprintf("tmp_address: %0.8x xpos: %d ypos: %d color %d \r\n", tmp_address, x, y, color_mux);
	write_half(tmp_address) = color_mux;
}

void drawline(int x2, int y2, int x1, int y1)
{
	if (m_color) {
		mainprintf("Main Core x2: %0.8x y2: %0.8x x1: %0.8x y1: %0.8x\r\n", x2, y2, x1, y1);
		int x,y,dx,dy,dx1,dy1,px,py,xe,ye,i;
		m_xpos_old = x2;
		m_ypos_old = y2;
		int16_t tmp_x2 = (x2 * 45) >> 6;
		int16_t tmp_y2 = (y2 * 45) >> 6;

		int16_t tmp_x1 = (x1 * 45) >> 6;
		int16_t tmp_y1 = (y1 * 45) >> 6;

		dx=tmp_x2-tmp_x1;
		dy=tmp_y2-tmp_y1;
		dx1=abs(dx);
		dy1=abs(dy);
		px=2*dy1-dx1;
		py=2*dx1-dy1;

		if(dy1<=dx1) {
		if(dx>=0) {
		x=tmp_x1;
		y=tmp_y1;
		xe=tmp_x2;
		} else {
		x=tmp_x2;
		y=tmp_y2;
		xe=tmp_x1;
		}
		putpixel(x,y);
		for(i=0;x<xe;i++) {
		x=x+1;
		if(px<0) {
		px=px+2*dy1;
		} else {
		if((dx<0 && dy<0) || (dx>0 && dy>0)) {
		y=y+1;
		} else {
		y=y-1;
		}
		px=px+2*(dy1-dx1);
		}
		putpixel(x,y);
		}
		} else {
		if(dy>=0) {
		x=tmp_x1;
		y=tmp_y1;
		ye=tmp_y2;
		} else {
		x=tmp_x2;
		y=tmp_y2;
		ye=tmp_y1;
		}
		putpixel(x,y);
		for(i=0;y<ye;i++) {
		y=y+1;
		if(py<=0) {
		py=py+2*dx1;
		} else {
		if((dx<0 && dy<0) || (dx>0 && dy>0)) {
		x=x+1;
		} else {
		x=x-1;
		}
		py=py+2*(dx1-dy1);
		}
		putpixel(x,y);
		}
		}
	}
}

void vggo() // avg_vggo
{
	m_pc = 0;
	m_sp = 0;
}

void vgrst() // avg_vgrst
{
	m_state_latch = 0;
	m_scale = 0;
	m_color = 0;
	m_stack_index = 0;
	m_bin_scale = 0;
}


uint8_t OP0() { return (m_op & 1); }
uint8_t OP1() { return (m_op >> 1)& 1; }
uint8_t OP2() { return (m_op >> 2)& 1; }
uint8_t OP3() { return (m_op >> 3)& 1; }
uint8_t ST3() { return (m_state_latch >> 3) & 1; }

int handler_0() // avg_latch0
{
	m_dvy = (m_dvy & 0x1f00) | m_data;
	m_pc++;

	return 0;
}

int handler_1() // avg_latch1
{
	m_dvy12 = (m_data >> 4) & 1;
	m_op = m_data >> 5;

	m_int_latch = 0;
	m_dvy = (m_dvy12 << 12) | ((m_data & 0xf) << 8);
	m_dvx = 0;
	m_pc++;

	return 0;
}

int handler_2() // avg_latch2
{
	m_dvx = (m_dvx & 0x1f00) | m_data;
	m_pc++;

	return 0;
}

int handler_3() // avg_latch3
{
	m_int_latch = m_data >> 4;
	m_dvx = ((m_int_latch & 1) << 12)
			| ((m_data & 0xf) << 8)
			| (m_dvx & 0xff);

	m_pc++;

	return 0;
}

int handler_4() // avg_strobe0
{
	if (OP0())
	{
		m_stack[m_sp & 3] = m_pc;
	}
	else
	{
		/*
		 * Normalization is done to get roughly constant deflection
		 * speeds. See Jed's essay why this is important. In addition
		 * to the intensity and overall time saving issues it is also
		 * needed to avoid accumulation of DAC errors. The X/Y DACs
		 * only use bits 3-12. The normalization ensures that the
		 * first three bits hold no important information.
		 *
		 * The circuit doesn't check for dvx=dvy=0. In this case
		 * shifting goes on as long as VCTR, SCALE and CNTR are
		 * low. We cut off after 16 shifts.
		 */
		int i = 0;
		while ((((m_dvy ^ (m_dvy << 1)) & 0x1000) == 0)
				&& (((m_dvx ^ (m_dvx << 1)) & 0x1000) == 0)
				&& (i++ < 16))
		{
			m_dvy = (m_dvy & 0x1000) | ((m_dvy << 1) & 0x1fff);
			m_dvx = (m_dvx & 0x1000) | ((m_dvx << 1) & 0x1fff);
			m_timer >>= 1;
			m_timer |= 0x4000 | (OP1() << 7);
		}
		if (OP1())
			m_timer &= 0xff;
	}

	return 0;
}

int avg_common_strobe1()
{
	if (OP2())
	{
		if (OP1())
			m_sp = (m_sp - 1) & 0xf;
		else
			m_sp = (m_sp + 1) & 0xf;
	}
	return 0;
}

int handler_5() // avg_strobe1
{
	if (!OP2())
	{
		for (int i = m_bin_scale; i > 0; i--)
		{
			m_timer >>= 1;
			m_timer |= 0x4000 | (OP1() << 7);
		}
		if (OP1())
			m_timer &= 0xff;
	}
	return avg_common_strobe1();
}


int avg_common_strobe2()
{
	if (OP2())
	{
		if (OP0())
		{
			m_pc = m_dvy << 1;

			if (m_dvy == 0)
			{
				/*
				 * Tempest and Quantum keep the AVG in an endless
				 * loop. I.e. at one point the AVG jumps to address 0
				 * and starts over again. The main CPU updates vector
				 * RAM while AVG is running. The hardware takes care
				 * that the AVG doesn't read vector RAM while the CPU
				 * writes to it. Usually we wait until the AVG stops
				 * (halt flag) and then draw all vectors at once. This
				 * doesn't work for Tempest and Quantum so we wait for
				 * the jump to zero and draw vectors then.
				 *
				 * Note that this has nothing to do with the real hardware
				 * because for a vector monitor it is perfectly okay to
				 * have the AVG drawing all the time. In the emulation we
				 * somehow have to divide the stream of vectors into
				 * 'frames'.
				 */

				// m_vector->clear_list();
				// vg_flush();
			}
		}
		else
		{
			m_pc = m_stack[m_sp & 3];
		}
	}
	else
	{
		if (m_dvy12)
		{
			m_scale = m_dvy & 0xff;
			m_bin_scale = (m_dvy >> 8) & 7;
		}
	}

	return 0;
}

void update_databus() // starwars_data
{
	m_data = vram_test[m_pc];
}

int avg_common_strobe3()
{

	m_halt = OP0();

	if (!OP0() && !OP2())
	{
		mainprintf("Paint m_dvx: %d m_dvy: %0.4x m_scale: %d \r\n", m_dvx, m_dvy, m_scale);
		if (OP1())
		{
			cycles = 0x100 - (m_timer & 0xff);
		}
		else
		{
			cycles = 0x8000 - m_timer;
		}
		m_timer = 0;

		m_xpos += ((((m_dvx >> 3) ^ m_xdac_xor) - 0x200) * cycles * (m_scale ^ 0xff)) >> 4;
		m_ypos -= ((((m_dvy >> 3) ^ m_ydac_xor) - 0x200) * cycles * (m_scale ^ 0xff)) >> 4;
	}

	if (OP2())
	{
		m_xpos = m_xcenter;
		m_ypos = m_ycenter;
		drawline(m_xcenter, m_ycenter, m_xpos, m_ypos);
	}

	return 1;
}

int handler_6() // starwars_strobe2
{
	if (!OP2() && !m_dvy12)
	{
		m_intensity = m_dvy & 0xff;
		m_color = (m_dvy >> 8) & 0xf;
		switch (m_color){
			case 0 : color_mux = 0x0000; break;
			case 1 : color_mux = 0x001f; break;
			case 2 : color_mux = 0x07E0; break;
			case 3 : color_mux = 0x07ff; break;
			case 4 : color_mux = 0xf800; break;
			case 5 : color_mux = 0xf81f; break;
			case 6 : color_mux = 0xFFE0; break;
			case 7 : color_mux = 0xffff; break;
		}
	}

	return avg_common_strobe2();
}

int handler_7() // starwars_strobe3
{
	const int cycles = avg_common_strobe3();

	if (!OP0() && !OP2())
	{
		drawline(m_xpos, m_ypos, m_xpos_old, m_ypos_old);
	}

	return cycles;
}


void vg_set_halt(int dummy)
{
	m_halt = dummy;
	m_pc = 0;
	m_dvx = 0;
	m_dvy = 0;
	m_stack[0] = 0;
	m_stack[1] = 0;
	m_stack[2] = 0;
	m_stack[3] = 0;
	m_data = 0;
	m_stack_index = 0;
	m_scale = 0;
	m_intensity = 0;
	m_op = 0;
	m_xpos = 512;
	m_ypos = 512;
	m_xcenter = 512; 
	m_ycenter = 512;
	m_color = 0;	
	m_xdac_xor = 0x200;
	m_ydac_xor = 0x200;
}

uint8_t state_addr() // avg_state_addr
{
	return (((m_state_latch >> 4) ^ 1) << 7)
			| (m_op << 4)
			| (m_state_latch & 0xf);
}

void video_start (){
	
	int cycles = 0;
	m_halt = 0;

	while (!m_halt)
	{
		// Get next state
		m_state_latch = (m_state_latch & 0x10) | (m_prom[state_addr()] & 0xf);

		if (ST3())
		{
			// Read vector RAM/ROM
			update_databus();

			// Decode state and call the corresponding handler
			switch (m_state_latch & 7)
			{
			case 0 : cycles += handler_0(); break;
			case 1 : cycles += handler_1(); break;
			case 2 : cycles += handler_2(); break;
			case 3 : cycles += handler_3(); break;
			case 4 : cycles += handler_4(); break;
			case 5 : cycles += handler_5(); break;
			case 6 : cycles += handler_6(); break;
			case 7 : cycles += handler_7(); break;
			}
		}
		mainprintf("Main Core m_op: %d m_pc: %0.4x m_data: %0.4x m_halt: %d \r\n", m_op, m_pc, m_data, m_halt);
		// If halt flag was set, let CPU catch up before we make halt visible
		// if (m_halt && !(m_state_latch & 0x10)) break;
		m_state_latch = (m_halt << 4) | (m_state_latch & 0xf);
		cycles += 8;
	}

	// do
	// {
	// 	m_op = (vram_test[m_pc] >> 5) & 0x7;
	// 	m_data = vram_test[m_pc];
		
	// 	mainprintf("Main Core m_op: %d m_data: %0.4x m_halt: %d \r\n", m_op, m_data, m_halt);
	// 	switch (m_op & 0x7){
	// 		case 0 : v_vctr();
	// 		case 1 : vg_set_halt(1);
	// 		case 2 : v_sec();
	// 		case 3 : v_color_scal();
	// 		case 4 : v_center();
	// 		case 5 : v_jsrl();
	// 		case 6 : v_rtsl();
	// 		case 7 : v_jmpl();
	// 	}
	// 	if (m_pc == 0) {
	// 		vg_set_halt(1);
			
	// 		mainprintf("I broke  \r\n");
	// 		break;
	// 	}
		
	// 	mainprintf("Main Core m_op: %d m_data: %0.4x m_halt: %d \r\n", m_op, m_data, m_halt);
	// } while (!m_halt);
	

			mainprintf("done \r\n");
};