module blinky #(
    parameter int DIVIDER = 2
) (
    input  logic clk,
    input  logic reset,
    output logic led
);
    logic [3:0] count;

    counter counter (
        .clk(clk),
        .reset(reset),
        .count(count)
    );

    assign led = count[DIVIDER];
endmodule
