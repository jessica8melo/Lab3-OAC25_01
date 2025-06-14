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
        regout   : out std_logic_vector(31 downto 0)
		  -- Porta de saída para depuração do estado
        Estado_out : out std_logic_vector(3 downto 0) 
    );
end Multiciclo;

architecture Behavioral of Multiciclo is
	 -- Componentes não tiveram mudanças de Uniciclo pra Multiciclo
    component ControlUnit is
        port (
            opcode      : in  STD_LOGIC_VECTOR (6 downto 0); -- Opcode da instrução
            zero_flag   : in  STD_LOGIC; -- Flag da ULA para BEQ
            ALUOpType   : out STD_LOGIC_VECTOR(1 downto 0);
            RegWrite    : out STD_LOGIC;
            MemRead     : out STD_LOGIC;
            MemWrite    : out STD_LOGIC;
            ALUSrc      : out STD_LOGIC;
            WBDataSel   : out STD_LOGIC_VECTOR(1 downto 0); -- Write-Back Data Select: 00=ALU, 01=Mem, 10=PC+4
            BranchPCSel : out STD_LOGIC; -- Condição de Branch
            Jump        : out STD_LOGIC);
    end component;

    component xregs is
        generic (
            SIZE : natural := 32;
            ADDR : natural := 5);
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
            oREGD    : out std_logic_vector(SIZE-1 downto 0));
    end component;

    component ALUControl is
        port (
            ALUOpType   : in  STD_LOGIC_VECTOR (1 downto 0);
            funct3  : in  STD_LOGIC_VECTOR (2 downto 0);
            funct7  : in  STD_LOGIC;
            ALUCtrl : out STD_LOGIC_VECTOR (4 downto 0));
    end component;

    component ALU is
        port (
            iControl : in  std_logic_vector(4 downto 0);
            iA       : in  std_logic_vector(31 downto 0);
            iB       : in  std_logic_vector(31 downto 0);
            oResult  : out std_logic_vector(31 downto 0));
    end component;

    component genImm32 is
		  port (
			  instr : in std_logic_vector(31 downto 0);
			  imm32 : out std_logic_vector(31 downto 0));
    end component;
	 
	 -- Componentes de Memória
    component ramI is
        port (
            address : in std_logic_vector(9 downto 0);
            clock   : in std_logic;
            q       : out std_logic_vector(31 downto 0)
        );
    end component;
    
    component ramD is
        port (
            address : in std_logic_vector(9 downto 0);
            clock   : in std_logic;
            data    : in std_logic_vector(31 downto 0);
            wren    : in std_logic;
            q       : out std_logic_vector(31 downto 0)
        );
    end component;

    -- Sinais internos
    -- Muitos sinais do uniciclo são mantidos, mas agora representam
    -- saídas combinacionais que são carregadas nos regs de estado
    signal PC_internal      : std_logic_vector(31 downto 0) := x"00400000";
    signal Instr_from_mem   : std_logic_vector(31 downto 0);
    signal regout_internal  : std_logic_vector(31 downto 0);
    signal SaidaULA_comb    : std_logic_vector(31 downto 0);
    signal Leitura1, Leitura2: std_logic_vector(31 downto 0);
    signal EscreveMem       : std_logic;
    signal LeMem            : std_logic;
    signal EscreveReg       : std_logic;
    signal OrigULA          : std_logic;
    signal ALUOpType        : std_logic_vector(1 downto 0);
    signal WBDataSel        : std_logic_vector(1 downto 0);
    signal Immediate        : std_logic_vector(31 downto 0);
    signal MemData_from_mem : std_logic_vector(31 downto 0);
    signal ALUControlSig    : std_logic_vector(4 downto 0);
    signal SrcA_comb, SrcB_comb : std_logic_vector(31 downto 0);
    signal WBData           : std_logic_vector(31 downto 0);
    signal BranchPCSel      : std_logic;
    signal Jump             : std_logic;

    -- NOVOS SINAIS E REGS PARA MULTICICLO
    -- Definição dos estados (máquina de estados finita - FSM)
    type T_ESTADO is (S_FETCH, S_DECODE, S_EXECUTE, S_MEM, S_WB);
    signal estado_atual, proximo_estado: T_ESTADO;

    -- Sinais de controle gerados pela FSM
    signal PCWrite, IRWrite, RegWrite_FSM, MemRead_FSM, MemWrite_FSM : std_logic;
    signal ALUSrcA, ALUSrcB, IorD, PCSource : std_logic_vector(1 downto 0);

    -- Regs de estado (pipeline registers??)
    signal IR         : std_logic_vector(31 downto 0); -- Instruction Register
    signal A, B       : std_logic_vector(31 downto 0); -- Regs lidos do banco
    signal ALUOut     : std_logic_vector(31 downto 0); -- Saída da ULA
    signal MDR        : std_logic_vector(31 downto 0); -- Memory Data Register
    signal PC_next_logic: std_logic_vector(31 downto 0); -- Lógica do próximo PC
    signal ZeroFlag   : std_logic;

    -- Sinais da instrução decodificada (agora vêm do reg IR)
    signal opcode     : std_logic_vector(6 downto 0);
    signal rs1, rs2, rd: std_logic_vector(4 downto 0);
    signal funct3     : std_logic_vector(2 downto 0);
    signal funct7_5   : std_logic;
   

begin
    -- 1. LÓGICA DA FSM    
    -- Processo da transição de estados (parte sequencial da FSM)
    process(clockCPU, reset)
    begin
        if reset = '1' then
            estado_atual <= S_FETCH;
        elsif rising_edge(clockCPU) then
            estado_atual <= proximo_estado;
        end if;
    end process;

    -- Processo para lógica de próximo estado e geração dos sinais de controle (parte combinacional da FSM)
    process(estado_atual, opcode)
    begin
        -- Valores padrão para os sinais
        PCWrite      <= '0'; IRWrite <= '0'; RegWrite_FSM <= '0';
        MemRead_FSM  <= '0'; MemWrite_FSM <= '0';
        PCSource     <= "00"; -- Padrão: PC + 4
        IorD         <= "00"; -- Padrão: Endereço para memória vem do PC
        ALUSrcA      <= "00"; -- Padrão: Entrada A da ULA vem do reg A
        ALUSrcB      <= "01"; -- Padrão: Entrada B da ULA vem do reg B

        case estado_atual is
            when S_FETCH =>
                -- Busca a instrução e calcula PC+4
                MemRead_FSM  <= '1';
                IRWrite      <= '1';
                ALUSrcA      <= "00"; -- PC
                ALUSrcB      <= "01"; -- Imediato (4)
                PCSource     <= "00"; -- Saída da ULA (PC+4)
                PCWrite      <= '1';
                proximo_estado <= S_DECODE;

            when S_DECODE =>
                -- Decodifica e busca operandos no banco de regs
                ALUSrcA      <= "00"; -- Reg. A
                ALUSrcB      <= "11"; -- Imediato (para cálculo de branch)
                proximo_estado <= S_EXECUTE;

            when S_EXECUTE =>
                -- Executa a operação na ULA
                ALUSrcA <= "10"; -- reg A
                if (opcode = TIPO_R) then
                    ALUSrcB <= "00"; -- reg B
                    proximo_estado <= S_WB;
                elsif (opcode = TIPO_I_LOAD or opcode = TIPO_S) then
                    ALUSrcB <= "10"; -- Imediato
                    proximo_estado <= S_MEM;
                elsif (opcode = TIPO_I_ARIT) then
                    ALUSrcB <= "10"; -- Imediato
                    proximo_estado <= S_WB;
                elsif (opcode = TIPO_B) then
                    ALUSrcA <= "10"; -- reg A
                    ALUSrcB <= "00"; -- reg B
                    if ZeroFlag = '1' then
                        PCSource <= "01"; -- Endereço de branch (PC + Imm)
                        PCWrite <= '1';
                    end if;
                    proximo_estado <= S_FETCH;
                else
                    proximo_estado <= S_FETCH; -- Outras instruções
                end if;

            when S_MEM =>
                -- Acessa a memória de dados
                IorD <= "01"; -- Endereço para memória vem da ULA
                if (opcode = TIPO_I_LOAD) then
                    MemRead_FSM <= '1';
                    proximo_estado <= S_WB;
                elsif (opcode = TIPO_S) then
                    MemWrite_FSM <= '1';
                    proximo_estado <= S_FETCH;
                end if;

            when S_WB =>
                -- Escreve o resultado de volta no banco de registradores
                RegWrite_FSM <= '1';
                proximo_estado <= S_FETCH;
        end case;
    end process;
    
    -- 2. ATUALIZAÇÃO DOS REGISTRADORES DE ESTADO
    -- Carregar o PC e os regs de estado na borda do clock
    process(clockCPU, reset)
    begin
        if reset = '1' then
            PC_internal <= x"00400000";
            IR          <= (others => '0');
            A           <= (others => '0');
            B           <= (others => '0');
            ALUOut      <= (others => '0');
            MDR         <= (others => '0');
        elsif rising_edge(clockCPU) then
            -- Carrega PC
            if PCWrite = '1' then
                PC_internal <= PC_next_logic;
            end if;
            -- Carrega IR
            if IRWrite = '1' then
                IR <= Instr_from_mem;
            end if;
            -- Carrega A e B
            A <= Leitura1;
            B <= Leitura2;
            -- Carrega saída da ULA
            ALUOut <= SaidaULA_comb;
            -- Carrega dado da memória
            MDR <= MemData_from_mem;
        end if;
    end process;

    -- 3. DATAPATH: MUX E DECODERS
    -- Decodificação da instrução (agora a fonte é o registrador IR) imposto de renda :(
    opcode   <= IR(6 downto 0);
    rd       <= IR(11 downto 7);
    funct3   <= IR(14 downto 12);
    rs1      <= IR(19 downto 15);
    rs2      <= IR(24 downto 20);
    funct7_5 <= IR(30);

    -- Lógica de seleção do próximo PC (MUX)
    with PCSource select
        PC_next_logic <= SaidaULA_comb when "00", -- PC+4 ou endereço JAL/JALR
                         ALUOut      when "01", -- Endereço de Branch (calculado em DECODE/EXECUTE)
                         (others => 'X') when others;

    -- Conexões com Memórias
    MemC : ramI port map (
        address => PC_internal(11 downto 2),
        clock   => clockMem,
        q       => Instr_from_mem
    );
    
    MemD : ramD port map (
        address => ALUOut(11 downto 2), -- Endereço sempre vem da ALUOut na fase MEM
        clock   => clockMem,
        data    => B,                   -- Dado para escrita vem do registrador B
        wren    => MemWrite_FSM,        -- Sinal de escrita controlado pela FSM
        q       => MemData_from_mem
    );

    -- Gerador de Imediato (lê do IR)
    ImmGen1 : genImm32 port map ( instr => IR, imm32 => Immediate );

    -- Unidade de Controle Principal (ainda pode ser usada para decodificar o opcode para a ULA)
    -- NOTA: Os sinais de controle de alto nível agora vêm da FSM.
    CU1 : ControlUnit port map (
        opcode => opcode, zero_flag => ZeroFlag, ALUOpType => ALUOpType,
        RegWrite => EscreveReg, MemRead => LeMem, MemWrite => EscreveMem,
        ALUSrc => OrigULA, WBDataSel => WBDataSel, BranchPCSel => BranchPCSel, Jump => Jump
    );
    
    -- Banco de Registradores
    Regs1 : xregs port map (
        iCLK => clockCPU, iRST => reset,
        iWREN => RegWrite_FSM, -- Habilitação de escrita controlada pela FSM
        iRS1  => rs1,
        iRS2  => rs2,
        iRD   => rd,
        iDATA => WBData,       -- Dado a ser escrito (vem do MUX de Write-Back)
        oREGA => Leitura1,
        oREGB => Leitura2,
        iDISP => regin,
        oREGD => regout_internal
    );
    
    -- MUX da entrada A da ULA
    with ALUSrcA select
        SrcA_comb <= PC_internal when "00",
                     A           when "10",
                     (others => 'X') when others;
    
    -- MUX da entrada B da ULA
    with ALUSrcB select
        SrcB_comb <= B         when "00",
                     x"00000004" when "01", -- Constante 4 para PC+4
                     Immediate when "10",
                     Immediate when "11",
                     (others => 'X') when others;

    -- Controle da ULA
    ALUCtrl1 : ALUControl port map (
        ALUOpType => ALUOpType, funct3 => funct3, funct7 => funct7_5, ALUCtrl => ALUControlSig
    );

    -- ULA
    ALU1 : ALU port map (
        iControl => ALUControlSig,
        iA       => SrcA_comb,
        iB       => SrcB_comb,
        oResult  => SaidaULA_comb
    );
    
    ZeroFlag <= '1' when SaidaULA_comb = x"00000000" else '0';

    -- MUX de Write Back (agora seleciona entre ALUOut e MDR)
    with WBDataSel select -- Esse ainda vem da Unidade de Controle
        WBData <= ALUOut when "00", -- Resultado da ULA (Tipo R, Tipo I Arit)
                  MDR    when "01", -- Dado da memória (Load)
                  ALUOut when "10", -- PC+4 (para JAL/JALR, vem da ULA na etapa EXEC)
                  (others => '0') when others;
                  
    -- Saídas para depuração
    PC    <= PC_internal;
    Instr <= IR; -- Mostra a instrução que está sendo processada
    regout <= regout_internal;
	 
	with estado_atual select
    Estado_out <= "0001" when S_FETCH,
                  "0010" when S_DECODE_BRANCH,
                  "0100" when S_EXECUTE,
                  "1000" when S_MEM,
                  "0101" when S_WB, -- Exemplo para WB
                  "0000" when others;
end Behavioral;