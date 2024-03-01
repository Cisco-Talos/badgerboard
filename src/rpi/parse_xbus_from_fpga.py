# Copyright 2024 Cisco Systems
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

from multiprocessing import Process, Queue
from queue import Empty
from time import sleep
import socketserver
import argparse
import random
import struct
import socket
import math
import sys

from scapy.all import Ether, IP, TCP, sendp, Raw
from scapy.contrib.modbus import ModbusADURequest
from scapy.contrib.modbus import ModbusADUResponse

parser = argparse.ArgumentParser(description='Process raw backplane data from FPGA')
parser.add_argument('--lhost', type=str, default='', help='The address to listen on for UDP traffic from the FPGA')
parser.add_argument('--lport', type=int, default=0x343A, help='The port to listen on for UDP traffic from the FPGA')
parser.add_argument('--sendinterface', type=str, default='lo', help='The interface on which to send messages out for Snort ingestion')
parser.add_argument('--recvworker_count', type=int, default=0x0A, help='The number of workers to put on UDP recv from the FPGA')
parser.add_argument('-v', '--v', action='store_true', help='Enable verbose output')
parser.add_argument('-vv', '--vv', action='store_true', help='Enable REALLY verbose output')
args = parser.parse_args()

class UdpServer():

    def __init__(self, lhost, lport):
        """
        Initialize a UdpServer Object

        Keyword arguments:
        lhost -- the ip address on which to listen for FPGA traffic
        lport -- the port on which to listen for FPGA traffic
        """

        self.lhost = lhost
        self.lport = lport
        self.recv_sz = 0x7E
        self.socket_recv_buf = 0x010000 * 0xC8

        self.s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.s.setsockopt(socket.SOL_SOCKET, \
                            socket.SO_RCVBUF, \
                            self.socket_recv_buf)
        self.s.bind((self.lhost, self.lport))

    def serve_forever(self, fpga_msg_q, worker_count):
        """
        Create the specified number of worker processes that will watch for
        incoming traffic from the FPGA

        This approach is taken to help avoid missing messages sent by the FPGA

        In testing we found that exceeding 10 workers did not appear to make a
        meaningful difference

        Keyword arguments:
        fpga_msg_q -- a Queue used to store received messages
        worker_count -- the number of workers to spawn
        """

        try:
            # list to save off handles to workers
            workers = []

            # run the `self._spawn_receive_process` function as a new process
            for _ in range(worker_count):
                cur_recv_p = Process(target=self._spawn_receive_process, \
                    args=(fpga_msg_q,))
                workers.append(cur_recv_p)
                cur_recv_p.start()

            # wait for all workers to finish before returning
            for cur_recv_p in workers:
                cur_recv_p.join()

        except OSError as e:
            print('[!] ERROR: {}'.format(e))

        except KeyboardInterrupt:
            print('\r[*] Cleaning up UDP server')

        finally:
            self.shutdown()

    def _spawn_receive_process(self, fpga_msg_q):
        """
        Wait for a message from the FPGA and then place that message into a
        shared multiprocessing Queue

        Keyword arguments:
        fpga_msg_q -- a Queue used to store received messages
        """

        try:
            # receive the new message and add it to the Queue
            while True:
                msg = self.s.recvfrom(self.recv_sz)[0]
                fpga_msg_q.put(msg)

        except KeyboardInterrupt:
            print('\r[*] Cleaning up spawned recv process')


    def shutdown(self):
        self.s.close()

    def __del__(self):
        self.shutdown()


class FpgaMsgProcessor():

    def __init__(self):
        """
        Initialize a FpgaMsgProcessor object 
        """
        self.xbus_msg_start_bytes = [0x04, 0x05]
        self.xbus_umas_msg_sz_offset = 0x0A
        self.xbus_umas_hdr_sz = 0x13
        self.xbus_umas_len_field_sz = 0x02
        self.xbus_pay_end_offset = -0x06
        self.xbus_pay_start_offset = 0x0A
        self.xbus_max_pay_sz = 0x20
        self.xbus_msg_max_sz = 0x30
        self.xbus_msg_flag = b'\x08\x64\x01\x00\x00\x7F'
        self.uint16 = 0x02
        self.uint32 = 0x04

    # TODO: may want to flip this down the road to take the entire packet
    # TODO: this is probably already implemented in some stdlib package
    def _fix_endianess(self, input_data):
        """
        Reverses the endianess of UDP messages from the FPGA
        
        This function takes an input_data variable of 4 or 2 bytes and 
        switches it from little-endian to big-endian. It does NOT take the 
        entire packet: just the data to be flipped.

        Keyword arguments:
        input_data -- a 2 or 4 byte list of data to flip endianness
        """

        input_data_len = len(input_data)

        # create a bytearray for output
        fixed_msg = bytearray(input_data_len)

        # determine format by the amount of data passed
        if input_data_len == self.uint32:
            input_data_format = '<I'
            output_data_format = '>I'
        elif input_data_len == self.uint16:
            input_data_format = '<H'
            output_data_format = '>H'
        else:
            raise ValueError('invalid number of bytes in `input_data`')

        # unpack the data so it can be repacked the desired way
        tmp_msg = struct.unpack_from(input_data_format, input_data)[0]

        # repack the data as big endian
        offset = 0x00
        struct.pack_into(output_data_format, fixed_msg, offset, tmp_msg)

        # return our fixed data
        return fixed_msg

    def _extractUmasTraffic(self, xbus_umas_data):
        """
        Extract the length field and remove the size of the data before UMAS 
        actually starts
        
        The extracted payload_sz value initally contains a count for more 
        than just the Umas data
         
        To get the correct value here we have to subtract off the remaining 
        bytes in the Umas header, not counting the two bytes for the length 
        field itself
        
        For example, below the extracted value would be 0x43 but there are 
        only 0x32 bytes of UMAS data
        
          1. 04 05 00 27 04 26 05 ea 98 08 43 00 0c 0a 5c 06
             1b 00 00 40 08 64 01 00 00 7f d9 d9 06 5a 00 fe
             02 0d 00 00 a2 9b 02 00 00 02 70 a9 00 05 ef de
        
          2. 04 05 08 27 04 26 04 f8 94 08 0d 00 00 a2 9b 02
             00 00 02 0e 00 0d 0a 03 e4 07 02 0e 08 0c 0a 03
             e4 07 02 00 00 00 08 50 72 6f c8 a4 00 0b 9f bc
        
          3. 04 55 90 27 04 26 05 bc 86 08 6a 65 63 74 00 43
        
        For all UMAS messages except those only a couple bytes in size, 
        additional XBUS messages will need to be read to get the remaining 
        UMAS data

        Keyword arguments:
        xbus_umas_data -- a list of XBUS messages containing a UMAS message
        """

        # get the reported length field
        payload_sz = struct.unpack_from('B', xbus_umas_data[0], \
            offset=self.xbus_umas_msg_sz_offset)[0]

        # remove the size of the header field within the payload
        payload_sz -= self.xbus_umas_hdr_sz 

        # add the size of the length field back in since its not included in 
        # the count value
        payload_sz += self.xbus_umas_len_field_sz

        # extract the one byte identifier of the sending module
        # this value will get used later for the MAC and IP
        # TODO: are you sure these are in the correct position?
        xbus_umas_dst_id_offset = 0x0C
        dst_id = struct.unpack_from('B', xbus_umas_data[0], \
            offset=xbus_umas_dst_id_offset)[0]

        # extract the one byte identifier of the receiving module
        # this value will get used later for the MAC and IP
        # TODO: are you sure these are in the correct position?
        xbus_umas_src_id_offset = 0x0D
        src_id = struct.unpack_from('B', xbus_umas_data[0], \
            offset=xbus_umas_src_id_offset)[0]

        # initialize storage variables for message processing
        idx = 0x00
        last_idx = len(xbus_umas_data) - 0x01 
        umas_txn_data = b''

        # handle cases where only one XBUS message exists specially
        #
        # this is needed because the XBUS message tails are not a known size
        #
        # this case is fairly common as we have commands such as 
        # READ_PROJECT_INFO which only need 0x03 bytes
        if last_idx == 0x00:
            offset = self.xbus_pay_start_offset+self.xbus_umas_hdr_sz
            umas_txn_data = xbus_umas_data[0][offset:offset + payload_sz]

        # handle cases with more than one XBUS message part
        else:
            # loop over each of the messages and pull out the embedded 
            # Umas data
            for xbus_umas_msg_part in xbus_umas_data:
                # on the first message we cannot pull the entire XBUS payload 
                # as it contains information other than just Umas
                #
                # in this case we have to include an offset to bypass the  
                # xbus Umas header as well as the start offset used for 
                # all messages
                if idx == 0x00:
                    umas_txn_data = xbus_umas_msg_part[ \
                                      self.xbus_pay_start_offset \
                                      + self.xbus_umas_hdr_sz \
                                      : self.xbus_pay_end_offset]
                
                # in the case of the last message we cannot assume that the 
                # XBUS message tail is included in the message
                #
                # due to this we have to calculate the number of bytes to 
                # read based on the total expected compared against the 
                # number already read
                elif idx == last_idx:
                    remaining_data_sz = payload_sz - len(umas_txn_data)
                    umas_txn_data += xbus_umas_msg_part[ \
                                       self.xbus_pay_start_offset \
                                       : self.xbus_pay_start_offset \
                                       + remaining_data_sz]
                
                # for every message in between we know a few things:
                # - the Umas data will always start at the same offset 
                #   (self.xbus_pay_start_offset)
                # - the message will always be a known size 
                #   (self.xbus_max_pay_sz)
                # - the xbus tail may or may not exist, but we don't care 
                #   since the data size is static
                else:
                    umas_txn_data += xbus_umas_msg_part[ \
                                       self.xbus_pay_start_offset \
                                       : self.xbus_pay_start_offset \
                                       + self.xbus_max_pay_sz]
                
                # keep our counter in line
                idx += 0x01

        if args.v:
            if umas_txn_data == b'':
                print("[!] ")
                print("[!] WARNING: Result umas_txn_data appears to be empty")
                for cur_trans in xbus_umas_data:
                    print("[!]\t{}".format(cur_trans.hex()))
                print("[!] ")


        # Build a dict holding the txn details once a full payload 
        # is extracted
        umas_txn = {}
        umas_txn['src_id'] = src_id
        umas_txn['dst_id'] = dst_id
        umas_txn['payload'] = umas_txn_data

        # return our data
        return umas_txn

    def _extractXbusTraffic(self, cur_fpga_msg):
        """
        Extract the XBUS traffic from the FPGA UDP message and split it out
        into a list of messages

        Keyword arguments:
        cur_fpga_msg -- the raw FPGA message
        """

        # stash the size of the full FPGA message for later
        cur_fpga_msg_len = len(cur_fpga_msg)

        # get the size of the full UMAS payload once reassembled
        umas_message_sz = int(cur_fpga_msg[self.xbus_umas_msg_sz_offset])

        # store an array of XBUS messages that will be combined to get a 
        # single UMAS message
        xbus_txns = []

        # when the Umas message is greater than the maximum size possible 
        # for a single XBUS message, there will be multiple XBUS messages 
        # in the same FPGA message
        if umas_message_sz > self.xbus_max_pay_sz:
            # get the number of packets
            #
            # python3 appears to return a float from division so we 
            # can just round up to handle the last partial message
            num_pkts = math.ceil(cur_fpga_msg_len / self.xbus_msg_max_sz)

            # Extract each of the XBUS messages within the FPGA message
            for idx in range(num_pkts):
                start = self.xbus_msg_max_sz * idx
                end = start + self.xbus_msg_max_sz
                if end > cur_fpga_msg_len:
                    end = cur_fpga_msg_len
                xbus_txns.append(cur_fpga_msg[start:end])

                if args.v:
                    # log times where the next message getting added doesn't 
                    # follow expectations
                    if xbus_txns[-1][0] not in self.xbus_msg_start_bytes:
                        print("[!] ")
                        print("[!] WARNING: Adding a partial UMAS message \
                            that doesn't start with 0x04 or 0x05")
                        for cur_trans in xbus_txns:
                            print("[!]\t{}".format(cur_trans.hex()))
                        print("[!] ")

        # when the reported message size is smaller than the max available 
        # for one message just add it and move on
        else:
            xbus_txns.append(cur_fpga_msg)

        # return the parsed txns for processing
        return xbus_txns


    def run(self, fpga_msg_q, xbus_msg_q):
        """
        Starts the FPGA message processor

        Keyword arguments:
        fpga_msg_q -- a Queue containing the raw msgs from UdpServer workers
        xbus_msg_q -- a Queue containing processed XBUS messages
        """

        # counter for verifying all expected messages have gone through
        msg_count = 0x00

        try:
            # loop forever, reading and processing the next FPGA message on 
            # each loop
            while True:
                # get the next UDP message from the FPGA that is sitting in 
                # the queue
                raw_fpga_msg = fpga_msg_q.get()

                # convert the 4-byte based little endian data in the UDP 
                # packet to the needed big endian version for later 
                # processing
                cur_fpga_msg = b''
                for idx in range(0x00, len(raw_fpga_msg), self.uint32):
                    cur_fpga_msg += self._fix_endianess( \
                        raw_fpga_msg[idx:idx+self.uint32])

                # only process messages that contain UMAS traffic at this time
                if self.xbus_msg_flag in cur_fpga_msg:
                    # extract the individual XBUS messages from the combined 
                    # FPGA message
                    xbus_txns = self._extractXbusTraffic(cur_fpga_msg)

                    # print each of the split XBUS messages for debugging
                    # only really useful for debugging
                    if args.vv:
                        print("[*] XBUS UMAS Message: {} packets" \
                            .format(len(xbus_txns)))
                        for txn in xbus_txns:
                            print("[*]\t{}".format(txn.hex()))

                    # rebuild the UMAS message from the XBUS parts
                    umas_txn = self._extractUmasTraffic(xbus_txns)
                    if umas_txn['payload']:
                        # add the txn to the Umas message queue for future 
                        # processing
                        xbus_msg_q.put(umas_txn)

                        # print debug messages if desired
                        if args.v:
                            # print out responses differently
                            if umas_txn['payload'][2] == 0xFD \
                              or umas_txn['payload'][2] == 0xFE:
                                print("[*] UMAS Response:\t\t{}" \
                                    .format(umas_txn['payload']))
                            # otherwise just print out the data and fnc code
                            else: 
                                print("[*] UMAS Request FNC {}:\t{}" \
                                    .format(hex(umas_txn['payload'][2]), \
                                        umas_txn['payload']))

                # keep a running count of the number of messages processed
                # this is only remotely useful for debugging
                msg_count += 0x01
                if args.v:
                    print("[*] Messages Processed: {}".format(msg_count))

        except KeyboardInterrupt:
            print("\r[*] Cleaning up FPGA message processor")


class UmasMsgSpoofer():

    def __init__(self):
        """
        Initializes the UmasMsgSpoofer
        """
        self.mbap_len = 0x07
        self.modbus_port = 0x01F6

    def run(self, umas_msg_q):
        """
        Loops through the passed UMAS message Queue, kicking off a spoofed
        transaction to assist in Snort traffic ingestion

        Keyword arguments:
        umas_msg_q -- a Queue containing the rebuilt UMAS messages
        """

        try:
            while True:
                # get the next message in the queue
                cur_umas_msg = umas_msg_q.get()

                print(cur_umas_msg)

                # iterate over each of the extracted txns and spoof a 
                # TCP stream containing the communication
                self._spoofTransaction(cur_umas_msg['src_id'], \
                    cur_umas_msg['dst_id'], self.modbus_port, \
                    cur_umas_msg['payload'])

        except KeyboardInterrupt:
            print("\r[*] Cleaning up UMAS msg spoofer server")

    def _spoofTransaction(self, src_id, dst_id, dport, payload):
        """
        Creates spoofed TCP transactions on the specified interface 

        Keyword arguments:
        src_id -- sending module identifier byte
        dst_id -- receiving module identifier byte
        dport -- port on which to spoof the transaction
        payload -- UMAS message to send in the transaction
        """

        # get a new ISN for each txn
        src_isn = random.randint(0x400, 0xFFFFFFF)
        dst_isn = random.randint(0x400, 0xFFFFFFF)

        # get a new source port for each txn
        sport = random.randint(0x400, 0xFFFF)

        # get a new modbus txn id for each txn
        trans_id = random.randint(0x01, 0xFFFF)

        # Ether
        src_mac = "DE:AD:BE:EF:00:{:02x}".format(src_id)
        dst_mac = "DE:AD:BE:EF:00:{:02x}".format(dst_id)
        req_ether = Ether(src=src_mac, dst=dst_mac)
        resp_ether = Ether(src=dst_mac, dst=src_mac)
        # TODO: should probably make sure this exists
        iface = args.sendinterface

        # IP
        dst = "192.168.0.{}".format(dst_id)
        src = "192.168.0.{}".format(src_id)
        req_ip = IP(src=src, dst=dst)
        resp_ip = IP(src=dst, dst=src)

        # SYN
        SYN = TCP(sport=sport, \
            dport=dport, \
            flags='S', \
            seq=src_isn)
        sendp(req_ether/req_ip/SYN, iface=iface)

        # SYNACK
        SYNACK = TCP(sport=dport, \
            dport=sport, \
            flags='SA', \
            seq=dst_isn, \
            ack=SYN.seq+0x01)
        sendp(resp_ether/resp_ip/SYNACK, iface=iface)

        # ACK
        ACK = TCP(sport=sport, \
            dport=dport, \
            flags='A', \
            seq=SYNACK.ack, \
            ack=SYNACK.seq+0x01)
        sendp(req_ether/req_ip/ACK, iface=iface)

        # XBUS Message
        payload_layer = Raw(payload)
        XBUSUMAS = TCP(sport=sport, dport=dport, flags='PA', seq=SYNACK.ack, ack=SYNACK.seq+0x01)/ModbusADURequest(trans_id=trans_id)/payload_layer
        sendp(req_ether/req_ip/XBUSUMAS, iface=iface)

        # XBUS Message ACK
        XBUSUMASACK = TCP(sport=dport, \
            dport=sport, \
            flags='A', \
            seq=XBUSUMAS.ack, \
            ack=XBUSUMAS.seq+len(payload_layer)+MBAPLEN)
        sendp(resp_ether/resp_ip/XBUSUMASACK, iface=iface)

        #
        # RST teardown
        # tearing down to prevent Snort from combining streams
        #

        # FINACK
        FINACK = TCP(sport=sport, \
            dport=dport, \
            flags='FA', \
            seq=XBUSUMASACK.seq, \
            ack=XBUSUMASACK.ack)
        sendp(req_ether/req_ip/FINACK, iface=iface)

        # LASTACK
        LASTACK = TCP(sport=dport, \
            dport=sport, \
            flags='A', \
            seq=FINACK.ack, \
            ack=FINACK.seq+0x01)
        sendp(resp_ether/resp_ip/LASTACK, iface=iface)

        # RSTACK
        RSTACK = TCP(sport=dport, \
            dport=sport, \
            flags='RA', \
            seq=LASTACK.seq, \
            ack=LASTACK.ack)
        sendp(resp_ether/resp_ip/RSTACK, iface=iface)


def main():
    """
    Kicks off the following:
       * UdpServer to receive messages from the FGPA
       * FpgaMsgProcessor to extract XBUS messages from raw FPGA messages
       * UmasMsgSpoofer to take processed XBUS messages and send them to Snort
    """

    # queue to hold raw messages from the FPGA
    fpga_msg_q = Queue()

    # queue to hold cleaned up raw XBUS messages broken out of the FPGA msgs
    xbus_msg_q = Queue()

    # queue to keep track of how many messages have been processed
    # 
    # it is initialized at 0x00 as it will get incremented each time a 
    # message is processed successfully
    # 
    # NOTE: probably don't need this outside of testing
    msg_count_q = Queue()
    msg_count_q.put(0x00)

    # server object to handle requests from the FPGA
    #
    # there should only ever be one of these unless we start using multiple 
    # ports for faster data transfer
    server = UdpServer(lhost=args.lhost, lport=args.lport)

    # message processor to take raw FPGA messages and extract XBUS messages
    fpga_msg_processor = FpgaMsgProcessor()

    # processor to take extracted Umas messages and prepare/send them across 
    # the wire to Snort
    umas_msg_spoofer = UmasMsgSpoofer()

    # begin processing
    try:
        # create a process in which to run the UDP server
        #
        # this will listen for traffic from the FPGA
        #
        # a separate process is used as the FPGA is going to send traffic 
        # as fast as it can, which is usually faster than we can receive 
        #
        # a queue is used to store the messages because they are going need 
        # to be accessed by a differrent process
        server_p = Process(target=server.serve_forever, \
            args=(fpga_msg_q, args.recvworker_count))
        server_p.start()

        # create a process to run the FPGA message processor
        #
        # this is needed because we can't spend the time to process each 
        # message on the fly
        #
        # data is transferred between the server and the processor via the 
        # fpga_msg_q
        #
        # messages extracted from the FPGA messages are put into the 
        # xbus_msg_q for later processing
        #
        # a msg_count_q is kept for testing purposes to ensure all sent 
        # messages are processed
        #
        # NOTE: may need to build a pool of these if the queue gets too big
        fpga_msg_processor_p = Process(target=fpga_msg_processor.run, \
            args=(fpga_msg_q, xbus_msg_q, ))
        fpga_msg_processor_p.start()

        # create a process to handle sending of prepared UMAS messages from 
        # the queue
        #
        # each queue entry will contain a dict with the following keys:
        #  - src_id: the one byte src field from the request packet, 
        #            converted to an int
        #  - dst_id: the one byte dst field from the request packet, 
        #            converted to an int
        #  - payload: a bytestring containing the entire message, built from 
        #             multiple XBUS messages where necessary
        umas_msg_spoofer_p = Process(target=umas_msg_spoofer.run, \
            args=(xbus_msg_q, ))
        umas_msg_spoofer_p.start()

        # block for the sub processes to finish
        server_p.join()
        fpga_msg_processor_p.join()
        umas_msg_spoofer_p.join()

    # catch CTRL+C
    except KeyboardInterrupt:
        print("\r[*] Exiting...")

    # make sure to clean up the server if needed
    finally:
        server.shutdown()


if __name__ == '__main__':
    # require python3
    if sys.version_info[0] != 0x03:
        print("Python2 is not supported")
        exit()

    main()
