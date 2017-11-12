module fp_mul(clk,rst,num1,num2,start,num_out,done);
input clk; // input clock
input rst; // input reset
input [31:0] num1;  // 32-bit operand_1 input in IEEE 754 single precision floating point format
input [31:0] num2;  // 32-bit operand_2 input in IEEE 754 single precision floating point format
input start;         // start pulse input to indicate state machine to start processing inputs

output [31:0] num_out;  //  32-bit result output in IEEE 754 single precision floating point format
output done;            // done pulse to indicate completion of addition/subtraction operation and output is valid   

reg done;  // registering done pulse
reg [31:0] num_out; // registering output number

reg [23:0] num1_m, num2_m, out_m;  // registers for storing mantissa of input operands & output, extra 1-bit used for representing implicit MSB of 1, ie the 1 in 1.23456
reg [9:0] num1_exp, num2_exp, out_exp; // registers to store exponents of operands
reg num1_s,num2_s,out_s;  // register to store the sign bits
reg [49:0] temp_product;  // temporary register to hold intermediate product of mantissas , size = 24bit mantissa * 2 + 2 bits for overflow = 50 bits 
reg [25:0] junk; // to store LSB chunk of multiplication that can be discarded

reg [2:0] compute_state;  // state machine state register

// defining states of FSM 
parameter init_var        = 3'd0,
          check_number    = 3'd1,
          multiply_start  = 3'd2,
          multiply_finish = 3'd3,
          normalize       = 3'd4,
          output_result   = 3'd5;
 

always @(negedge clk)
begin

   if (rst) begin  // initialize state of FSM & outputs
	 compute_state <= init_var;
    done <= 0;
    num_out <= 0;
   end
	else begin
		case(compute_state)
	
         init_var:
			begin
         done <= 0; // setting the done bit to zero to reset after coming from last state where done bit is set to 1
         // splitting the input IEEE 754 numbers and registering the mantissa, sign & exponent separately 
				if (start)  // continue execution as soon as start pulse is received
				begin
               // sign bits
					num1_s <= num1[31];
					num2_s <= num2[31];
               // exponent bits, subtracting the bias of 127 from exponent to get the true value
					num1_exp <= num1[30:23]-127;
					num2_exp <= num2[30:23]-127;
               // mantissa bits
               num1_m <= num1[22:0];
					num2_m <= num2[22:0];
					compute_state <= check_number; // go to next state = check_number
				 end
			 end

         check_number:
         begin
         // for very small numbers (if exp = 0 - 127 = -127, adjust exponent to 1 = 1 - 127 = -126, so that we know the number is of type 0.1234 rather than the general 1.1234 format  
				if ($signed(num1_exp) == -127) begin
				num1_exp <= -126;
				end
				else begin
				num1_m[23] <= 1;  // in 1.1234 format = already in correct form
				end
				if ($signed(num2_exp) == -127) begin
				num2_exp <= -126;
				end 
				else begin
				num2_m[23] <= 1;  // in 1.1234 format = already in correct form
				end
				compute_state <= multiply_start; // go to next state = multiply_start
			 end

         multiply_start:
         begin
            out_s <= num1_s ^ num2_s; // sign multiplication using exor
            out_exp <= num1_exp + num2_exp + 1; // just add the exponents and increment by 1 (for accuracy)
            temp_product <= num1_m * num2_m * 4; // normal multiplication of mantissas with 4 (corresponding to the exponent increment == x*4 = left shift by 2 bits = more accuracy as we will drop lesser significant bits in next step)
            compute_state <= multiply_finish; // go to next state = multiply_finish
         end

         multiply_finish:
         begin
         // this state is used to extract needed result from multiplication and discard unneeded bits
            out_m <= temp_product[49:26];  // extract significant result from the multiplication
		      junk <= temp_product[25:0];  // lesser significant bits are not used in output ( can be used for rounding purpose )
            compute_state <= normalize; // go to next state = normalize
         end

         normalize:
         begin
         // normalize the output number if result does not conform to 1.1234 format
         // if MSB bit of mantissa == 0 , i.e. it is in 0.1234 format, adjust/decrement exponent and left shift mantissa till the MSB is 1
            if (out_m[23] == 0) begin 
            out_exp <= out_exp - 1;
			   out_m <= out_m << 1;
            out_m[0] <= 0;
            end
		      else begin
            compute_state <= output_result; // go to next state = output_result
            end
         end

         output_result:
         begin
         // send output in IEEE 754 format
            done <= 1; // set done bit
            num_out[31] <= out_s;
            num_out[30:23] <= out_exp[7:0]+127; // add bias of 127 back for valid IEEE 754 format representation
            num_out[22:0] <= out_m[22:0];
            compute_state <= init_var; // go to initial state = init_var
         end

      endcase
	 end
end
endmodule
