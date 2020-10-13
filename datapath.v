module fetch (input zero, rst, clk, brancheq, branchlt, branchgte, neg,
              input [31:0] sigext, 
              output [31:0] inst,
              input branchnc);
  
  wire [31:0] pc, pc_4, new_pc;

  assign pc_4 = 4 + pc; // pc+4  Adder
  assign new_pc = ((brancheq & zero) 
                || (branchlt & neg) 
                || (branchgte & !neg)
                || branchnc) 
                ? pc_4 + sigext : pc_4; // new PC Mux

  PC program_counter(new_pc, clk, rst, pc);

  reg [31:0] inst_mem [0:31];

  assign inst = inst_mem[pc[31:2]];

  initial begin

    inst_mem[0] <= 32'h00000000; // nop
    inst_mem[1] <= 32'h00500113; // addi x2, x0, 5  ok
    inst_mem[2] <= 32'h00210233; // add  x4, x2, x2  ok
    inst_mem[3] <= 32'h00410287; // lwi x5, x2, x4 = lwi x5, 5, 10
    inst_mem[4] <= 32'hE3B392B7; // lui 
    inst_mem[5] <= 32'h20E113;   // ori x2, x1, 2 
    inst_mem[6] <= 32'h221293;    // slli x5, x4, 2 
    inst_mem[7] <= 32'h520002;    // swap x4 x5

  end
  
endmodule

module PC (input [31:0] pc_in, input clk, rst, output reg [31:0] pc_out);

  always @(posedge clk) begin
    pc_out <= pc_in;
    if (~rst)
      pc_out <= 0;
  end

endmodule

module decode (input [31:0] inst, writedata, 
               input clk, 
               output [31:0] data1, data2, ImmGen, 
               output alusrc, memread, memwrite, memtoreg, 
               output ssalu, ssmemadr, ssmemwrite,
               output brancheq, branchlt, branchgte,
               output [1:0] aluop, 
               output [9:0] funct,
               output branchnc);
  
  wire brancheq, branchlt, branchgte;
  wire branchnc;
  wire ssalu, ssmemadr, ssmemwrite;
  wire memread, memtoreg, MemWrite, alusrc, regwrite;
  wire writeimm;
  wire [1:0] aluop; 
  wire [4:0] writereg, rs1, rs2, rd;
  wire [6:0] opcode;
  wire [2:0] funct3;
  wire [9:0] funct;
  wire [31:0] ImmGen;

  assign opcode = inst[6:0];
  assign rs1    = inst[19:15];
  assign rs2    = inst[24:20];
  assign rd     = inst[11:7];
  assign funct = {inst[31:25],inst[14:12]};
  assign funct3 = {inst[14:12]};

  ControlUnit control (opcode, inst, funct3, alusrc, 
                       memtoreg, regwrite, memread, memwrite, 
                       ssalu, ssmemadr, ssmemwrite,
                       brancheq, branchlt, branchgte, aluop, ImmGen, writeimm, branchnc);
  
  Register_Bank Registers (clk, regwrite, rs1, rs2, rd, writedata, data1, data2, ImmGen, writeimm); 

endmodule

module ControlUnit (input [6:0] opcode, 
                    input [31:0] inst,
                    input [2:0] funct3,
                    output reg alusrc, memtoreg, regwrite, memread, memwrite,
                    output reg ssalu, ssmemadr, ssmemwrite,
                    output reg brancheq, branchlt, branchgte,
                    output reg [1:0] aluop, 
                    output reg [31:0] ImmGen,
                    output reg writeimm,
                    output reg branchnc);

  always @(opcode) begin
    alusrc   <= 0;
    memtoreg <= 0;
    regwrite <= 0;
    memread  <= 0;
    memwrite <= 0;
    ssalu <= 0;
    ssmemadr <= 0;
    ssmemwrite <= 0;
    brancheq <= 0;
    branchlt <= 0;
    branchgte <= 0;
    aluop    <= 0;
    ImmGen   <= 0; 
    writeimm <= 0;
    branchnc <= 0;
    case(opcode) 
      7'b0110011: begin // R type == 51
        regwrite <= 1;
        aluop    <= 2;
        case (funct5)
          5'b00001: begin
            regwrite <= 1;
            memwrite <= 1;
            memread  <= 0;
          end
        endcase
      end
      7'b1100011: begin // beq == 99
        case (funct3)
          3'b000: begin
            brancheq <= 1;
            aluop    <= 1;
            ImmGen   <= {{19{inst[31]}},inst[31],inst[7],inst[30:25],inst[11:8],1'b0};
          end
          3'b100: begin
            branchlt <= 1;
            aluop    <= 1;
            ImmGen   <= {{19{inst[31]}},inst[31],inst[7],inst[30:25],inst[11:8],1'b0};
          end
          3'b101: begin
            branchgte <= 1;
            brancheq <= 1;
            aluop    <= 1;
            ImmGen   <= {{19{inst[31]}},inst[31],inst[7],inst[30:25],inst[11:8],1'b0};
          end
        endcase
      end
      7'b0010011: begin // addi/ori/slli == 19
        case (funct3)
          3'b000: begin //addi
            alusrc   <= 1;
            regwrite <= 1;
            ImmGen   <= {{20{inst[31]}},inst[31:20]};
          end
          3'b110: begin //ori
            alusrc   <= 1;
            regwrite <= 1;
            writeimm <= 1;
            ImmGen   <= {{20{inst[31]}},inst[31:20]};
          end
          3'b001: begin //slli
            alusrc   <= 1;
            regwrite <= 1;
            writeimm <= 1;
            ImmGen <= {inst[24:20], 1'b0};
          end
        endcase
      end  
      7'b0000011: begin // lw == 3
        alusrc   <= 1;
        memtoreg <= 1;
        regwrite <= 1;
        memread  <= 1;
        ImmGen   <= {{20{inst[31]}},inst[31:20]};
      end
      7'b0000111: begin // lwi
        memtoreg <= 1;
        regwrite <= 1;
        memread <= 1;
        aluop <= 0;
      end
      7'b0110111: begin // lui
        regwrite <= 1;
        writeimm <= 1;
        ImmGen <= {inst[31:12], 12'b0};
      end
      7'b1101111: begin // jump
        branchnc <= 1;
        ImmGen   <= {{12{inst[31]}},inst[19:12],inst[31:20]};
      end
      7'b0100011: begin // sw == 35
        alusrc   <= 1;
        memwrite <= 1;
        ImmGen   <= {{20{inst[31]}},inst[31:25],inst[11:7]};
      end
      7'b1110011: begin // ss = 115
        ssalu <= 1;
        ssmemadr <= 1;
        ssmemwrite <= 1;
        memwrite <= 1;
        ImmGen   <= {{20{inst[31]}},inst[31:25],inst[11:7]};
      end
    endcase
  end

endmodule 

module Register_Bank (input clk, regwrite, 
                      input [4:0] read_reg1, read_reg2, writereg, 
                      input [31:0] writedata, 
                      output [31:0] read_data1, read_data2,
                      input [31:0] ImmGen,
                      input writeimm);

  integer i;
  reg [31:0] memory [0:31]; // 32 registers de 32 bits cada

  // fill the memory
  initial begin
    for (i = 0; i <= 31; i++) 
      memory[i] <= i;
  end

  assign read_data1 = (regwrite && read_reg1==writereg) ? writedata : memory[read_reg1];
  assign read_data2 = (regwrite && read_reg2==writereg) ? writedata : memory[read_reg2];
	
  always @(posedge clk) begin
    if (regwrite)
        if (writeimm)
            memory[writereg] <= ImmGen;
        else
            memory[writereg] <= writedata;
  end
  
endmodule

module execute (input [31:0] in1, in2, ImmGen, 
                input alusrc, 
                input [1:0] aluop, 
                input [9:0] funct,
                input ssalu,
                output zero, 
                output [31:0] aluout,
                output neg);

  wire [31:0] alu_B;
  wire [31:0] alu_A;
  wire [3:0] aluctrl;
  
  assign alu_B = (alusrc) ? ImmGen : in2;
  assign alu_A = (ssalu) ? ImmGen : in1;

  //Unidade Lógico Aritimética
  ALU alu (aluctrl, alu_A, alu_B, aluout, zero, neg);

  alucontrol alucontrol (aluop, funct, aluctrl);

endmodule

module alucontrol (input [1:0] aluop, input [9:0] funct, output reg [3:0] alucontrol);
  
  wire [7:0] funct7;
  wire [2:0] funct3;

  assign funct3 = funct[2:0];
  assign funct7 = funct[9:3];

  always @(aluop) begin
    case (aluop)
      0: alucontrol <= 4'd2; // ADD to SW and LW
      1: alucontrol <= 4'd6; // SUB to branch
      default: begin
        case (funct3)
          0: alucontrol <= (funct7 == 0) ? /*ADD*/ 4'd2 : /*SUB*/ 4'd6; 
          2: alucontrol <= 4'd7; // SLT
          4: alucontrol <= (funct7 == 99) ? /*SLT*/ 4'd6 : /*XOR*/ 4'd4;
          6: alucontrol <= 4'd1; // OR
          //39: alucontrol <= 4'd12; // NOR
          7: alucontrol <= 4'd0; // AND
          default: alucontrol <= 4'd15; // Nop
        endcase
      end
    endcase
  end
endmodule

module ALU (input [3:0] alucontrol, 
            input [31:0] A, B, 
            output reg [31:0] aluout, 
            output zero,
            output neg);
  
  assign zero = (aluout == 0); // Zero recebe um valor lógico caso aluout seja igual a zero.
  assign neg = (A < B);   // Neg recebe um valor lógico caso aluout seja negativo.
  
  always @(alucontrol, A, B) begin
      case (alucontrol)
        0: aluout <= A & B; // AND
        1: aluout <= A | B; // OR
        2: aluout <= A + B; // ADD
        4: aluout <= A ^ B; // XOR
        6: aluout <= A - B; // SUB
        //7: aluout <= A < B ? 32'd1:32'd0; //SLT
        //12: aluout <= ~(A | B); // NOR
      default: aluout <= 0; //default 0, Nada acontece;
    endcase
  end
endmodule

module memory (input [31:0] aluout, data1, writedataSW,
               input memread, memwrite, clk, 
               input ssmemadr, ssmemwrite,
               output [31:0] readdata);

  integer i;
  reg [31:0] memory [0:127]; 
	wire [31:0] writedata;

  
  // fill the memory
  initial begin
    for (i = 0; i <= 127; i++) 
      memory[i] <= i;
  end

  assign readdata = (memread) ? memory[aluout[31:2]] : 0;
  assign writedata = (ssmemwrite) ? aluout : writedataSW;

  always @(posedge clk) begin
    if (memwrite & ssmemadr)
      memory[data1[31:2]] <= writedata;
    if (memwrite & !ssmemadr)
      memory[aluout[31:2]] <= writedata;
	end
endmodule

module writeback (input [31:0] aluout, readdata, input memtoreg, output reg [31:0] write_data);
  always @(memtoreg) begin
    write_data <= (memtoreg) ? readdata : aluout;
  end
endmodule

// TOP -------------------------------------------
module mips (input clk, rst, output [31:0] writedata);
  
  wire [31:0] inst, sigext, data1, data2, aluout, readdata;
  wire zero, memread, memwrite, memtoreg, branch, alusrc;
  wire ssalu, ssmemadr, ssmemwrite;
  wire branchnc;
  wire [9:0] funct;
  wire [1:0] aluop;
  
  // FETCH STAGE
  fetch fetch (zero, rst, clk, brancheq, branchlt, branchgte, neg, sigext, inst, branchnc);
  
  // DECODE STAGE
  decode decode (inst, writedata, clk, data1, data2, sigext, alusrc, 
                 memread, memwrite, memtoreg, 
                 ssalu, ssmemadr, ssmemwrite, 
                 brancheq, branchlt, branchgte, aluop, funct, branchnc);   
  
  // EXECUTE STAGE
  execute execute (data1, data2, sigext, alusrc, aluop, funct, ssalu, zero, aluout, neg);

  // MEMORY STAGE
  memory memory (aluout, data1, data2, memread, memwrite, clk, ssmemadr, ssmemwrite, readdata);

  // WRITEBACK STAGE
  writeback writeback (aluout, readdata, memtoreg, writedata);

endmodule
