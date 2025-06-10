library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.riscv_pkg.all;

-- Q1.2: o banco de registradores aqui é o sinal xreg32 que, de acordo com
-- com o tipo "banco", é um conjunto de 32 regs de 32 bits cada.
--
-- O banco recebe:
-- o sinal do clock por ser um componente síncrono;
-- o sinal de reset para forçar o banco inteiro para voltar para o padrão
-- (todos os regs zerados) e colocaros regs SP e GP nos valores iniciais;
-- o sinal WREN que define se o banco pode ou não escrever dados no momento;
-- os sinais RS1, RS2 e RD que definem quais regs estão sendo utilizados
-- para leitura (RS1 e RS2) ou escrita (RD);
-- o valor a ser escrito no reg caso esteja executando essa função;
-- os valores dos regs RS1 e RS2;
-- o sinal DISP que define qual reg está sendo observado;
-- o valor do reg sendo observado.
--
-- No processo definido o banco reage ou à batida de subida do sinal de
-- reset, reiniciando os valores do banco, ou à batida de subida do clock
-- para escrever o valor de entrada no reg especificado caso seja permitido.

entity xregs is
    generic (
        SIZE : natural := 32;
        ADDR : natural := 5
    );
    port 
    (
        iCLK        : in  std_logic;
        iRST        : in  std_logic;
        iWREN       : in  std_logic;
        iRS1        : in  std_logic_vector(ADDR-1 downto 0);
        iRS2        : in  std_logic_vector(ADDR-1 downto 0);
        iRD     : in  std_logic_vector(ADDR-1 downto 0);
        iDATA       : in  std_logic_vector(SIZE-1 downto 0);
        oREGA   : out std_logic_vector(SIZE-1 downto 0);
        oREGB   : out std_logic_vector(SIZE-1 downto 0);
        
        iDISP       : in  std_logic_vector(ADDR-1 downto 0);
        oREGD       : out std_logic_vector(SIZE-1 downto 0)
    );
end entity;

architecture rtl of xregs is

type banco is array (31 downto 0) of std_logic_vector(31 downto 0);
constant ZERO32 : std_logic_vector(31 downto 0) := X"00000000";
constant GPR : natural := 5;
constant SPR : natural := 2;

signal xreg32: banco;

begin
    oREGA <= ZERO32 when (iRS1="00000") else xreg32(to_integer(unsigned(iRS1)));
    oREGB <= ZERO32 when (iRS2="00000") else xreg32(to_integer(unsigned(iRS2)));
    oREGD <= ZERO32 when (iDISP="00000") else xreg32(to_integer(unsigned(iDISP)));
    process(iCLK, iRST)
	 begin
		if (iRST = '1') then
        xreg32 <= (others => (others => '0'));
        xreg32(SPR) <= STACK_ADDRESS;
        xreg32(GPR) <= DATA_ADDRESS;
		elsif rising_edge(iCLK) then
        if (iWREN = '1' and not(iRD = "00000")) then
            xreg32(to_integer(unsigned(iRD))) <= iDATA;
        end if;
		end if;
	end process;
end rtl;