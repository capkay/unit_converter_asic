module converter (clk, rst, number_in, valid_in,type, select, reverse, number_out, valid_out);
input clk, rst;  // clock and reset input
input reverse;   // input to change conversion from/to Imperial/metric
input valid_in;  // input to indicate start of conversion and valid input entered 
input [31:0] number_in; //32-bit input number in IEEE 754 single precision floating point format
input [1:0]  type; //2-bit input to select type of conversion: length, mass, volume & temperature
input [2:0]  select; //3-bit input to select various conversion modes between different Imperial/metric units

output [31:0] number_out;  //32-bit output number in IEEE 754 single precision floating point format
output valid_out;  // output indicates conversion has finished and number_out is also valid 

reg [31:0] conv_factor;  //32-bit register which holds the various multiplicative conversion factors used in the conversion process
reg [31:0] conv_add;   //32-bit register which holds the various additive conversion factors used in the conversion process
wire m_valid_in,m_valid_out; // wire for multiplier valid_id & valid_out
wire a_valid_in,a_valid_out; // wire for adder valid_id & valid_out
wire [31:0] m_number_in,m_number_out; // wire to connect number_in & number_out for the adder
wire [31:0] a_number_in,a_number_out; // wire to connect number_in & number_out for the multiplier

//--------- sub-module instantiations ----------------//
fp_mul fp_mult(clk,rst,m_number_in,conv_factor,m_valid_in,m_number_out,m_valid_out); // multiplier instantiation
fp_add_sub fp_add(clk,rst,a_number_in,conv_add,a_valid_in,a_number_out,a_valid_out); // adder instantiation
//----------------------------------- ----------------//

//--------- control/mux logic to route inputs/outputs for proper conversion----------------//
// if (conversion_type != temperature), route system inputs (number_in & valid_in) to multiplier inputs as it is normal multiplicative conversion, else if (!reverse), connect adder outputs to multiplier inputs when converting temp from F to C where adder is used first,  otherwise connect system inputs to multiplier inputs as reverse temperature conversion needs multiplier first.
assign m_number_in = (type != 2'b11)? number_in   : (!reverse) ? a_number_out : number_in;
assign m_valid_in  = (type != 2'b11)? valid_in    : (!reverse) ? a_valid_out  : valid_in ;

// if (conversion_type != temperature), adder inputs are tied to 0 as we'll not use adder, else if (!reverse), connect system inputs to adder inputs as we convert temperature from F to C and adder is needed first, otherwise connect multiplier outputs to adder inputs as we use multiplier first for C to F conversion.
assign a_number_in = (type != 2'b11)? 32'h0       : (!reverse) ? number_in    : m_number_out;
assign a_valid_in  = (type != 2'b11)? 1'b0        : (!reverse) ? valid_in     : m_valid_out;

// if (conversion_type != temperature), system outputs are connected to multiplier outputs as it is normal multiplicative conversion, else if (!reverse), connect system outputs to multiplier outputs as we convert temperature from F to C and multiplier is done last, otherwise connect system outputs to adder outputs as we use adder last for C to F conversion.
assign number_out  = (type != 2'b11)? m_number_out: (!reverse) ? m_number_out : a_number_out;
assign valid_out   = (type != 2'b11)? m_valid_out : (!reverse) ? m_valid_out  : a_valid_out ;
//----------------------------------- ----------------//

always @(negedge clk)
  begin
      if (rst) begin  // upon reset, initialize conversion factors to 0
         conv_factor <= 0;
         conv_add    <= 0;
      end else 
      begin
  if(type == 2'b00)  // length conversion when type = 0
      begin
      case (select)  // type of sub-conversion based on select. conversion factors are inverse when reverse is high 
         0: conv_factor <= (!reverse) ? 32'h41cb3333 : 32'h3d214270; // 1 inch [in] = 25.4 mm , 1 mm = 0.03937 in
         1: conv_factor <= (!reverse) ? 32'h40228f5c : 32'h3ec9930c; // 1 inch = 2.54 cm , 1 cm = 0.3937  in
         2: conv_factor <= (!reverse) ? 32'h3cd013a9 : 32'h421d7afb; // 1 inch = 0.0254 m, 1 m  = 39.3701 in
         3: conv_factor <= (!reverse) ? 32'h3e9c0ebf : 32'h4051f944; // 1 foot [ft, 12 in] = 0.3048 m, 1 m  = 3.280839 in
         4: conv_factor <= (!reverse) ? 32'h399fcd90 : 32'h454d0d70; // 1 foot = 0.0003048 km, 1 km = 3280.839895 in
         5: conv_factor <= (!reverse) ? 32'h3f6a161e : 32'h3f8bfb83; // 1 yard [yd, 3 ft] = 0.9144 m, 1 m  = 1.093613 yd
         6: conv_factor <= (!reverse) ? 32'h3a6fb458 : 32'h4488b3a0; // 1 yard = 0.0009144 km, 1 km = 1093.613298 yd
         7: conv_factor <= (!reverse) ? 32'h3fcdfd8b : 32'h3f1f1349; // 1 mile [1760 yd]  = 1.6093 km, 1 km = 0.621388 mile
      endcase
      end
   else if(type == 2'b01) // Mass conversion when type = 1
         begin
            case (select)  // type of sub-conversion based on select. conversion factors are inverse when reverse is high
               0: conv_factor <= (!reverse) ? 32'h46dd7c00 : 32'h3813f27b; // 1 ounce [oz] = 28350 mg , 1 mg = 0.00003527336 oz
               1: conv_factor <= (!reverse) ? 32'h41e2cccd : 32'h3d107acc; // 1 ounce [oz] = 28.35  g , 1 g  = 0.03527336 oz
               2: conv_factor <= (!reverse) ? 32'h43e2cccd : 32'h3b107ab7; // 1 pound [lb, 16 oz] = 453.6  g , 1 g  = 0.00220458 lb 
               3: conv_factor <= (!reverse) ? 32'h3ee83e42 : 32'h400d17ee; // 1 pound [lb, 16 oz] = 0.4536 kg, 1 kg = 2.2045856 lb
               4: conv_factor <= (!reverse) ? 32'h40cb35a8 : 32'h3e214091; // 1 stone [14 lb] = 6.3503 kg, 1 kg = 0.15747286 stone 
               5: conv_factor <= (!reverse) ? 32'h424b353f : 32'h3ca140c2; // 1 hundredweight [cwt, 112 lb] = 50.802 kg, 1 kg = 0.0196842 cwt 
               6: conv_factor <= (!reverse) ? 32'h4462cccd : 32'h3a907ab7; // 1 short ton = 907.2 kg , 1 kg = 0.00110229 short ton
               7: conv_factor <= (!reverse) ? 32'h3f683e42 : 32'h3f8d17ee; // 1 short ton = 0.9072 metric ton, 1 metric ton = 1.10229276
            endcase
         end
   else if(type == 2'b10) // Volume conversion when type = 2
         begin
            case (select)  // type of sub-conversion based on select. conversion factors are inverse when reverse is high
               0: conv_factor <= (!reverse) ? 32'h41831893 : 32'h3d79f341; // 1 cu inch [in3] = 16.387 cm3, 1 cm3 = 0.061023 in3
               1: conv_factor <= (!reverse) ? 32'h3ce7ff58 : 32'h420d3e31; // 1 cu foot [ft3] = 0.02832 m3 , 1 m3  = 35.310734 ft3
               2: conv_factor <= (!reverse) ? 32'h41ec978d : 32'h3d0a7f80; // 1 fluid ounce [fl oz] = 29.574 milliliter [ml], 1 ml = 0.033813 fl oz 
               3: conv_factor <= (!reverse) ? 32'h3cf2452c : 32'h42074102; // 1 fluid ounce = 0.029574 liter [l], 1 l = 33.813484 fl oz
               4: conv_factor <= (!reverse) ? 32'h43ec999a : 32'h3b0a7eca; // 1 pint [16 fl oz] = 473.2 ml, 1 ml = 0.00211327 pint 
               5: conv_factor <= (!reverse) ? 32'h3ef24745 : 32'h40073fd5; // 1 pint = 0.4732 l, 1 l = 2.113271 pint
               6: conv_factor <= (!reverse) ? 32'h407243fe : 32'h3e8741a8; // 1 gallon [231 in3] = 3.7854 l, 1 l = 0.2641728 gallon
               7: conv_factor <= (!reverse) ? 32'h3b781479 : 32'h43841621; // 1 gallon = 0.0037854 kiloliter [kl], 1 kl = 264.17288 gallon
            endcase
         end
   else if(type == 2'b11) // temperature conversion when type = 3
         begin
         // F to C --> Add (-32), then multiply by 5/9=0.55555555
         // C to F --> multiply by 9/5=1.8, then add 32 
            conv_add    <= (!reverse) ? 32'hc2000000 : 32'h42000000; // -32 , 32 
            conv_factor <= (!reverse) ? 32'h3f0e38e4 : 32'h3fe66666; // 5/9 = 0.5555556, 9/5=1.8 
         end
   end
   end

endmodule  // converter
