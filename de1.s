.data
    result_sw: .word 0

.text
    li gp,0x10010000 

    # --- Teste de add ---
    li   t1, 5
    li   t0, 10
    add  t0, t0, t1       # t0 = t0 + 5 = 15
    
    # --- Teste de addi ---
    addi t0, t0, 5        # t0 = t0 + 5 = 20

    # --- Teste de sub ---
    # Para subtrair 10 de t0 (t0 = 20): t0 <- t0 - 10 = 10
    addi t1, x0, 10     
    sub t0, t0, t1        # t0 = t0 - 10 = 10

    # --- Teste de and ---
    li t1, 0xC            # t1 = 12
    li t2, 0xA            # t2 = 10
    and t0, t1, t2        # t0 = 12 AND 10 = 8

    # --- Teste de or ---
    or t0, t1, t2         # t0 = 12 OR 10 = 14

    # --- Teste de slt (set less than) ---
    li t1, 10             # t1 = 10
    li t2, 20             # t2 = 20
    slt t0, t1, t2        # t0 = (10 < 20) = 1
    slt t0, t2, t1        # t0 = (20 < 10) = 0

    # --- Teste de sw e lw ---
    # Armazena t0 em result_sw e depois carrega de novo em t0 para garantir resultado
    la t1, result_sw
    sw t0, 0(t1)
    lw t0, 0(t1)

    # --- Teste de beq ---
    # Se t0 == t0, pula para label_beq_true
    beq t0, t0, label_beq_true
    addi t0, x0, 99       # NÃO executa esse (comprovação)
label_beq_true:
    addi t0, x0, 1        # t0 = 1 (se o beq funcionou)

    # --- Teste de jal ---
    jal ra, sub_rotina
    addi t0, x0, 50       # t0 = 50 (para mostrar que retornou)
    j end_program      

sub_rotina:
    addi t0, x0, 100      # t0 = 100 (apenas para mostrar que entrou na sub-rotina)
    jr ra                 # Retorna

    # --- Teste de jalr ---
    la t1, end_program
    addi t1, t1, 0
    jalr x0, t1, 0
    addi t0, x0, 999      # NÃO executa esse

end_program:
    j end_program         # Loop infinito
