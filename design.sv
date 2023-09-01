// Code your design here
typedef enum logic [3:0] {
  opADD=0,
  opSUB=1,
  opB=2,
  opLD=3,
  opST=4,
  opCBZ=5,
  opADDI=6,
  opANDI=7,
  opSUBI=8,
  opBL=9,
  opBR=10
} instrOpcode;

typedef enum logic [2:0] {
  aluADD=0,
  aluSUB=1,
  aluPASSFromInput1=2,
  aluOR=3,
  aluAND=4
} aluOp;

typedef enum logic [1:0] {
  branchNone=0,
  branchCB=1,
  branchB=2
} branchSel;

typedef struct packed {
  // Register control
  logic regWrite;
  logic reg2loc;
  // ALU control
  logic aluSrc;
  aluOp aluSel;
  // Data Memory control
  logic memRead;
  logic memWrite;
  logic mem2reg;
  // PC Control
  logic holdPC;
  logic holdIFID;
  branchSel branch;
} cpuControl;


module computer (
  output logic [15:0] progAddr,
  input logic [15:0] progInstr,
  input clk,
  input reset
);
  
  // Intruction Fetch (IF) Stage
  
  logic [15:0] pc;
  
  assign progAddr = pc;
  
  always_ff @(posedge clk)
    begin
      if (ctl.holdPC == 0) begin
    if (reset==1)
      pc <=0;
     else
      case(EXMEM.branch)
        branchNone: pc<=pc+2;
        branchCB: 
          begin
            if (EXMEM.aluZero==1) pc<=EXMEM.pc+{{6{EXMEM.instr[11]}},EXMEM.instr[11:3],1'b0};
            else pc<=pc+2;
          end
        branchB: pc<=EXMEM.pc+{{3{EXMEM.instr[11]}},EXMEM.instr[11:0],1'b0};
        default: pc<=0;
      endcase
    end
      else 
        pc <= pc; //stall
    end
  
  // Instruction Decode (ID) Stage
  //    Controller is at the bottom of the module
  
struct packed {
    logic [15:0] pc;
    logic [15:0] instr;
  } IFID;
  
  always_ff @(posedge clk)
    begin
      if (ctl.holdIFID == 0)
        begin
          if (reset==1)
            begin
              IFID.pc <= 0;
              IFID.instr <= {4'd0,3'd0,3'd7,3'd0,3'd0};  // do nothing
            end
            begin
              IFID.pc <= pc;
              IFID.instr <= progInstr;
            end
        end
    end

  // Register file and reading the file
  logic [15:0] regFile [0:15];
  logic [15:0] readData1, readData2;
  
  always_comb
    begin
      if (IFID.instr[2:0]==7)
        readData1=0;
    else
      readData1=regFile[IFID.instr[2:0]];
    end
  
  always_comb
    begin
      if (IFID.instr[5:3]==7)
        readData2=0;
      else
        readData2=regFile[IFID.instr[5:3]];
    end
  
  // Execute (EX) Stage
  
  struct packed {
    branchSel branch;
    logic regWrite;
    logic reg2loc;
    logic aluSrc;
    aluOp aluSel;
    logic memRead;
    logic memWrite;
    logic mem2reg;
    
    logic [15:0] pc;
    logic [15:0] instr;
    logic [15:0] readData1;
    logic [15:0] readData2;
  } IDEX;
  
  always_ff @(posedge clk)
    begin
      if (reset==1)
        begin
          IDEX.branch=branchNone;
          IDEX.regWrite=0;
          IDEX.memWrite=0;
        end
      else
        begin
          IDEX.branch <= ctl.branch;
          IDEX.regWrite <= ctl.regWrite;
          IDEX.reg2loc <= ctl.reg2loc;
          IDEX.aluSrc <= ctl.aluSrc;
          IDEX.aluSel <= ctl.aluSel;
          IDEX.memRead <= ctl.memRead;
          IDEX.memWrite <= ctl.memWrite;
          IDEX.mem2reg <= ctl.mem2reg;
      
          IDEX.pc <= IFID.pc;
          IDEX.instr <= IFID.instr;
          IDEX.readData1 <= readData1;
          IDEX.readData2 <= readData2;
        end
    end

    // Mux in the EX stage
    logic [2:0] regWriteIndex;

    always_comb
      case(IDEX.reg2loc)
        0: regWriteIndex = IDEX.instr[5:3];
        1: regWriteIndex = IDEX.instr[8:6];
      endcase
 
  // ALU
  logic [15:0] aluResult;
  logic [15:0] aluSrc2;
  logic Zero;
  
  always_comb
    case(IDEX.aluSrc)
      0: aluSrc2 = IDEX.readData2;
      1: aluSrc2 = {{10{IDEX.instr[11]}},IDEX.instr[11:6]};
    endcase
  
  always_comb
    case(IDEX.aluSel)
      aluADD: aluResult=IDEX.readData1+aluSrc2;
      aluSUB: aluResult=IDEX.readData1-aluSrc2;
      aluPASSFromInput1: aluResult=IDEX.readData1;
      aluOR:  aluResult=IDEX.readData1|aluSrc2;
      aluAND: aluResult=IDEX.readData1&aluSrc2;
      default: aluResult=0;
    endcase

  assign Zero=~|aluResult;
  
  // Memory (MEM) Stage
  
  struct packed {
    branchSel branch;
    logic regWrite;
    logic [2:0] regWriteIndex;
    logic memRead;
    logic memWrite;
    logic mem2reg;
    logic [15:0] pc;
    logic [15:0] instr;
    logic aluZero;
    logic [15:0] aluResult;
    logic [15:0] readData2;
  } EXMEM;
  
  always_ff @(posedge clk)
    if (reset==1)
      begin
        EXMEM.branch=branchNone;
        EXMEM.regWrite=0;
        EXMEM.memWrite=0;
      end
    else
      begin
        EXMEM.branch <= IDEX.branch;
        EXMEM.regWrite <= IDEX.regWrite;
        EXMEM.regWriteIndex <= regWriteIndex;
        EXMEM.memRead <= IDEX.memRead;
        EXMEM.memWrite <= IDEX.memWrite;
        EXMEM.mem2reg <= IDEX.mem2reg;
        EXMEM.pc <= IDEX.pc;
        EXMEM.instr <= IDEX.instr;
        EXMEM.aluZero <= Zero;
        EXMEM.aluResult <= aluResult;
        EXMEM.readData2 <= IDEX.readData2;
      end
  
  logic [15:0] DMem [0:127];
  logic [15:0] dmemReadData;
  
  assign dmemReadData=DMem[EXMEM.aluResult[6:1]];
  
  always_ff @(posedge clk)
    if (EXMEM.memWrite==1)
      DMem[aluResult[6:1]]<=EXMEM.readData2;
  
  
  // Write Back (WB) Stage
  
  struct packed {
    logic regWrite;
    logic [2:0] regWriteIndex;
    logic mem2reg;
    logic [15:0] dmemReadData;
    logic [15:0] aluResult;
  } MEMWB;
  
  always @(posedge clk)
    if (reset==1)
      begin
        MEMWB.regWrite <= 0;
      end
    else
      begin
        MEMWB.regWrite <= EXMEM.regWrite;
        MEMWB.regWriteIndex <= EXMEM.regWriteIndex;
        MEMWB.mem2reg <= EXMEM.mem2reg;
        MEMWB.dmemReadData <= dmemReadData;
        MEMWB.aluResult <= EXMEM.aluResult;
      end

  // Writing to reg file

  logic [15:0] regWriteData;

  always_comb
    case(MEMWB.mem2reg)
      0: regWriteData=MEMWB.aluResult;
      1: regWriteData=MEMWB.dmemReadData;
    endcase
        
  always_ff @(negedge clk)
    begin
      if (MEMWB.regWrite==1)
        regFile[MEMWB.regWriteIndex] <= regWriteData;
    end
  
  
// Controller
cpuControl ctl;
  
  always_comb
    begin   
      
      
      
      if((((regWriteIndex == readData1)||(regWriteIndex == readData2))&& IDEX.regWrite==1)||(((EXMEM.regWriteIndex == readData1)||(EXMEM.regWriteIndex == readData2))&& EXMEM.regWrite==1))
      begin
        //insert nothing (noOp)
        ctl.holdPC = 1;
      	ctl.holdIFID = 1;
        //follows no op in tb
        ctl.regWrite=0;
        ctl.reg2loc=0;
        ctl.aluSrc=0;
        ctl.aluSel=aluPASSFromInput1;
        ctl.memRead=0;
        ctl.memWrite=0;
        ctl.mem2reg=0;
        ctl.branch=branchNone;
      end
      else begin
        ctl.holdPC = 0;
      	ctl.holdIFID = 0;
      
    case(IFID.instr[15:12])
      opADDI: 
        begin
          ctl.regWrite=1;
          ctl.reg2loc=0;
          ctl.aluSrc=1;
          ctl.aluSel=aluADD;
          ctl.memRead=0;
          ctl.memWrite=0;
          ctl.mem2reg=0;
          ctl.branch=branchNone;
        end
      opB:
        begin
          ctl.regWrite=0;
          ctl.reg2loc=0;
          ctl.aluSrc=1;
          ctl.aluSel=aluADD;
          ctl.memRead=0;
          ctl.memWrite=0;
          ctl.mem2reg=0;
          ctl.branch=branchB;
        end
      opSUBI:
        begin
          ctl.regWrite=1;
          ctl.reg2loc=0;
          ctl.aluSrc=1;
          ctl.aluSel=aluSUB;
          ctl.memRead=0;
          ctl.memWrite=0;
          ctl.mem2reg=0;
          ctl.branch=branchNone;   
        end
      opADD:
        begin
          ctl.regWrite=1;
          ctl.reg2loc=1;//should be good
          ctl.aluSrc=0; //good
          ctl.aluSel=aluADD; //good
          ctl.memRead=0; //right?
          ctl.memWrite=0; 
          ctl.mem2reg=0;
          ctl.branch=branchNone; 
        end
      default: 
        begin 
          ctl.regWrite=0;
          ctl.reg2loc=0;
          ctl.aluSrc=0;
          ctl.aluSel=aluADD;
          ctl.memRead=0;
          ctl.memWrite=0;
          ctl.mem2reg=0;
          ctl.branch=branchNone;
        end
    endcase
   end
end
  
endmodule
