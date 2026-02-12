module fulladder4(
  input  logic [3:0] a_i,
  input  logic [3:0] b_i,
  input  logic       carry_i,
  output logic [3:0] sum_o,
  output logic       carry_o
);
logic carry_o1;
logic carry_o2;
logic carry_o3;

fulladder adder0(
    .a_i(a_i[0]),
    .b_i(b_i[0]),
    .carry_i(carry_i),
    
    .carry_o(carry_o1),
    .sum_o(sum_o[0])
);

fulladder adder1(
    .a_i(a_i[1]),
    .b_i(b_i[1]),
    .carry_i(carry_o1),
    
    .carry_o(carry_o2),
    .sum_o(sum_o[1])
);

fulladder adder2(
    .a_i(a_i[2]),
    .b_i(b_i[2]),
    .carry_i(carry_o2),
    
    .carry_o(carry_o3),
    .sum_o(sum_o[2])
);

fulladder adder3(
    .a_i(a_i[3]),
    .b_i(b_i[3]),
    .carry_i(carry_o3),
    .carry_o(carry_o),
    .sum_o(sum_o[3])
);

endmodule