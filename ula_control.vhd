library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.riscv_pkg.all;

-- Q1.6: o controlador da ULA seleciona qual operação a ULA deve realizar
-- a partir do controle principal (ALUOp) e dos campos funct da instrução. 

entity ALUControl is
    Port (
        ALUOpType   : in  STD_LOGIC_VECTOR (1 downto 0); -- Sinal da unidade de controle principal
        funct3  : in  STD_LOGIC_VECTOR (2 downto 0); -- Campo da instrução
        funct7  : in  STD_LOGIC;                     -- Bit usado para distinguir add/sub (bit 30)
        ALUCtrl : out STD_LOGIC_VECTOR (4 downto 0)  -- Sinal para a ULA
    );
end ALUControl;

architecture Behavioral of ALUControl is
begin

    process (ALUOpType, funct3, funct7)
    begin
        case ALUOpType is
            when "00" => -- LW / SW sempre ADD
                ALUCtrl <= OPADD;
            when "01" => -- BEQ usa SUB
                ALUCtrl <= OPSUB;
            when "10" => -- R-type (depende do funct3, funct7)
                case funct3 is
                    when "000" => -- ADD ou SUB
                        if funct7 = '1' then
                            ALUCtrl <= OPSUB; -- SUB
                        else
                            ALUCtrl <= OPADD; -- ADD
                        end if;
                    when "010" => -- SLT
                        ALUCtrl <= OPSLT;
                    when "110" => -- OR
                        ALUCtrl <= OPOR;
                    when "111" => -- AND
                        ALUCtrl <= OPAND;
                    when others =>
                        ALUCtrl <= OPADD; -- padrão seguro
                end case;
            when "11" => -- I-type aritmético (ADDI, SLTI, ANDI, ORI)
                case funct3 is
                    when "000" => ALUCtrl <= OPADD; -- ADDI
                    when "010" => ALUCtrl <= OPSLT; -- SLTI
                    when "110" => ALUCtrl <= OPOR;  -- ORI
                    when "111" => ALUCtrl <= OPAND; -- ANDI
                    when others => ALUCtrl <= OPADD;
                end case;
            when others => -- padrão seguro
                ALUCtrl <= OPADD;
        end case;
    end process;

end Behavioral;