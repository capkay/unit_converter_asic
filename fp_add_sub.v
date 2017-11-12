module fp_add_sub(clk,rst,num1,num2,start,num_out,done);
input clk;  // input clock
input rst;  // input reset
input [31:0] num1;  // 32-bit operand_1 input in IEEE 754 single precision floating point format
input [31:0] num2;  // 32-bit operand_2 input in IEEE 754 single precision floating point format
input start;         // start pulse input to indicate state machine to start processing inputs

output [31:0] num_out;  //  32-bit result output in IEEE 754 single precision floating point format
output done;            // done pulse to indicate completion of addition/subtraction operation and output is valid   

reg done;  // registering done pulse
reg [31:0] num_out; // registering output number

reg [23:0] num1_m, num2_m;  // registers for storing mantissa of input operands, extra 1-bit used for representing implicit MSB of 1, ie the 1 in 1.23456
reg [23:0] out_m; // register to store mantissa of output
reg [9:0] num1_exp, num2_exp, out_exp; // registers to store exponents of operands
reg num1_s, num2_s, out_s;  // register to store the sign bits
reg [24:0] temp_sum_m;  // temporary register to hold intermediate sum of mantissas, extra bit w.r.t to num1_m/num2_m to hold carry bit 

reg [2:0] compute_state;  // state machine state register

// defining states of FSM 
parameter init_var      = 3'd0,  
          balance       = 3'd1,
          start_adding  = 3'd2,
          check_overflow= 3'd3,
          normalize     = 3'd4,
          output_result = 3'd5;

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
            if(start)  // continue execution as soon as start pulse is received
            begin
               // sign bits
               num1_s <= num1[31];
               num2_s <= num2[31];
               // exponent bits, subtracting the bias of 127 from exponent to get the true value
               num1_exp <= num1[30:23]-127;
               num2_exp <= num2[30:23]-127;
               // mantissa bits, setting MSB for the implicit one before the decimal point 
               num1_m <= {1'b1,num1[22:0]};
               num2_m <= {1'b1,num2[22:0]};
               compute_state <= balance; // go to next state = balance
            end
         end
         
         balance:
         begin
         // exponent of smaller number should match the exponent of bigger number , this state is looped until exponent of smaller number matches the exponent of larger number
         // compare exponents to find the bigger number 
            if ($signed(num1_exp) > $signed(num2_exp)) begin  // if num1 > num2
               num2_exp <= num2_exp + 1; // increase exponent of num2
               num2_m <= num2_m >> 1;    // right shift the mantissa of num2 by 1-bit
               end else if ($signed(num1_exp) < $signed(num2_exp)) begin // if num1 < num2 , repeat above process for num1
               num1_exp <= num1_exp + 1;
               num1_m <= num1_m >> 1;
               end else begin // exponents are same, go to next state = start_adding
               compute_state <= start_adding;
               end
         end

         start_adding:
         begin
         //addition of mantissas based on sign
              out_exp <= num1_exp; // num1 exponent matches exponent of larger number, so assign it to the output exponent
              if (num1_s == num2_s) begin // same sign implies addition + (+) +, or - (+) -
              temp_sum_m <= num1_m + num2_m; // sum of mantissas
              out_s <= num1_s; // taking sign bit
              end else begin
              // numbers not having same sign, implies subtraction. subtract smaller number from bigger number and take sign of the larger number
              if (num1_m >= num2_m) begin 
              temp_sum_m <= num1_m - num2_m;
              out_s <= num1_s;
              end else begin
              temp_sum_m <= num2_m - num1_m;
              out_s <= num2_s;
                       end
                  end
              compute_state <= check_overflow;  // go to next state = check_overflow
         end

         check_overflow:
         begin
         // if overflow happened in addition, the MSB bit would hold the carry bit
         // if carry bit is set, take appropriate mantissa and increase exponent by 1
              if (temp_sum_m[24]) begin
              out_m <= temp_sum_m[24:1];
              out_exp <= out_exp + 1;
              end else begin // no overflow occured, take mantissa as it is
              out_m <= temp_sum_m[23:0];
              end
              compute_state <= normalize;  // go to next state = normalize
         end

         normalize:
         begin
         // normalize = bring the implicit 1 to the MSB of the mantissa for the output and adjust the exponent if it's not already there, else go to next state
               if (out_m[23] == 0 && $signed(out_exp) > -126) begin
               out_exp <= out_exp - 1;
               out_m <= out_m << 1;
               end else begin 
               compute_state <= output_result; // go to next state = output_result 
               end
         end

         output_result:
         begin
         // send output in IEEE 754 format
               done <= 1;  // set done bit
               num_out[31] <= out_s;
               num_out[30:23] <= out_exp[7:0]+127; // add bias of 127 back for valid IEEE 754 format representation
               num_out[22:0] <= out_m[22:0];
               compute_state <= init_var; // go to intital state
         end

      endcase
   end
end
endmodule
