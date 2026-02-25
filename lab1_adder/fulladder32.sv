module fulladder32(
    input  logic [31:0] a_i,
    input  logic [31:0] b_i,
    input  logic        carry_i,
    output logic [31:0] sum_o,
    output logic        carry_o
);

logic carry01;
logic carry12;
logic carry23;
logic carry34;
logic carry45;
logic carry56;
logic carry67;

fulladder4 adder0(
.a_i(a_i[3:0]),
.b_i(b_i[3:0]),
.carry_i(carry_i),
.carry_o(carry01),
.sum_o(sum_o[3:0])
);

fulladder4 adder1(
.a_i(a_i[7:4]),
.b_i(b_i[7:4]),
.carry_i(carry01),
.carry_o(carry12),
.sum_o(sum_o[7:4])
);

fulladder4 adder2(
.a_i(a_i[11:8]),
.b_i(b_i[11:8]),
.carry_i(carry12),
.carry_o(carry23),
.sum_o(sum_o[11:8])
);

fulladder4 adder3(
.a_i(a_i[15:12]),
.b_i(b_i[15:12]),
.carry_i(carry23),
.carry_o(carry34),
.sum_o(sum_o[15:12])
);

fulladder4 adder4(
.a_i(a_i[19:16]),
.b_i(b_i[19:16]),
.carry_i(carry34),
.carry_o(carry45),
.sum_o(sum_o[19:16])
);

fulladder4 adder5(
.a_i(a_i[23:20]),
.b_i(b_i[23:20]),
.carry_i(carry45),
.carry_o(carry56),
.sum_o(sum_o[23:20])
);

fulladder4 adder6(
.a_i(a_i[27:24]),
.b_i(b_i[27:24]),
.carry_i(carry56),
.carry_o(carry67),
.sum_o(sum_o[27:24])
);

fulladder4 adder7(
.a_i(a_i[31:28]),
.b_i(b_i[31:28]),
.carry_i(carry67),
.carry_o(carry_o),
.sum_o(sum_o[31:28])
);

endmodule
