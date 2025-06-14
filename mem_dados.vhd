library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ramD is
    port (
        -- Endereço vem da ULA (ALUOut)
        address : in  std_logic_vector(9 downto 0);
        clock   : in  std_logic;
        -- Dado a ser escrito, vem do registrador B
        data    : in  std_logic_vector(31 downto 0);
        -- Habilitação de escrita, vem da FSM
        wren    : in  std_logic;
        -- Saída de dados (para 'lw'), vai para o MDR
        q       : out std_logic_vector(31 downto 0)
    );
end entity ramD;

architecture Behavioral of ramD is

    -- Define o tipo da memória: um array de vetores de 32 bits
    constant MEM_DEPTH : integer := 1024;
    type mem_array is array (0 to MEM_DEPTH-1) of std_logic_vector(31 downto 0);

    -- Cria a memória. Pode ser inicializada com zeros.
    signal memory : mem_array := (others => (others => '0'));

begin
    -- Processo síncrono para leitura e escrita
    process(clock)
    begin
        if rising_edge(clock) then
            -- Lógica de escrita
            if wren = '1' then
                memory(to_integer(unsigned(address))) <= data;
            end if;

            -- A leitura também é síncrona e ocorre em paralelo.
            -- Se uma escrita e leitura ocorrerem no mesmo endereço no mesmo ciclo,
            -- o dado antigo é lido (comportamento "read-before-write").
            -- Isso funciona perfeitamente para a nossa pipeline.
            q <= memory(to_integer(unsigned(address)));
        end if;
    end process;

end architecture Behavioral;