# GUTHRIE
# William

.data
displayBuffer:  .space 0x40000 # space for 512x256 bitmap display 
space: .space 0x40
errorBuffer:    .space 0x40000 # space to store match function
templateBuffer: .space 0x100   # space for 8x8 template
imageFileName:    .asciiz "pxlcon512x256cropgs.raw" 
templateFileName: .asciiz "template8x8gs.raw"
# struct bufferInfo { int *buffer, int width, int height, char* filename }
imageBufferInfo:    .word displayBuffer  512 128  imageFileName
errorBufferInfo:    .word errorBuffer    512 128  0
templateBufferInfo: .word templateBuffer 8   8    templateFileName

.text
main:	la $a0, imageBufferInfo
	jal loadImage
	la $a0, templateBufferInfo
	jal loadImage
	la $a0, imageBufferInfo
	la $a1, templateBufferInfo
	la $a2, errorBufferInfo
	jal matchTemplateFast        # MATCHING DONE HERE
	la $a0, errorBufferInfo
	jal findBest
	la $a0, imageBufferInfo
	move $a1, $v0
	jal highlight
	la $a0, errorBufferInfo	
	jal processError
	li $v0, 10		# exit
	syscall
	

##########################################################
# matchTemplate( bufferInfo imageBufferInfo, bufferInfo templateBufferInfo, bufferInfo errorBufferInfo )
# NOTE: struct bufferInfo { int *buffer, int width, int height, char* filename }
matchTemplate:	
	
	addi $sp $sp -28
	sw $ra 0($sp)
	sw $s0 4($sp)
	sw $s1 8($sp)
	sw $s2 12($sp)
	sw $s3 16($sp)
	sw $s4 20($sp)
	sw $s5 24($sp)
	
	lw $s0 0($a0)	#s0 = imageBufferInfo
	lw $s1 0($a1)	#s1 = templateBufferInfo
	lw $s2 0($a2)	#s2 = errorBufferInfo
	
	lw $s3 8($a0)	#s3 = imageHeight
	addi $s3 $s3 -8	#s3 = imageHeight - 8
	
	lw $s4 4($a0)	#s4 = imageWidth
	addi $s4 $s4 -8	#s4 = imageWidth - 8
	
	addi $s5 $0 8 	#s5 = 8
	
	add $t0 $0 $0	#t0 = y
	add $t1 $0 $0	#t1 = x
	add $t2 $0 $0	#t2 = j
	add $t3 $0 $0	#t3 = i
	
loop:	lw $t4 4($a1) 	#t4 = width of template
	mulo $t4 $t4 $t2#t4 = j*width of template
	add $t4 $t4 $t3 #t4 = offset of T[i][j] in words
	sll $t4 $t4 2  #t4 = offset in bytes
	lw $t5 0($a1) 	#load base address of data in template buffer
	add $t5 $t4 $t5 #add offset to base address and save to t5
	lbu $t4 0($t5)	#load value at t5 into t4 (t4 = T[i][j])
	
	lw $t5 4($a0)	#t5 = width of image
	add $t6 $t0 $t2 #t6 = y + j
	mulo $t5 $t5 $t6 #t5 = width * (y + j)
	add $t5 $t5 $t1 #t5 = width * (y + j) + x
	add $t5 $t5 $t3 #t5 = width * (y + j) + x + i
	sll $t5 $t5 2 	#t5 = offset in bytes
	lw $t6 0($a0) #load base address of data in image buffer
	add $t6 $t5 $t6 #add offset to base address and save to t6
	lbu $t5 0($t6) #load value at t6 into t5 (t5 = I[x+i][j+y])
	
	sub $t5 $t5 $t4 #t5 = I[x+i][y+j] - T[i][j]
	abs $t5 $t5	#t5 = |[x+i][y+j] - T[i][j]|
	
	lw $t6 4($a2)	#t6 = width of error buffer 
	mulo $t6 $t6 $t0 #t6 = width * y
	add $t6 $t6 $t1	#t6 = width * y + x
	sll $t6 $t6 2 	#t6 = offset in bytes
	lw $t7 0($a2) 	#t7 = base address
	add $t6 $t6 $t7	#add offset
	lw $t7 0($t6)	#load number at t6
	add $t7 $t7 $t5	#add abs(...) to value at t6
	sw $t7 0($t6)	#put new number back into t6

	addi $t3 $t3 1	  #i++
	
	bne $t3 $s5 loop #if $t3(i) != $s5(8) go to loop
	add $t3 $0 $0	  #reset i to 0
	addi $t2 $t2 1	  #j++
	
	bne $t2 $s5 loop #if $t2(j) != $s5(8) go to loop
	add $t2 $0 $0	  #reset j to 0
	addi $t1 $t1 1	  #x++	
	
	ble $t1 $s4 loop #if $t1(x) <= $s4(width-8) go up to loop
	add $t1 $0 $0	  #reset x to 0
	addi $t0 $t0 1	  #y++
	
	ble $t0 $s3 loop #if $t0(y) <= $s3(height-8) go up to loop
	
	
end:	lw $ra 0($sp)
	lw $s0 4($sp)
	lw $s1 8($sp)
	lw $s2 12($sp)
	lw $s3 16($sp)
	lw $s4 20($sp)
	lw $s5 24($sp)
	addi $sp $sp 28
	jr $ra	
	
##########################################################
# matchTemplateFast( bufferInfo imageBufferInfo, bufferInfo templateBufferInfo, bufferInfo errorBufferInfo )
# NOTE: struct bufferInfo { int *buffer, int width, int height, char* filename }
matchTemplateFast:	
	
	addi $sp $sp -44
	sw $s0 0($sp)
	sw $s1 4($sp)
	sw $s2 8($sp)
	sw $s3 12($sp)
	sw $s4 16($sp)
	sw $s5 20($sp)
	sw $s6 24($sp)
	sw $s7 28($sp)
	sw $v0 32($sp)
	sw $v1 36($sp)
	sw $a3 40($sp)
	
	lw $s0 8($a0)		#s0 = imageHeight
	addi $s0 $s0 -8		#s0 = imageHeight - 8
	
	lw $s6 4($a0)		#s6 = imageWidth
	addi $s1 $s6 -8		#s1 = imageWidth - 8
		
	add $s2 $0 $0 		#s2 = j 
	add $s3 $0 $0 		#s3 = y 
	add $s4 $0 $0 		#s4 = x
	
	lw $s5 4($a1)		#s5 = width of template
	sll $s5 $s5 2  		#s5 = width of template in bytes
	
	lw $s7 0($a0)		#s7 = base address of I
	lw $v0 0($a2)		#v0 = base address of SAD
	
JLoop:	mulo $t8 $s2 $s5	#t8 = j*width of template (in bytes)
	lw $t9 0($a1)		#load base address of data in template buffer
	add $t9 $t9 $t8		#t9 = address of T[0][j]
	
	lbu $t0 0($t9)		#t0 = value at T[0][j]
	lbu $t1 4($t9)		#t1 = value at T[1][j]
	lbu $t2 8($t9)		#t2 = value at T[2][j]
	lbu $t3 12($t9)		#t3 = value at T[3][j]
	lbu $t4 16($t9)		#t4 = value at T[4][j]
	lbu $t5 20($t9)		#t5 = value at T[5][j]
	lbu $t6 24($t9)		#t6 = value at T[6][j]
	lbu $t7 28($t9)		#t7 = value at T[7][j]
	
InLoop: add $t8 $s2 $s3		#t8 = y + j
	mulo $t8 $t8 $s6	#t8 = (y + j) * width of image
	add $t8 $t8 $s4		#t8 = offset of I[x][y+j]
	sll $t8 $t8 2		#t8 = offset in bytes
	add $t8 $t8 $s7		#t8 = address of I[x][y+j]
	
	mulo $v1 $s3 $s6	#v1 = y * width of error(image really)
	add $v1 $v1 $s4		#v1 = offset of SAD[x,y]
	sll $v1 $v1 2		#v1 = offset of SAD[x,y] in bytes
	add $v1 $v1 $v0		#v1 = address of SAD[x,y]
	lw $a3 0($v1)		#a3 = value of SAD[x,y]
	
	#Calculating
	lbu $t9 0($t8)		#t9 = value of I[x][y+j]
	sub $t9 $t9 $t0		#t9 = I[x][y+j] - t0
	abs $t9 $t9
	add $a3 $a3 $t9		#SAD[x,y] += abs(t9)
	
	lbu $t9 4($t8)		#t9 = value of I[x+1][y+j]
	sub $t9 $t9 $t1 	#t9 = I[x+1][y+j] - t1
	abs $t9 $t9
	add $a3 $a3 $t9		#SAD[x,y] += abs(t9)
	
	lbu $t9 8($t8)		#t9 = value of I[x+2][y+j]
	sub $t9 $t9 $t2		#t9 = I[x+2][y+j] - t2
	abs $t9 $t9
	add $a3 $a3 $t9		#SAD[x,y] += abs(t9)
	
	lbu $t9 12($t8)		#t9 = value of I[x+3][y+j]
	sub $t9 $t9 $t3		#t9 = I[x+3][y+j] - t3
	abs $t9 $t9
	add $a3 $a3 $t9		#SAD[x,y] += abs(t9)
	
	lbu $t9 16($t8)		#t9 = value of I[x]+4[y+j]
	sub $t9 $t9 $t4		#t9 = I[x+4][y+j] - t4
	abs $t9 $t9
	add $a3 $a3 $t9		#SAD[x,y] += abs(t9)
	
	lbu $t9 20($t8)		#t9 = value of I[x+5][y+j]
	sub $t9 $t9 $t5		#t9 = I[x+5][y+j] - t5
	abs $t9 $t9
	add $a3 $a3 $t9		#SAD[x,y] += abs(t9)
	
	lbu $t9 24($t8)		#t9 = value of I[x+6][y+j]
	sub $t9 $t9 $t6		#t9 = I[x+6][y+j] - t6
	abs $t9 $t9
	add $a3 $a3 $t9		#SAD[x,y] += abs(t9)
	
	lbu $t9 28($t8)		#t9 = value of I[x+7][y+j]
	sub $t9 $t9 $t7		#t9 = I[x+7][y+j] - t7
	abs $t9 $t9
	add $a3 $a3 $t9		#SAD[x,y] += abs(t9)

	sw $a3 0($v1)		#Put new value back into SAD[x,y]
	#looping
	addi $s4 $s4 1	  	#x++
	
	ble $s4 $s1 InLoop 	#if $s4(x) <= $s1(width-8) go up to InLoop
	add $s4 $0 $0	  	#reset x to 0
	addi $s3 $s3 1	  	#y++
	
	ble $s3 $s0 InLoop 	#if $s3(y) <= $s0(height-8) go up to InLoop
	add $s3 $0 $0	  	#reset y to 0
	addi $s2 $s2 1	  	#j++
	
	addi $t8 $0 8		#t8 = 8
	blt $s2 $t8 JLoop
	
	lw $s0 0($sp)
	lw $s1 4($sp)
	lw $s2 8($sp)
	lw $s3 12($sp)
	lw $s4 16($sp)
	lw $s5 20($sp)
	lw $s6 24($sp)
	lw $s7 28($sp)
	lw $v0 32($sp)
	lw $v1 36($sp)
	lw $a3 40($sp)
	addi $sp $sp 44
	jr $ra	
	
	
	
###############################################################
# loadImage( bufferInfo* imageBufferInfo )
# NOTE: struct bufferInfo { int *buffer, int width, int height, char* filename }
loadImage:	lw $a3, 0($a0)  # int* buffer
		lw $a1, 4($a0)  # int width
		lw $a2, 8($a0)  # int height
		lw $a0, 12($a0) # char* filename
		mul $t0, $a1, $a2 # words to read (width x height) in a2
		sll $t0, $t0, 2	  # multiply by 4 to get bytes to read
		li $a1, 0     # flags (0: read, 1: write)
		li $a2, 0     # mode (unused)
		li $v0, 13    # open file, $a0 is null-terminated string of file name
		syscall
		move $a0, $v0     # file descriptor (negative if error) as argument for read
  		move $a1, $a3     # address of buffer to which to write
		move $a2, $t0	  # number of bytes to read
		li  $v0, 14       # system call for read from file
		syscall           # read from file
        		# $v0 contains number of characters read (0 if end-of-file, negative if error).
        		# We'll assume that we do not need to be checking for errors!
		# Note, the bitmap display doesn't update properly on load, 
		# so let's go touch each memory address to refresh it!
		move $t0, $a3	   # start address
		add $t1, $a3, $a2  # end address
loadloop:	lw $t2, ($t0)
		sw $t2, ($t0)
		addi $t0, $t0, 4
		bne $t0, $t1, loadloop
		jr $ra
		
		
#####################################################
# (offset, score) = findBest( bufferInfo errorBuffer )
# Returns the address offset and score of the best match in the error Buffer
findBest:	lw $t0, 0($a0)     # load error buffer start address	
		lw $t2, 4($a0)	   # load width
		lw $t3, 8($a0)	   # load height
		addi $t3, $t3, -7  # height less 8 template lines minus one
		mul $t1, $t2, $t3
		sll $t1, $t1, 2    # error buffer size in bytes	
		add $t1, $t0, $t1  # error buffer end address
		li $v0, 0		# address of best match	
		li $v1, 0xffffffff 	# score of best match	
		lw $a1, 4($a0)    # load width
        		addi $a1, $a1, -7 # initialize column count to 7 less than width to account for template
fbLoop:		lw $t9, 0($t0)        # score
		sltu $t8, $t9, $v1    # better than best so far?
		beq $t8, $zero, notBest
		move $v0, $t0
		move $v1, $t9
notBest:		addi $a1, $a1, -1
		bne $a1, $0, fbNotEOL # Need to skip 8 pixels at the end of each line
		lw $a1, 4($a0)        # load width
        		addi $a1, $a1, -7     # column count for next line is 7 less than width
        		addi $t0, $t0, 28     # skip pointer to end of line (7 pixels x 4 bytes)
fbNotEOL:	add $t0, $t0, 4
		bne $t0, $t1, fbLoop
		lw $t0, 0($a0)     # load error buffer start address	
		sub $v0, $v0, $t0  # return the offset rather than the address
		jr $ra
		

#####################################################
# highlight( bufferInfo imageBuffer, int offset )
# Applies green mask on all pixels in an 8x8 region
# starting at the provided addr.
highlight:	lw $t0, 0($a0)     # load image buffer start address
		add $a1, $a1, $t0  # add start address to offset
		lw $t0, 4($a0) 	# width
		sll $t0, $t0, 2	
		li $a2, 0xff00 	# highlight green
		li $t9, 8	# loop over rows
highlightLoop:	lw $t3, 0($a1)		# inner loop completely unrolled	
		and $t3, $t3, $a2
		sw $t3, 0($a1)
		lw $t3, 4($a1)
		and $t3, $t3, $a2
		sw $t3, 4($a1)
		lw $t3, 8($a1)
		and $t3, $t3, $a2
		sw $t3, 8($a1)
		lw $t3, 12($a1)
		and $t3, $t3, $a2
		sw $t3, 12($a1)
		lw $t3, 16($a1)
		and $t3, $t3, $a2
		sw $t3, 16($a1)
		lw $t3, 20($a1)
		and $t3, $t3, $a2
		sw $t3, 20($a1)
		lw $t3, 24($a1)
		and $t3, $t3, $a2
		sw $t3, 24($a1)
		lw $t3, 28($a1)
		and $t3, $t3, $a2
		sw $t3, 28($a1)
		add $a1, $a1, $t0	# increment address to next row	
		add $t9, $t9, -1		# decrement row count
		bne $t9, $zero, highlightLoop
		jr $ra

######################################################
# processError( bufferInfo error )
# Remaps scores in the entire error buffer. The best score, zero, 
# will be bright green (0xff), and errors bigger than 0x4000 will
# be black.  This is done by shifting the error by 5 bits, clamping
# anything bigger than 0xff and then subtracting this from 0xff.
processError:	lw $t0, 0($a0)     # load error buffer start address
		lw $t2, 4($a0)	   # load width
		lw $t3, 8($a0)	   # load height
		addi $t3, $t3, -7  # height less 8 template lines minus one
		mul $t1, $t2, $t3
		sll $t1, $t1, 2    # error buffer size in bytes	
		add $t1, $t0, $t1  # error buffer end address
		lw $a1, 4($a0)     # load width as column counter
        		addi $a1, $a1, -7  # initialize column count to 7 less than width to account for template
pebLoop:		lw $v0, 0($t0)        # score
		srl $v0, $v0, 5       # reduce magnitude 
		slti $t2, $v0, 0x100  # clamp?
		bne  $t2, $zero, skipClamp
		li $v0, 0xff          # clamp!
skipClamp:	li $t2, 0xff	      # invert to make a score
		sub $v0, $t2, $v0
		sll $v0, $v0, 8       # shift it up into the green
		sw $v0, 0($t0)
		addi $a1, $a1, -1        # decrement column counter	
		bne $a1, $0, pebNotEOL   # Need to skip 8 pixels at the end of each line
		lw $a1, 4($a0)        # load width to reset column counter
        		addi $a1, $a1, -7     # column count for next line is 7 less than width
        		addi $t0, $t0, 28     # skip pointer to end of line (7 pixels x 4 bytes)
pebNotEOL:	add $t0, $t0, 4
		bne $t0, $t1, pebLoop
		jr $ra
