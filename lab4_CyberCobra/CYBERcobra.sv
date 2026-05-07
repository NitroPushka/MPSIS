module CYBERcobra (
  input  logic         clk_i,
  input  logic         rst_i,
  input  logic [15:0]  sw_i,
  output logic [31:0]  out_o
);
	
	logic[31:0] PC;
	logic[31:0] next_PC;
	logic[31:0] instruction;
	logic[31:0] RD1;
	logic[31:0] RD2;
	logic[31:0] WD;
	logic[31:0] alu_result;
	logic[31:0] offset_const;
	logic flag;
	
	always_comb begin
		case((instruction[30] & flag) | instruction[31])
			1'b0: offset_const = 32'd4;
			1'b1: offset_const = {{22{instruction[12]}}, instruction[12:5], 2'b0}; // shift left 4 = *2 binary code
			
			// PC = PC + offset*4
		endcase
	end
	
	fulladder32 adder(
		.a_i(PC),
		.b_i(offset_const),
		.carry_i(1'b0),
		.carry_o(),
		.sum_o(next_PC)
	);

// проверяем reset
	always_ff @(posedge clk_i) begin
		if (rst_i == 1) begin
			PC <= 32'd0;
		end
		else begin 
			PC <= next_PC;
		end
	end
	
	instr_mem imem(
		.read_addr_i(PC),
		.read_data_o(instruction)
	);
	
	alu alu(
		.a_i(RD1),
		.b_i(RD2),
		.alu_op_i(instruction[27:23]),
		.flag_o(flag),
		.result_o(alu_result)
	);

	register_file reg_file(
		.clk_i(clk_i),
		.write_enable_i(~(instruction[30] | instruction[31])),
		.write_addr_i(instruction[4:0]),
		.read_addr1_i(instruction[22:18]),
		.read_addr2_i(instruction[17:13]),
		.write_data_i(WD),
		.read_data1_o(RD1),
		.read_data2_o(RD2)
	);

	always_comb begin
		case(instruction[29:28])
			2'd0: WD = {{9{instruction[27]}}, instruction[27:5]};
			2'd1: WD = alu_result;
			2'd2: WD = {{16{sw_i[15]}}, sw_i[15:0]};
			default: WD = 32'd0; 
		endcase
	end
	
	assign out_o = RD1;

endmodule
