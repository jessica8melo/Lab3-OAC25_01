library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.riscv_pkg.all;

entity Multiciclo is
    port (
        clockCPU : in  std_logic;
        clockMem : in  std_logic;
        reset    : in  std_logic;
        PC       : out std_logic_vector(31 downto 0);
        Instr    : out std_logic_vector(31 downto 0);
        regin    : in  std_logic_vector(4 downto 0);
        regout   : out std_logic_vector(31 downto 0);
        Estado_out : out std_logic_vector(3 downto 0)
    );
end Multiciclo;

architecture Behavioral of Multiciclo is
    -- Componentes (parte estrutural do processador multiciclo)
    component ControlUnit is
        port (
            clock       : in  STD_LOGIC;
            reset       : in  STD_LOGIC;
            opcode      : in  STD_LOGIC_VECTOR (6 downto 0);
            zero_flag   : in  STD_LOGIC;
            PCWrite     : out STD_LOGIC;
            PCSource    : out STD_LOGIC_VECTOR(1 downto 0);
            IRWrite     : out STD_LOGIC;
            RegWrite    : out STD_LOGIC;
            ALUSrcA     : out STD_LOGIC;
            ALUSrcB     : out STD_LOGIC_VECTOR(1 downto 0);
            MemRead     : out STD_LOGIC;
            MemWrite    : out STD_LOGIC;
            IorD        : out STD_LOGIC;
            WBDataSel   : out STD_LOGIC;
            ALUOpType   : out std_logic_vector(1 downto 0)
        );
    end component;

    component xregs is
        generic (
            SIZE : natural := 32;
            ADDR : natural := 5
        );
        port (
            iCLK     : in  std_logic;
            iRST     : in  std_logic;
            iWREN    : in  std_logic;
            iRS1     : in  std_logic_vector(ADDR-1 downto 0);
            iRS2     : in  std_logic_vector(ADDR-1 downto 0);
            iRD      : in  std_logic_vector(ADDR-1 downto 0);
            iDATA    : in  std_logic_vector(SIZE-1 downto 0);
            oREGA    : out std_logic_vector(SIZE-1 downto 0);
            oREGB    : out std_logic_vector(SIZE-1 downto 0);
            iDISP    : in  std_logic_vector(ADDR-1 downto 0);
            oREGD    : out std_logic_vector(SIZE-1 downto 0)
        );
    end component;
   
    component ALUControl is
        port (
            ALUOpType : in  std_logic_vector(1 downto 0);
            funct3    : in  std_logic_vector(2 downto 0);
            funct7    : in  std_logic;
            ALUCtrl   : out std_logic_vector(4 downto 0)
        );
    end component;

    component ALU is
        port (
            iControl : in  std_logic_vector(4 downto 0);
            iA       : in  std_logic_vector(31 downto 0);
            iB       : in  std_logic_vector(31 downto 0);
            oResult  : out std_logic_vector(31 downto 0)
        );
    end component;

    component genImm32 is
        port (
            instr : in  std_logic_vector(31 downto 0);
            imm32 : out std_logic_vector(31 downto 0)
        );
    end component;

    component ramI is
        port (
            address : in  std_logic_vector(9 downto 0);
            clock   : in  std_logic;
            q       : out std_logic_vector(31 downto 0)
        );
    end component;

    component ramD is
        port (
            address : in  std_logic_vector(9 downto 0);
            clock   : in  std_logic;
            data    : in  std_logic_vector(31 downto 0);
            wren    : in  std_logic;
            q       : out std_logic_vector(31 downto 0)
        );
    end component;

    -- Sinais internos (conexão entre componentes)
    signal PC_internal      : std_logic_vector(31 downto 0) := x"00400000";
    signal PC_next          : std_logic_vector(31 downto 0);
    signal InstrReg         : std_logic_vector(31 downto 0);
    signal A, B             : std_logic_vector(31 downto 0); -- Operandos da ULA
    signal ALUOut           : std_logic_vector(31 downto 0);
    signal MDR              : std_logic_vector(31 downto 0); -- Memória de dados
    signal ImmGen           : std_logic_vector(31 downto 0);
    signal ALUCtrl          : std_logic_vector(4 downto 0);
    signal SaidaULA         : std_logic_vector(31 downto 0);
    signal WBData           : std_logic_vector(31 downto 0);
    signal ZeroFlag         : std_logic;

    -- Sinais da Unidade de Controle
    signal PCWrite          : std_logic;
    signal IRWrite          : std_logic;
    signal RegWrite         : std_logic;
    signal ALUSrcA          : std_logic;
    signal ALUSrcB          : std_logic_vector(1 downto 0);
    signal MemRead          : std_logic;
    signal MemWrite         : std_logic;
    signal IorD             : std_logic;
    signal WBDataSel        : std_logic;
    signal PCSource         : std_logic_vector(1 downto 0);
    signal ALUOpType        : std_logic_vector(1 downto 0);

    -- Decodificação da instrução
    signal opcode           : std_logic_vector(6 downto 0);
    signal funct3           : std_logic_vector(2 downto 0);
    signal funct7           : std_logic;

begin
    -- Conexão da Unidade de Controle
    CU: ControlUnit port map (
        clock       => clockCPU,
        reset       => reset,
        opcode      => opcode,
        zero_flag   => ZeroFlag,
        PCWrite     => PCWrite,
        PCSource    => PCSource,
        IRWrite     => IRWrite,
        RegWrite    => RegWrite,
        ALUSrcA     => ALUSrcA,
        ALUSrcB     => ALUSrcB,
        MemRead     => MemRead,
        MemWrite    => MemWrite,
        IorD        => IorD,
        WBDataSel   => WBDataSel,
        ALUOpType   => ALUOpType
    );

    -- Banco de registradores
    Regs: xregs port map (
        iCLK     => clockCPU,
        iRST     => reset,
        iWREN    => RegWrite,
        iRS1     => InstrReg(19 downto 15),
        iRS2     => InstrReg(24 downto 20),
        iRD      => InstrReg(11 downto 7),
        iDATA    => WBData,
        oREGA    => A,
        oREGB    => B,
        iDISP    => regin,
        oREGD    => regout
    );

    -- Unidade de geração de imediato
    ImmGen1: genImm32 port map (
        instr => InstrReg,
        imm32 => ImmGen
    );

    -- ULA
    ALUCtrlUnit: ALUControl port map (
        ALUOpType   => ALUOpType,
        funct3      => funct3,
        funct7      => funct7,
        ALUCtrl     => ALUCtrl
    );

    ALU1: ALU port map (
        iControl => ALUCtrl,
        iA       => A,
        iB       => B,
        oResult  => SaidaULA
    );

    -- Memórias (instruções e dados)
    INSTR_MEM: ramI port map (
        address => PC_internal(11 downto 2),
        clock   => clockMem,
        q       => InstrReg
    );

    DATA_MEM: ramD port map (
        address => ALUOut(11 downto 2),
        clock   => clockMem,
        data    => B,
        wren    => MemWrite,
        q       => MDR
    );

    -- Decodificação da instrução
    opcode  <= InstrReg(6 downto 0);
    funct3  <= InstrReg(14 downto 12);
    funct7  <= InstrReg(30);

    -- Sinal de zero para Branch
    ZeroFlag <= '1' when SaidaULA = x"00000000" else '0';

    -- Múltiplex do Write-back
    WBData <= ALUOut when WBDataSel = '0' else MDR;

    -- Atualizações dos registradores de estado
    process(clockCPU, reset)
    begin
        if reset = '1' then
            PC_internal <= x"00400000";
            ALUOut <= (others => '0');
        elsif rising_edge(clockCPU) then
            if PCWrite = '1' then
                PC_internal <= PC_next;
            end if;
            ALUOut <= SaidaULA;
        end if;
    end process;

    -- Multiplexador para definir próximo PC
    with PCSource select
        PC_next <= SaidaULA when "00",
                    ALUOut when "01",
                    (others => '0') when others;

    -- Saídas para depuração
    PC <= PC_internal;
    Instr <= InstrReg;

end Behavioral;
