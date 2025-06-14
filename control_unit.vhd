library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.riscv_pkg.all;

-- UNIDADE DE CONTROLE - MULTICICLO (máquina de estados finita)

entity ControlUnit is
    Port (
        -- ENTRADAS
        clock       : in  STD_LOGIC;
        reset       : in  STD_LOGIC;
        opcode      : in  STD_LOGIC_VECTOR (6 downto 0); -- Opcode da instrução
        zero_flag   : in  STD_LOGIC;                     -- Flag da ULA para BEQ

        -- SAÍDAS DE CONTROLE DO DATAPATH
        -- Controle do PC
        PCWrite     : out STD_LOGIC;
        PCSource    : out STD_LOGIC_VECTOR(1 downto 0); -- 00=ALU(PC+4), 01=ALUOut(Branch), 10=JUMP_ADDR

        -- Controle de Regs de Estado
        IRWrite     : out STD_LOGIC;
        RegWrite    : out STD_LOGIC; -- Escrita no Banco de Registradores

        -- Controle dos MUX da ULA
        ALUSrcA     : out STD_LOGIC; -- 0=PC, 1=Reg. A
        ALUSrcB     : out STD_LOGIC_VECTOR(1 downto 0); -- 00=Reg. B, 01=Imm(4), 10=Imm

        -- Controle da Memória
        MemRead     : out STD_LOGIC;
        MemWrite    : out STD_LOGIC;
        IorD        : out STD_LOGIC; -- 0=Endereço do PC, 1=Endereço da ALUOut

        -- Controle do MUX de Write Back
        WBDataSel   : out STD_LOGIC -- 0=ALUOut, 1=Dado da Memória (MDR)
    );
end ControlUnit;

architecture Behavioral of ControlUnit is
    -- Definição dos estados da máquina
    type T_ESTADO is (S_FETCH, S_DECODE_BRANCH, S_EXECUTE, S_MEM, S_WB);
    signal estado_atual, proximo_estado: T_ESTADO;

begin

    -- 1. Processo Sequencial: Atualização do Estado Atual
    -- Armazena o estado atual.
    process(clock, reset)
    begin
        if reset = '1' then
            estado_atual <= S_FETCH;
        elsif rising_edge(clock) then
            estado_atual <= proximo_estado;
        end if;
    end process;

    -- 2. Processo Combinacional: Lógica de Próximo Estado e Saídas
    -- Decide o que fazer em cada estado e para qual estado ir
    process(estado_atual, opcode, zero_flag)
    begin
        --VALORES PADRÃO
        PCWrite   <= '0';
        PCSource  <= "00";
        IRWrite   <= '0';
        RegWrite  <= '0';
        ALUSrcA   <= '0';
        ALUSrcB   <= "00";
        MemRead   <= '0';
        MemWrite  <= '0';
        IorD      <= '0'; -- Endereço para memória vem do PC
        WBDataSel <= '0'; -- Padrão: dado vem da ULA

        --LÓGICA DA MÁQUINA DE ESTADOS
        case estado_atual is
            -- ETAPA 1: BUSCA DA INSTRUÇÃO
            when S_FETCH =>
                -- Ler da mem de instruções, guardar no IR, ULA calcula PC+4, PC é atualizado.
                MemRead   <= '1';
                IRWrite   <= '1';
                ALUSrcA   <= '0';       -- ULA.iA = PC
                ALUSrcB   <= "01";      -- ULA.iB = 4
                PCSource  <= "00";      -- PC_next = Saída da ULA (PC+4)
                PCWrite   <= '1';
                proximo_estado <= S_DECODE_BRANCH;

            -- ETAPA 2: DECODIFICAÇÃO E CÁLCULO DE ENDEREÇO DE BRANCH
            when S_DECODE_BRANCH =>
                -- Datapath lê regs. ULA calcula endereço de branch (PC + Imm).
                ALUSrcA   <= '0';        -- ULA.iA = PC (do ciclo anterior)
                ALUSrcB   <= "10";      -- ULA.iB = Imediato
                proximo_estado <= S_EXECUTE;

            -- ETAPA 3: EXECUÇÃO
            when S_EXECUTE =>
                -- ULA executa operação com base no tipo de instrução.
                ALUSrcA <= '1'; -- ULA.iA = Registrador A
                
                case opcode is
                    when OPC_RTYPE =>
                        ALUSrcB <= "00"; -- ULA.iB = Registrador B
                        proximo_estado <= S_WB;

                    when OPC_OPIMM =>
                        ALUSrcB <= "10"; -- ULA.iB = Imediato
                        proximo_estado <= S_WB;

                    when OPC_LOAD | OPC_STORE =>
                        ALUSrcB <= "10"; -- ULA.iB = Imediato (cálculo de endereço)
                        proximo_estado <= S_MEM;

                    when OPC_BRANCH =>
                        ALUSrcB <= "00"; -- ULA.iB = Registrador B (para comparação)
                        if zero_flag = '1' then
                            PCWrite  <= '1';
                            PCSource <= "01"; -- PC_next = ALUOut (endereço calculado na etapa anterior)
                        end if;
                        proximo_estado <= S_FETCH;
                        
                    when OPC_JALR | OPC_JAL =>
                        -- A ULA já calculou PC+4 (Fetch) ou Endereço do Salto (Decode)
                        -- A escrita do PC e do registrador é gerenciada no datapath
                        proximo_estado <= S_WB; 
                        
                    when others =>
                        proximo_estado <= S_FETCH; -- Instrução não suportada
                end case;

            -- ETAPA 4: ACESSO À MEMÓRIA
            when S_MEM =>
                -- Usar o endereço em ALUOut para ler ou escrever na memória de dados.
                IorD <= '1'; -- Endereço para memória vem da ALUOut
                
                if opcode = OPC_LOAD then
                    MemRead <= '1';
                    proximo_estado <= S_WB;
                elsif opcode = OPC_STORE then
                    MemWrite <= '1';
                    proximo_estado <= S_FETCH;
                end if;

            -- ETAPA 5: ESCRITA DE VOLTA (WRITE-BACK)
            when S_WB =>
                -- Escrever o resultado no banco de registradores.
                RegWrite <= '1';
                
                if opcode = OPC_LOAD then
                    WBDataSel <= '1'; -- Dado a ser escrito vem da memória (MDR)
                else
                    WBDataSel <= '0'; -- Dado a ser escrito vem da ULA (ALUOut)
                end if;
                
                proximo_estado <= S_FETCH;

        end case;
    end process;
end Behavioral;