/*
 * Copyright (C) 2009 - 2019 Xilinx, Inc.
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

#include <stdio.h>
#include <unistd.h>
#include "platform.h"
#include "xil_printf.h"
#include "BackplaneReader_AXILite.h"
#include "xparameters.h"
#include "xstatus.h"
#include "xintc.h"
#include "xil_exception.h"
#include "xil_io.h"
#include "xil_types.h"

#include <stdio.h>

#include "xparameters.h"

#include "netif/xadapter.h"

#include "platform.h"
#include "platform_config.h"

#include "lwip/tcp.h"
#include "lwip/udp.h"
#include "xil_cache.h"

#include "lwip/inet.h"


#define INTC_DEVICE_ID		  XPAR_INTC_0_DEVICE_ID
#define INTC_DEVICE_INT_ID	  XPAR_INTC_0_BACKPLANEREADER_AXILITE_0_VEC_ID

int IntcExample(u16 DeviceId);
int SetUpInterruptSystem(XIntc *XIntcInstancePtr);
void DeviceDriverHandler(void *CallbackRef);
void platform_setup_backplane(XIntc *XIntcInstancePtr);

//static XIntc InterruptController;
//volatile static int InterruptProcessed = FALSE;

/* defined by each RAW mode application */
void print_app_header();
int start_application();
int transfer_data();
void tcp_fasttmr(void);
void tcp_slowtmr(void);

/* missing declaration in lwIP */
void lwip_init();


static struct netif server_netif;
struct netif *send_netif;
struct pbuf *packet;

u32 dataBuffer [32];
struct udp_pcb * upcb;

extern XIntc *intcp;

struct pbuf *packet;

void
print_ip(char *msg, ip_addr_t *ip)
{
	print(msg);
	xil_printf("%d.%d.%d.%d\n\r", ip4_addr1(ip), ip4_addr2(ip),
			ip4_addr3(ip), ip4_addr4(ip));
}

void
print_ip_settings(ip_addr_t *ip, ip_addr_t *mask, ip_addr_t *gw)
{

	print_ip("Board IP: ", ip);
	print_ip("Netmask : ", mask);
	print_ip("Gateway : ", gw);
}

int main()
{

	ip_addr_t ipaddr, netmask, gw;

	/* the mac address of the board. this should be unique per board */
	unsigned char mac_ethernet_address[] =
	{ 0xde, 0xad, 0xbe, 0xef, 0x13, 0x37 };

	send_netif = &server_netif;

	init_platform();

	/* initialize IP addresses to be used */
	IP4_ADDR(&ipaddr,  192, 168,   1, 10);
	IP4_ADDR(&netmask, 255, 255, 255,  0);
	IP4_ADDR(&gw,      192, 168,   1,  1);

	lwip_init();

	/* Add network interface to the netif_list, and set it as default */
	if (!xemac_add(send_netif, &ipaddr, &netmask,
						&gw, mac_ethernet_address,
						PLATFORM_EMAC_BASEADDR)) {
		xil_printf("Error adding N/W interface\n\r");
		return -1;
	}

	netif_set_default(send_netif);


	/* specify that the network if is up */
	netif_set_up(send_netif);

	/* Set up our global PCB for UDP */
	upcb = udp_new();

	err_t err;
	ip_addr_t remote_addr;

	err = inet_aton("192.168.1.255", &remote_addr);
	if (!err) {
		xil_printf("Invalid Server IP address: %d\r\n", err);
		return -1;
	}

	err = udp_bind(upcb, &ipaddr, 0);
	if (err != ERR_OK) {
		xil_printf("udp_client: Error on udp_connect: %d\r\n", err);
		udp_remove(upcb);
		return -1;
	}

	err = udp_connect(upcb, &remote_addr, 13370);
	if (err != ERR_OK) {
		xil_printf("udp_client: Error on udp_connect: %d\r\n", err);
		udp_remove(upcb);
		return -1;
	}

	// EXPERIMENTAL: This size could possibly not be enough?
	 packet = pbuf_alloc(PBUF_TRANSPORT, 0x400, PBUF_RAM);

	/* now enable interrupts */
	platform_enable_interrupts();


	/* receive and process packets */
	while (1) {

	}

	/* never reached */
	cleanup_platform();

	return 0;
}


