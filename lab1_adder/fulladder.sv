module fulladder(
  input  logic a_i,
  input  logic b_i,
  input  logic carry_i,
  output logic sum_o,
  output logic carry_o
);

logic AxorB;
logic AxorBxorCarry;
logic AandB;
logic AandCarry;
logic AandBorAandCarry;
logic BandCarry;


assign AxorB = a_i ^ b_i;

assign AxorBxorCarry = carry_i ^ AxorB;

assign AandB = a_i & b_i;

assign AandCarry = a_i & carry_i;

assign AandBorAandCarry = AandB | AandCarry;

assign BandCarry = carry_i & b_i;

assign carry_o = AandBorAandCarry | BandCarry;
assign sum_o = AxorBxorCarry;

endmodule