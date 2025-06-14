library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
-- Biblioteca para ler arquivos de texto na simulação
use STD.TEXTIO.ALL;

entity ramI is
    port (
        -- O endereço vem do PC. 10 bits = 2^10 = 1024 posições.
        address : in  std_logic_vector(9 downto 0);
        clock   : in  std_logic;
        -- A saída 'q' vai para o registrador de instrução (IR)
        q       : out std_logic_vector(31 downto 0)
    );
end entity ramI;

architecture Behavioral of ramI is
    -- Define o tipo da memória: um array de vetores de 32 bits
    constant MEM_DEPTH : integer := 1024; -- 1024 palavras de 32 bits
    type mem_array is array (0 to MEM_DEPTH - 1) of std_logic_vector(31 downto 0);

    -- Função para inicializar a memória a partir de um arquivo .hex
    -- (Isso é usado para simulação e síntese em FPGA)
    impure function init_mem_from_file(file_name : in string) return mem_array is
        file mem_file     : text open read_mode is file_name;
        variable mem_line : line;
        variable temp_mem : mem_array := (others => (others => '0'));
        variable i        : integer := 0;
        variable bit_v    : std_logic_vector(31 downto 0);
    begin
        while not endfile(mem_file) loop
            readline(mem_file, mem_line);
            -- Converte a linha do arquivo hexadecimal para std_logic_vector
            hread(mem_line, bit_v);
            temp_mem(i) := bit_v;
            i := i + 1;
        end loop;
        return temp_mem;
    end function;

    -- Cria o sinal de memória e o inicializa com o conteúdo do arquivo
    -- Substitua "programa.hex" pelo nome do seu arquivo de programa.
    signal memory : mem_array := init_mem_from_file("programa.hex");

begin
    -- Processo síncrono para a leitura
    process(clock)
    begin
        if rising_edge(clock) then
            -- A leitura é síncrona: o dado só aparece na saída no ciclo de clock
            -- seguinte ao fornecimento do endereço.
            q <= memory(to_integer(unsigned(address)));
        end if;
    end process;

end architecture Behavioral;