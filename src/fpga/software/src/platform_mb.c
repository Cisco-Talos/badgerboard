/*
 * Copyright (C) 2010 - 2019 Xilinx, Inc.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 * 3. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT
 * SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
 * OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
 * IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
 * OF SUCH DAMAGE.
 *
 */
/*
 * platform_mb.c
 *
 * MicroBlaze platform specific functions.
 */

#ifdef __MICROBLAZE__

#include "platform.h"
#include "platform_config.h"

#include "mb_interface.h"
#include "BackplaneReader_AXILite.h"

#include "xparameters.h"
#include "xintc.h"
#include "xtmrctr_l.h"

#include "lwip/pbuf.h"
#include "lwip/err.h"
#include "lwip/udp.h"


extern u32 dataBuffer[32];
extern struct netif *send_netif;
extern struct udp_pcb * upcb;

extern struct pbuf *packet;

void
xadapter_timer_handler(void *p)
{
	timer_callback();

	/* Load timer, clear interrupt bit */
	XTmrCtr_SetControlStatusReg(PLATFORM_TIMER_BASEADDR, 0,
			XTC_CSR_INT_OCCURED_MASK
			| XTC_CSR_LOAD_MASK);

	XTmrCtr_SetControlStatusReg(PLATFORM_TIMER_BASEADDR, 0,
			XTC_CSR_ENABLE_TMR_MASK
			| XTC_CSR_ENABLE_INT_MASK
			| XTC_CSR_AUTO_RELOAD_MASK
			| XTC_CSR_DOWN_COUNT_MASK);

	XIntc_AckIntr(XPAR_INTC_0_BASEADDR, PLATFORM_TIMER_INTERRUPT_MASK);
}

#define MHZ (66)
#define TIMER_TLR (25000000*((float)MHZ/100))

void
platform_setup_timer()
{
	/* set the number of cycles the timer counts before interrupting */
	/* 100 Mhz clock => .01us for 1 clk tick. For 100ms, 10000000 clk ticks need to elapse  */
	XTmrCtr_SetLoadReg(PLATFORM_TIMER_BASEADDR, 0, TIMER_TLR);

	/* reset the timers, and clear interrupts */
	XTmrCtr_SetControlStatusReg(PLATFORM_TIMER_BASEADDR, 0, XTC_CSR_INT_OCCURED_MASK | XTC_CSR_LOAD_MASK );

	/* start the timers */
	XTmrCtr_SetControlStatusReg(PLATFORM_TIMER_BASEADDR, 0,
			XTC_CSR_ENABLE_TMR_MASK | XTC_CSR_ENABLE_INT_MASK
			| XTC_CSR_AUTO_RELOAD_MASK | XTC_CSR_DOWN_COUNT_MASK);

	/* Register Timer handler */
	XIntc_RegisterHandler(XPAR_INTC_0_BASEADDR,
			PLATFORM_TIMER_INTERRUPT_INTR,
			(XInterruptHandler)xadapter_timer_handler,
			0);
}

void BackplaneInterruptHandler(void *CallbackRef) {
	// We need to get the size of the buffer so that we can set the pbuf size accurately, this reduces work
	// on the recv end.
	u32 size = BACKPLANEREADER_AXILITE_mReadReg(0x44a00000, 63*4) + 1;
//	printf("Number of Regs : %X\r\n", size);

	if (size == 0) {
		return;
	}

	// We don't want to copy anything, just grab the memory directly where it is, this significantly reduces
	// time to send the packets.
	packet->payload = (void *) 0x44a00000;
	packet->tot_len = size * sizeof(int);
	packet->len = size * sizeof(int);


	// This causes a memory leak because it is "slow" and can be interrupted, for some reason the critical section didn't seem
	// to work. If interrupted before the pbuf is freed, we have a memory leak. The solution I adopted above is to have a global
	// pbuf allocated at setup that *should* be long enough for every message, and instead just tweak the pbuf sizes manually.
	// This is a pretty hacky solution, but is super fast so we aren't getting caught up on re-interrupts, and even if we do
	// we just end up dropping a packet silently.
//	struct pbuf *packet = pbuf_alloc(PBUF_TRANSPORT, size * sizeof(int), PBUF_RAM);
//	if (!packet) {
//		xil_printf("error allocating pbuf to send\r\n");
//		return;
//	} else {
//		memcpy(packet->payload, (int *)0x44a00000, size * sizeof(int));
//	}


	err_t err = udp_send(upcb, packet);
	if (err != ERR_OK) {
		xil_printf("send error", err);
		return;
	}

//	pbuf_free(packet);


}

void platform_setup_backplane(XIntc *XIntcInstancePtr) {
	// We need to connect our interrupt handler and enable it within the Microblaze interrupt controller.
	XIntc_Connect(XIntcInstancePtr, 2, (XInterruptHandler)BackplaneInterruptHandler, 0);

	XIntc_Enable(XIntcInstancePtr, 2);

}

void platform_enable_interrupts()
{
	microblaze_enable_interrupts();
}
#endif
