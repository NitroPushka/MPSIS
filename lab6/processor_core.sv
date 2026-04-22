module processor_core (
  input  logic        clk_i,
  input  logic        rst_i,

  input  logic        stall_i,
  input  logic [31:0] instr_i,
  input  logic [31:0] mem_rd_i,
  input  logic        irq_req_i,

  output logic [31:0] instr_addr_o,
  output logic [31:0] mem_addr_o,
  output logic [ 2:0] mem_size_o,
  output logic        mem_req_o,
  output logic        mem_we_o,
  output logic [31:0] mem_wd_o,
  output logic        irq_ret_o
);

  import decoder_pkg::*;

  logic[31:0] imm_I;
  logic[31:0] imm_U;
  logic[31:0] imm_S;
  logic[31:0] imm_B;
  logic[31:0] imm_J;
  logic[31:0] imm_Z;

  assign imm_I = {{20{instr_i[31]}}, instr_i[31:20]};
  assign imm_U = {instr_i[31:12], 12'h000};
  assign imm_S = {{20{instr_i[31]}}, instr_i[31:25], instr_i[11:7]};
  assign imm_B = {{19{instr_i[31]}}, instr_i[31], instr_i[7], instr_i[30:25], instr_i[11:8], 1'b0};
  assign imm_J = {{11{instr_i[31]}}, instr_i[31], instr_i[19:12], instr_i[20], instr_i[30:21], 1'b0};
  assign imm_Z = {27'd0, instr_i[19:15]};

  logic ill_instr;
  logic trap;
  logic irq;
  assign trap = irq | ill_instr;

  logic[31:0] a_i;
  logic[31:0] b_i;

  logic[1:0] a_sel;
  logic[2:0] b_sel;
  logic[1:0] wb_sel;
  logic[4:0] alu_op;
  logic gpr_we;

  logic alu_flag;
  logic[31:0] alu_result;

  logic[31:0] rd1;
  logic[31:0] rd2;
  logic[31:0] wb_data;
  logic we;

  assign we = ~(trap | stall_i) & gpr_we;

  logic branch;
  logic jal;
  logic jalr;
  logic[31:0] jalr_sum;
  logic[31:0] b_or_j;
  assign b_or_j = branch? imm_B: imm_J;
  logic[31:0] jb_or_4;
  assign jb_or_4 = ((alu_flag & branch) | jal)? b_or_j: 32'd4;
  logic[31:0] bj4_sum;

  logic[31:0] PC;
  logic[31:0] next_PC;
  logic[31:0] jalr_or_bj4;
  assign jalr_or_bj4 = jalr? {jalr_sum[31:1], 1'b0}: bj4_sum;
  logic[31:0] jalr_or_bj4_or_mtvec;
  logic[31:0] mtvec;
  assign jalr_or_bj4_or_mtvec = trap? mtvec: jalr_or_bj4;
  logic[31:0] mepc;
  logic mret;
  assign next_PC = mret? mepc: jalr_or_bj4_or_mtvec;
  always_ff @(posedge clk_i) begin
    if(~stall_i) begin
      if (rst_i == 1) begin
        PC <= 32'd0;
      end
		  else begin
        PC <= next_PC;
      end
    end
	end

  assign mem_wd_o = rd2;
  assign mem_addr_o = alu_result;
  assign instr_addr_o = PC;
  logic mem_req;
  assign mem_req_o = ~trap & mem_req;
  logic mem_we;
  assign mem_we_o = ~trap & mem_we;

  logic[31:0] csr_wd;
  logic[2:0] csr_op;
  logic csr_we;

  logic[31:0] mie;

  logic[31:0] irq_cause;
  logic[31:0] mcause;
  assign mcause = ill_instr? 32'h0000_0002: irq_cause;

  always_comb begin
    case(a_sel)
      OP_A_RS1: a_i = rd1;
      OP_A_CURR_PC: a_i = PC;
      OP_A_ZERO: a_i = 32'd0;
    endcase
  end

  always_comb begin
    case(b_sel)
      OP_B_RS2: b_i = rd2;
      OP_B_IMM_I: b_i = imm_I;
      OP_B_IMM_U: b_i = imm_U;
      OP_B_IMM_S: b_i = imm_S;
      OP_B_INCR: b_i = 32'd4;
    endcase
  end

  always_comb begin
    case(wb_sel)
      WB_EX_RESULT: wb_data = alu_result;
      WB_LSU_DATA: wb_data = mem_rd_i;
      WB_CSR_DATA: wb_data = csr_wd;
    endcase
  end

  decoder main_decoder(.fetched_instr_i(instr_i), .a_sel_o(a_sel), .b_sel_o(b_sel), .alu_op_o(alu_op), .csr_op_o(csr_op),
  .csr_we_o(csr_we), .mem_req_o(mem_req), .mem_we_o(mem_we), .mem_size_o(mem_size_o), .gpr_we_o(gpr_we), .wb_sel_o(wb_sel), .illegal_instr_o(ill_instr),
  .branch_o(branch), .jal_o(jal), .jalr_o(jalr), .mret_o(mret));

  register_file register(.clk_i(clk_i), .write_enable_i(we), .write_addr_i(instr_i[11:7]), .read_addr1_i(instr_i[19:15]),
  .read_addr2_i(instr_i[24:20]), .write_data_i(wb_data), .read_data1_o(rd1), .read_data2_o(rd2));

  alu ALU(.a_i(a_i), .b_i(b_i), .alu_op_i(alu_op), .flag_o(alu_flag), .result_o(alu_result));

  fulladder32 adder32_bj(.a_i(PC), .b_i(jb_or_4), .carry_i(1'b0), .sum_o(bj4_sum), .carry_o());

  fulladder32 adder32_jalr(.a_i(rd1), .b_i(imm_I), .carry_i(1'b0), .sum_o(jalr_sum), .carry_o());

  csr_controller control_status_registers(.clk_i(clk_i), .rst_i(rst_i), .trap_i(trap), .opcode_i(csr_op),
   .addr_i(instr_i[31:20]), .pc_i(PC), .mcause_i(mcause), .rs1_data_i(rd1), .imm_data_i(imm_Z), .write_enable_i(csr_we),
   .read_data_o(csr_wd), .mie_o(mie), .mepc_o(mepc), .mtvec_o(mtvec));

  interrupt_controller irq_controller(.clk_i(clk_i), .rst_i(rst_i), .exception_i(ill_instr),
    .irq_req_i(irq_req_i), .mie_i(mie[16]), .mret_i(mret), .irq_ret_o(irq_ret_o), .irq_cause_o(irq_cause), .irq_o(irq));

endmodule