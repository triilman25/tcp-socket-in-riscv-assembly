# Architecture	: RISC-V
# Instruction	: RV64I
# OS		: Linux Alpine (RISCV64)
# Created by Tri Ilman A. Fattah


.equ SYS_write, 64
.equ SYS_exit, 93

# SYSCALL
.equ SYS_socket, 198
.equ SYS_bind, 200
.equ SYS_listen, 201
.equ SYS_accept, 202
 
.equ SYS_close, 57

.equ AF_INET, 2
.equ SOCK_STREAM, 1
.equ IPPROTO_TCP, 0
.equ INADDR_ANY, 0
.equ MAX_CONN, 5

.equ STDOUT, 1
.equ STDERR, 2

.macro write fd, buf, len
	addi a7, x0, SYS_write
	addi a0, x0, \fd
	la a1, \buf
	addi a2, x0, \len
	ecall
.endm

.macro write2 fd, buf, len
	addi a7, x0, SYS_write
	addi a0, \fd, 0
	la a1, \buf
	addi a2, x0, \len
	ecall
.endm

.macro exit info
	li a7, SYS_exit
	li a0, \info
	ecall
.endm

.macro close fd
	addi a7, x0, SYS_close
	addi a0, \fd, 0
	ecall
.endm

.macro socket domain, type, protocol
	addi a7, x0, SYS_socket
	addi a0, x0, \domain
	addi a1, x0, \type
	addi a2, x0, \protocol
	ecall
.endm

.macro bind sockfd, addr, addr_len
	addi a7, x0, SYS_bind
	addi a0, \sockfd, 0
	la a1, \addr
	addi a2, \addr_len, 0
	ecall
.endm

.macro listen sockfd, backlog
	addi a7, x0, SYS_listen
	addi a0, \sockfd, 0
	addi a1, x0, \backlog
	ecall
.endm

.macro accept sockfd, addr, addr_len
	addi a7, x0, SYS_accept
	addi a0, \sockfd, 0
	la a1, \addr
	la a2, \addr_len
	ecall
.endm

.section .rodata

start_msg: .ascii "INFO: Starting Web Server!\n"
start_msg_len = . - start_msg

ok_msg: .ascii "INFO: OK!\n"
ok_msg_len = . - ok_msg

error_msg: .ascii "INFO: ERROR!\n"
error_msg_len = . - error_msg

sock_trace: .ascii "INFO: Create a socket...\n"
sock_trace_len = . - sock_trace 

bind_trace_msg: .ascii "INFO: Binding the socket...\n"
bind_trace_msg_len = . - bind_trace_msg 

listen_trace_msg: .ascii "INFO: Listen to the socket...\n" 
listen_trace_msg_len = . - listen_trace_msg

accept_trace_msg: .ascii "INFO: Waiting for client connection...\n" 
accept_trace_msg_len = . - accept_trace_msg


.section .data
.align 2

sockaddr_in.sin_family:.half 0
sockaddr_in.sin_port: 	.half 0
sockaddr_in.sin_addr: 	.word 0
sockaddr_in.sin_zero: 	.dword 0
# sockaddr_in_end:
# sockaddr_in_len = sockaddr_in_end - sockaddr_in.sin_family 
sockaddr_in_len = . - sockaddr_in.sin_family

.align 2
cliaddr.sin_family:	.half 0 	# 2 byte
cliaddr.sin_port: 	.half 0 	# 2 byte
cliaddr.sin_addr: 	.word 0 	# 4 byte
cliaddr.sin_zero: 	.dword 0 	# 8 byte
# cliaddr_end:
cliaddr_size = . - cliaddr.sin_family 
cliaddr_len: .word cliaddr_size 

response: 
	.ascii "HTTP/1.1 200 OK\r\n"
	.ascii "Content-Type: text/html; charset=utf-8\r\n"
	.ascii "Connection: close\r\n"
	.ascii "\r\n"
	.ascii "<h1> Hello from GAS RISC-V! </h1>\n"
response_len = . - response


## ADD PORT WITH LSB 
port:	.half 0x12f0 			# Little endian (LSB)
port_len = . - port			# optional 
 
.section .text
.globl _start
_start:
	# Linker relaxation to access symbol in data section
	.option push					
	.option norelax		
	la gp, __global_pointer$
	.option pop

	write STDOUT, start_msg, start_msg_len
	
	write STDOUT, sock_trace, sock_trace_len
	socket AF_INET, SOCK_STREAM, IPPROTO_TCP
	#socket 3, 4, 0
	blt a0, x0, error
	addi s0, a0, 0 						# save socket file descriptor (sockfd)

	write STDOUT, bind_trace_msg, bind_trace_msg_len
	la 	t0, sockaddr_in.sin_family
	addi	t1, x0, AF_INET					#sin_family
	sh 	t1, 0(t0)

	
	la 	a0, port 					# sin_port 6969 or MSB for network
	jal	ra, lsb_to_msb
	addi	t1, a0, 0
	
	sh 	t1, 2(t0) 	
	addi	t1, x0, INADDR_ANY
	sw 	t1, 4(t0)					# sin_addr
	addi t1, x0, sockaddr_in_len
	bind s0, sockaddr_in.sin_family, t1
	blt a0, x0, error

	write STDOUT, listen_trace_msg, listen_trace_msg_len
	listen s0, MAX_CONN
	blt a0, x0, error	
	
loop:
	write STDOUT, accept_trace_msg, accept_trace_msg_len
	accept s0, cliaddr.sin_family, cliaddr_len
	blt a0, x0, error
	
	# Allocation some stack space
	addi sp, sp, -16					# alocate 16 byte memory
	
	sd s0, 0(sp)
	addi s0, a0, 0 						# connfd

	write2 s0, response, response_len
	write STDOUT, ok_msg, ok_msg_len
	close s0
	ld s0, 0(sp) 						# load sockfd
	jal x0, loop
	
	close s0

	addi sp, sp, 16						# dealocation 
	exit 0

lsb_to_msb:
	addi 	sp, sp, -32
	sd	ra, 24(sp)
	sd	s0, 16(sp)
	addi	s0, sp, 32			# s0 = Frame Pointer
	lh	t1, 0(a0)			# pointer to port (LSB) 
	sb	t1, -17(s0)			# store 0x39
	srl	t1, t1, 8
	sb	t1, -18(s0)
	lh	a0, -18(s0)

	ld	ra, 24(sp)
	ld	s0, 16(sp)
	addi	sp, sp, 32
	jalr	x0, ra, 0
	

	
error:
	write STDERR, error_msg, error_msg_len 
	close s0

	addi sp, sp, 16						# dealocation
	exit 1


# ======== REFERENCE ==========================

# struct sockaddr_in {
#	sa_family_t sin_family; 	type size: unsigned short = 16-bit
#	in_port_t sin_port; 		type size: uint16_t = 16-bit
#	struct in_addr sin_addr; 	type size: uint32_t = 32-bit
#	uint8_t sin_zero[8]; 		type size: 64-bit
#}


