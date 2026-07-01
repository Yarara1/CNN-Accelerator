`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/22/2026 05:07:51 PM
// Design Name: 
// Module Name: cnn_accel_wrapper
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


`timescale 1ns / 1ps

module cnn_accel_wrapper (
    input  wire        clk,

    // External active-low PL reset, for example from a switch/button
    input  wire        ext_resetn,

    // Control signals from MicroBlaze / AXI GPIO / control register
    input  wire        start,
    input  wire        clear_done,

    // Status signals back to MicroBlaze / AXI GPIO / status register
    output reg         busy,
    output reg         done,
    output reg  [3:0]  predicted_digit,
    output reg  [31:0] timer_value
);

    // ------------------------------------------------------------
    // Internal signals
    // ------------------------------------------------------------
    reg start_d;
    wire start_pulse;

    wire core_done;
    wire [3:0] core_predicted_digit;

    reg core_start;
    reg [31:0] cycle_counter;

    // Rising-edge detect for start
    always @(posedge clk or negedge ext_resetn) begin
        if (!ext_resetn) begin
            start_d <= 1'b0;
        end else begin
            start_d <= start;
        end
    end

    assign start_pulse = start & ~start_d;

    // ------------------------------------------------------------
    // Control/status logic
    // ------------------------------------------------------------
    always @(posedge clk or negedge ext_resetn) begin
        if (!ext_resetn) begin
            busy            <= 1'b0;
            done            <= 1'b0;
            predicted_digit <= 4'd0;
            timer_value     <= 32'd0;
            cycle_counter   <= 32'd0;
            core_start      <= 1'b0;
        end else begin
            // Default: start pulse to core is only one clock cycle
            core_start <= 1'b0;

            if (clear_done) begin
                done <= 1'b0;
            end

            // Start CNN accelerator
            if (start_pulse && !busy) begin
                busy          <= 1'b1;
                done          <= 1'b0;
                cycle_counter <= 32'd0;
                timer_value   <= 32'd0;
                core_start    <= 1'b1;
            end

            // Count latency while CNN is running
            if (busy && !core_done) begin
                cycle_counter <= cycle_counter + 32'd1;
            end

            // CNN finished
            if (busy && core_done) begin
                busy            <= 1'b0;
                done            <= 1'b1;
                timer_value     <= cycle_counter;
                predicted_digit <= core_predicted_digit;
            end
        end
    end

    // ------------------------------------------------------------
    // CNN core instance
    // ------------------------------------------------------------
    // IMPORTANT:
    // Rename ports here to match your current cnn_core / conv1_top module.
    // The wrapper assumes your core has:
    // clk, resetn, start, done, predicted_digit
    // ------------------------------------------------------------
    cnn_core u_cnn_core (
        .clk             (clk),
        .resetn          (ext_resetn),
        .start           (core_start),
        .done            (core_done),
        .predicted_digit (core_predicted_digit)
    );

endmodule
