
// Testbench 2
module tb;
  logic [15:0] addr;
  logic [15:0] instr;
  logic clk;
  logic reset;
  
  instrMemory im(addr,instr);
  computer cpu(addr,instr,clk,reset);
  
  initial
    begin
      clk=0;
      forever #1 clk=~clk;
    end
  
  initial
    begin
      $monitor("clk=%b reset=%b addr=%3d X0=%2d X1=%2d X2=%2d, instr=%b, PChold=%b, holdIFID=%b",clk,
               reset,addr,
               cpu.regFile[0],
               cpu.regFile[1],
               cpu.regFile[2], cpu.IFID.instr, cpu.ctl.holdIFID, cpu.ctl.holdPC
              );
      reset=1;
      #2
      reset=0;
      #40 $finish;
    end
  
endmodule

module instrMemory(
  input logic [15:0] addr,
  output logic [15:0] instr
);
  
  function logic [15:0] rFormat
    (input instrOpcode op,
     input [2:0] regDst,
     input [2:0] regSrc1,
     input [2:0] regSrc2
    );
    rFormat={op, 3'b0, regDst,regSrc2,regSrc1};
  endfunction
  
  function logic [15:0] iFormat
    (input instrOpcode op,
     input [2:0] regDst,
     input [2:0] regSrc,
     input [5:0] immConst
    );
    iFormat={op, immConst, regDst,regSrc};
  endfunction
  
  function logic [15:0] dFormat
    (input instrOpcode op,
     input [2:0] regRegFile,
     input [2:0] regAddr,
     input [5:0] offsetConst
    );
    dFormat={op, offsetConst, regRegFile,regAddr};
  endfunction
  
  function logic [15:0] cbFormat
    (input instrOpcode op,
     input [2:0] regTest,
     input [8:0] offsetConst
    );
    cbFormat={op, offsetConst, regTest};
  endfunction
  
  function logic [15:0] bFormat
    (input instrOpcode op,
     input [11:0] offsetConst
    );
    bFormat={op, offsetConst};
  endfunction
  
  function logic [15:0] nop
    (
    );
    nop = rFormat(opADD,7,7,7);
  endfunction
  
  always_comb
    case(addr[4:1])
      0: instr=iFormat(opADDI,0,7,3);
      1: instr=iFormat(opADDI,1,7,2);
      2: instr=iFormat(opSUBI,2,0,1);
      3: instr=rFormat(opADD,0,1,2);
      4: instr=bFormat(opB,-4);
      default: instr=nop();
    endcase
  
endmodule
