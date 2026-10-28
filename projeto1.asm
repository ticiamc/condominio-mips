# =========================================================
# Nome do Grupo: Letícia Medeiros Cavalcante e Sarah Pereira de Lima
# Atividade: Projeto 01 (PE1) da 1a VA
# Disciplina: Arquitetura e Organização de Computadores
# Semestre Letivo: 2026.2
# Breve descrição: Implementação do comando addAuto (e addAuto com A
#                  maiúsculo), que cadastra um carro ou moto em um AP
#                  respeitando a regra de 1 carro OU até 2 motos,
#                  sem mistura. AP vazio também é recusado.
# =========================================================

# ---------------------------------------------------------
# COMO CADA APARTAMENTO FICA GUARDADO NA NOSSA MEMÓRIA (328 bytes)
#   offset   0: palavra  quantidade de moradores (0 = AP vazio)
#   offset   4: 6 x 40B  nomes dos moradores (39 caracteres + \0)
#   offset 244: byte     tipo de veículo (0 = nenhum, 'c' = carro, 'm' = moto)
#   offset 245: byte     quantidade de veículos (0, 1 ou 2)
#   offset 246: 2 bytes  sobra para manter o alinhamento
#   offset 248: 2 x 40B  veículos: modelo (30B) + placa (10B)
# Para achar o AP usamos: (andar - 1) * 2 + (final - 1)  ->  101 = 0, 1202 = 23
# ---------------------------------------------------------

.data                                # Seção de variáveis estáticas na memória
    banner:              .asciiz "LS-shell>> " # Banner com nossas iniciais exigido pelo projeto
    msg_invalido:        .asciiz "Comando invalido\n" # Mensagem padrão para comandos não reconhecidos
    msg_ap_invalido:     .asciiz "Falha: AP invalido\n" # Mensagem para quando o AP digitado não existe no condomínio
    msg_max_moradores:   .asciiz "Falha: AP com numero max de moradores\n" # Mensagem para quando o AP já tem 6 moradores
    msg_nao_encontrado:  .asciiz "Falha: morador nao encontrado\n" # Mensagem quando o nome não consta no AP
    msg_max_autos:       .asciiz "Falha: AP com numero max de automoveis\n" # Mensagem quando não cabe mais veículo
    msg_tipo_invalido:   .asciiz "Falha: tipo invalido\n" # Mensagem para tipo diferente de "c" ou "m"
    msg_ap_vazio_auto:   .asciiz "Falha: AP vazio\n"      # AP sem moradores não pode ter veículo

    # Nomes dos comandos: o parser compara o que o usuário digitou com cada um deles
    cmd_infoGeral:       .asciiz "infoGeral"   # Mostra o panorama de APs vazios e não vazios
    cmd_formatar:        .asciiz "formatar"    # Apaga todos os dados da execução atual
    cmd_limparAp:        .asciiz "limparAp"    # Exclui moradores e automóveis de um AP
    cmd_addMorador:      .asciiz "addMorador"  # Cadastra um morador em um AP
    cmd_infoAp:          .asciiz "infoAp"      # Exibe as informações de um AP ou de todos
    cmd_rmvMorador:      .asciiz "rmvMorador"  # Remove um morador de um AP pelo nome
    cmd_addAuto_min:     .asciiz "addAuto"     # Cadastra um veículo (variante com 'a' minúsculo)
    cmd_addAuto_mai:     .asciiz "AddAuto"     # Cadastra um veículo (variante com 'A' maiúsculo, aceita por convenção)

    msg_info_nao_vazios: .asciiz "Nao vazios:\t" # Rótulo de APs ocupados
    msg_info_vazios:     .asciiz "Vazios:\t\t"   # Rótulo de APs desocupados
    msg_porcentagem_ini: .asciiz " ("            # Abre o parêntese da porcentagem
    msg_porcentagem_fim: .asciiz "%)\n"          # Fecha a porcentagem e quebra a linha

    msg_ap_label:        .asciiz "AP: "          # Rótulo da linha com o número do AP
    msg_ap_vazio:        .asciiz "Apartamento vazio\n" # AP sem moradores
    msg_moradores_label: .asciiz "Moradores:\n"  # Cabeçalho da lista de moradores
    msg_carro_label:     .asciiz "Carro:\n"      # Cabeçalho da seção de carro
    msg_moto_label:      .asciiz "Moto:\n"       # Cabeçalho da seção de motos
    msg_sep_veiculo:     .asciiz " / "           # Separador entre modelo e placa
    msg_newline:         .asciiz "\n"            # Quebra de linha genérica
    str_all:             .asciiz "all"           # Constante para a opção --all do infoAp

    buffer_comando:      .space 256  # Reserva 256 bytes para o input do usuário
    buffer_int:          .space 12   # Buffer de conversão de inteiro para texto
    .align 2                         # Alinha em múltiplo de 4 bytes
    opcoes:              .space 16   # Vetor de até 4 endereços de opções
    condominio:          .space 7872 # 24 APs x 328 bytes

.text
.globl main

main:
loop_shell:
    la $a0, banner
    jal print_string_mmio

    la $a0, buffer_comando
    jal read_string_mmio

    la $a0, buffer_comando
    jal parser_comandos

    j loop_shell

# =========================================================
# FUNÇÃO: print_string_mmio
# =========================================================
print_string_mmio:
    li $t0, 0xFFFF0008
    li $t1, 0xFFFF000C
    move $t2, $a0
print_loop:
    lb $t3, 0($t2)
    beqz $t3, print_fim
aguarda_display:
    lw $t4, 0($t0)
    andi $t4, $t4, 1
    beqz $t4, aguarda_display
    sw $t3, 0($t1)
    addi $t2, $t2, 1
    j print_loop
print_fim:
    jr $ra

# =========================================================
# FUNÇÃO: print_int_mmio
# =========================================================
print_int_mmio:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    la $t0, buffer_int
    addi $t0, $t0, 11
    sb $zero, 0($t0)
    li $t1, 10
    move $t2, $a0
int_loop:
    addi $t0, $t0, -1
    divu $t2, $t1
    mfhi $t3
    mflo $t2
    addi $t3, $t3, 48
    sb $t3, 0($t0)
    bnez $t2, int_loop
    move $a0, $t0
    jal print_string_mmio
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# =========================================================
# FUNÇÃO: read_string_mmio
# =========================================================
read_string_mmio:
    li $t0, 0xFFFF0000
    li $t1, 0xFFFF0004
    move $t2, $a0
    li $t9, 0
read_loop:
    lw $t3, 0($t0)
    andi $t3, $t3, 1
    beqz $t3, read_loop
    lw $t4, 0($t1)
    li $t5, 0xFFFF0008
    li $t6, 0xFFFF000C
echo_wait:
    lw $t7, 0($t5)
    andi $t7, $t7, 1
    beqz $t7, echo_wait
    sw $t4, 0($t6)
    sb $t4, 0($t2)
    li $t8, 10
    beq $t4, $t8, read_fim
    li $t8, 8
    beq $t4, $t8, read_apaga
    li $t8, 255
    beq $t9, $t8, read_loop
    addi $t2, $t2, 1
    addi $t9, $t9, 1
    j read_loop
read_apaga:
    beqz $t9, read_loop
    addi $t2, $t2, -1
    addi $t9, $t9, -1
    j read_loop
read_fim:
    li $t8, 0
    sb $t8, 0($t2)
    jr $ra

# =========================================================
# FUNÇÃO: strcmp
# =========================================================
strcmp:
strcmp_loop:
    lb $t0, 0($a0)
    lb $t1, 0($a1)
    bne $t0, $t1, strcmp_diferente
    beqz $t0, strcmp_igual
    addi $a0, $a0, 1
    addi $a1, $a1, 1
    j strcmp_loop
strcmp_diferente:
    li $v0, 1
    jr $ra
strcmp_igual:
    li $v0, 0
    jr $ra

# =========================================================
# FUNÇÃO: strcpy
# =========================================================
strcpy:
strcpy_loop:
    beqz $a2, strcpy_fim
    lb $t0, 0($a1)
    beqz $t0, strcpy_fim
    sb $t0, 0($a0)
    addi $a0, $a0, 1
    addi $a1, $a1, 1
    addi $a2, $a2, -1
    j strcpy_loop
strcpy_fim:
    sb $zero, 0($a0)
    jr $ra

# =========================================================
# FUNÇÃO: parser_comandos
# =========================================================
parser_comandos:
    addi $sp, $sp, -12
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)
    move $s0, $a0

    lb $t0, 0($s0)
    beqz $t0, parser_fim

    move $a0, $s0
    jal separa_opcoes
    move $s1, $v0

    move $a0, $s0
    la $a1, cmd_infoGeral
    jal strcmp
    beqz $v0, executa_infoGeral

    move $a0, $s0
    la $a1, cmd_formatar
    jal strcmp
    beqz $v0, executa_formatar

    move $a0, $s0
    la $a1, cmd_limparAp
    jal strcmp
    beqz $v0, executa_limparAp

    move $a0, $s0
    la $a1, cmd_addMorador
    jal strcmp
    beqz $v0, executa_addMorador

    move $a0, $s0
    la $a1, cmd_infoAp
    jal strcmp
    beqz $v0, executa_infoAp

    move $a0, $s0
    la $a1, cmd_rmvMorador
    jal strcmp
    beqz $v0, executa_rmvMorador

    move $a0, $s0                    # Compara com "addAuto" (minúsculo)
    la $a1, cmd_addAuto_min
    jal strcmp
    beqz $v0, executa_addAuto

    move $a0, $s0                    # Compara com "AddAuto" (maiúsculo)
    la $a1, cmd_addAuto_mai
    jal strcmp
    beqz $v0, executa_addAuto

comando_invalido:
    la $a0, msg_invalido
    jal print_string_mmio
    j parser_fim

executa_infoGeral:
    bnez $s1, comando_invalido
    jal comando_infoGeral
    j parser_fim

executa_formatar:
    bnez $s1, comando_invalido
    jal comando_formatar
    j parser_fim

executa_limparAp:
    li $t0, 1
    bne $s1, $t0, comando_invalido
    la $t0, opcoes
    lw $a0, 0($t0)
    jal comando_limparAp
    j parser_fim

executa_addMorador:
    li $t0, 2
    bne $s1, $t0, comando_invalido
    la $t0, opcoes
    lw $a0, 0($t0)
    lw $a1, 4($t0)
    lb $t1, 0($a1)
    beqz $t1, comando_invalido
    jal comando_addMorador
    j parser_fim

executa_infoAp:
    li $t0, 1
    bne $s1, $t0, comando_invalido
    la $t0, opcoes
    lw $a0, 0($t0)
    jal comando_infoAp
    j parser_fim

executa_rmvMorador:
    li $t0, 2
    bne $s1, $t0, comando_invalido
    la $t0, opcoes
    lw $a0, 0($t0)
    lw $a1, 4($t0)
    lb $t1, 0($a1)
    beqz $t1, comando_invalido
    jal comando_rmvMorador
    j parser_fim

executa_addAuto:                     # Desvio do comando addAuto / AddAuto
    li $t0, 4
    bne $s1, $t0, comando_invalido   # addAuto exige exatamente 4 opções
    la $t0, opcoes
    lw $a0, 0($t0)                   # 1ª opção: número do AP
    lw $a1, 4($t0)                   # 2ª opção: tipo ("c" ou "m")
    lw $a2, 8($t0)                   # 3ª opção: modelo
    lw $a3, 12($t0)                  # 4ª opção: placa
    lb $t1, 0($a2)
    beqz $t1, comando_invalido       # Modelo vazio não vale
    lb $t1, 0($a3)
    beqz $t1, comando_invalido       # Placa vazia não vale
    jal comando_addAuto
    j parser_fim

parser_fim:
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    addi $sp, $sp, 12
    jr $ra

# =========================================================
# FUNÇÃO: separa_opcoes
# =========================================================
separa_opcoes:
    li $v0, 0
    la $t5, opcoes
sep_loop:
    lb $t0, 0($a0)
    beqz $t0, sep_fim
    li $t1, 32
    bne $t0, $t1, sep_proximo
    lb $t2, 1($a0)
    li $t1, 45
    bne $t2, $t1, sep_proximo
    lb $t2, 2($a0)
    bne $t2, $t1, sep_proximo
    sb $zero, 0($a0)
    li $t3, 4
    bge $v0, $t3, sep_conta
    sll $t4, $v0, 2
    add $t4, $t5, $t4
    addi $t6, $a0, 3
    sw $t6, 0($t4)
sep_conta:
    addi $v0, $v0, 1
    addi $a0, $a0, 3
    j sep_loop
sep_proximo:
    addi $a0, $a0, 1
    j sep_loop
sep_fim:
    jr $ra

# =========================================================
# FUNÇÃO: converte_ap
# =========================================================
converte_ap:
    li $t0, 0
    li $t1, 0
conv_loop:
    lb $t2, 0($a0)
    beqz $t2, conv_valida
    li $t3, 48
    blt $t2, $t3, conv_invalido
    li $t3, 57
    bgt $t2, $t3, conv_invalido
    addi $t2, $t2, -48
    li $t3, 10
    mul $t0, $t0, $t3
    add $t0, $t0, $t2
    addi $t1, $t1, 1
    li $t3, 4
    bgt $t1, $t3, conv_invalido
    addi $a0, $a0, 1
    j conv_loop
conv_valida:
    li $t3, 3
    blt $t1, $t3, conv_invalido
    li $t3, 100
    div $t0, $t3
    mflo $t4
    mfhi $t5
    li $t3, 1
    blt $t4, $t3, conv_invalido
    blt $t5, $t3, conv_invalido
    li $t3, 12
    bgt $t4, $t3, conv_invalido
    li $t3, 2
    bgt $t5, $t3, conv_invalido
    addi $t4, $t4, -1
    sll $t4, $t4, 1
    addi $t5, $t5, -1
    add $v0, $t4, $t5
    jr $ra
conv_invalido:
    li $v0, -1
    jr $ra

# =========================================================
# FUNÇÃO: endereco_ap
# =========================================================
endereco_ap:
    li $t0, 328
    mul $t0, $a0, $t0
    la $v0, condominio
    add $v0, $v0, $t0
    jr $ra

# =========================================================
# FUNÇÃO: comando_infoGeral
# =========================================================
comando_infoGeral:
    addi $sp, $sp, -12
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)
    li $s0, 0
    li $s1, 0
    li $t2, 24
    la $t3, condominio
loop_contagem:
    beqz $t2, exibe_relatorio
    lw $t4, 0($t3)
    beqz $t4, soma_vazio
    addi $s1, $s1, 1
    j proximo_ap
soma_vazio:
    addi $s0, $s0, 1
proximo_ap:
    addi $t3, $t3, 328
    addi $t2, $t2, -1
    j loop_contagem
exibe_relatorio:
    la $a0, msg_info_nao_vazios
    move $a1, $s1
    jal imprime_linha_info
    la $a0, msg_info_vazios
    move $a1, $s0
    jal imprime_linha_info
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    addi $sp, $sp, 12
    jr $ra

# =========================================================
# FUNÇÃO: imprime_linha_info
# =========================================================
imprime_linha_info:
    addi $sp, $sp, -8
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    move $s0, $a1
    jal print_string_mmio
    move $a0, $s0
    jal print_int_mmio
    la $a0, msg_porcentagem_ini
    jal print_string_mmio
    li $t0, 100
    mul $t0, $s0, $t0
    li $t1, 24
    div $t0, $t1
    mflo $a0
    jal print_int_mmio
    la $a0, msg_porcentagem_fim
    jal print_string_mmio
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    addi $sp, $sp, 8
    jr $ra

# =========================================================
# FUNÇÃO: comando_formatar
# =========================================================
comando_formatar:
    la $t0, condominio
    li $t1, 1968
formatar_loop:
    sw $zero, 0($t0)
    addi $t0, $t0, 4
    addi $t1, $t1, -1
    bnez $t1, formatar_loop
    jr $ra

# =========================================================
# FUNÇÃO: comando_limparAp
# =========================================================
comando_limparAp:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    jal converte_ap
    bltz $v0, limpar_invalido
    move $a0, $v0
    jal endereco_ap
    li $t1, 82
limpar_loop:
    sw $zero, 0($v0)
    addi $v0, $v0, 4
    addi $t1, $t1, -1
    bnez $t1, limpar_loop
    j limpar_fim
limpar_invalido:
    la $a0, msg_ap_invalido
    jal print_string_mmio
limpar_fim:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# =========================================================
# FUNÇÃO: comando_addMorador
# =========================================================
comando_addMorador:
    addi $sp, $sp, -12
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)
    move $s1, $a1
    jal converte_ap
    bltz $v0, add_mor_invalido
    move $a0, $v0
    jal endereco_ap
    move $s0, $v0
    lw $t0, 0($s0)
    li $t1, 6
    bge $t0, $t1, add_mor_cheio
    li $t1, 40
    mul $t1, $t0, $t1
    addi $t1, $t1, 4
    add $a0, $s0, $t1
    move $a1, $s1
    li $a2, 39
    jal strcpy
    lw $t0, 0($s0)
    addi $t0, $t0, 1
    sw $t0, 0($s0)
    j add_mor_fim
add_mor_invalido:
    la $a0, msg_ap_invalido
    jal print_string_mmio
    j add_mor_fim
add_mor_cheio:
    la $a0, msg_max_moradores
    jal print_string_mmio
add_mor_fim:
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    addi $sp, $sp, 12
    jr $ra

# =========================================================
# FUNÇÃO: comando_infoAp
# =========================================================
comando_infoAp:
    addi $sp, $sp, -12
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)
    move $s1, $a0
    la $a1, str_all
    move $a0, $s1
    jal strcmp
    bnez $v0, info_ap_unico
info_ap_all:
    li $s0, 0
info_all_loop:
    li $t0, 24
    beq $s0, $t0, info_fim
    move $a0, $s0
    jal imprime_ap
    addi $s0, $s0, 1
    j info_all_loop
info_ap_unico:
    move $a0, $s1
    jal converte_ap
    bltz $v0, info_ap_invalido
    move $a0, $v0
    jal imprime_ap
    j info_fim
info_ap_invalido:
    la $a0, msg_ap_invalido
    jal print_string_mmio
info_fim:
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    addi $sp, $sp, 12
    jr $ra

# =========================================================
# FUNÇÃO: imprime_ap
# =========================================================
imprime_ap:
    addi $sp, $sp, -16
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)
    sw $s2, 12($sp)
    move $s1, $a0
    jal endereco_ap
    move $s0, $v0
    la $a0, msg_ap_label
    jal print_string_mmio
    srl $t0, $s1, 1
    addi $t0, $t0, 1
    li $t1, 100
    mul $t0, $t0, $t1
    andi $t1, $s1, 1
    addi $t1, $t1, 1
    add $a0, $t0, $t1
    jal print_int_mmio
    la $a0, msg_newline
    jal print_string_mmio
    lw $t0, 0($s0)
    beqz $t0, imprime_ap_vazio
    la $a0, msg_moradores_label
    jal print_string_mmio
    li $s2, 0
imprime_moradores_loop:
    lw $t0, 0($s0)
    beq $s2, $t0, imprime_moradores_fim
    li $t1, 40
    mul $t1, $s2, $t1
    addi $t1, $t1, 4
    add $a0, $s0, $t1
    jal print_string_mmio
    la $a0, msg_newline
    jal print_string_mmio
    addi $s2, $s2, 1
    j imprime_moradores_loop
imprime_moradores_fim:
    lb $t0, 244($s0)
    beqz $t0, imprime_ap_fim
    li $t1, 99
    beq $t0, $t1, imprime_carro
imprime_motos:
    la $a0, msg_moto_label
    jal print_string_mmio
    li $s2, 0
    lb $t2, 245($s0)
imprime_motos_loop:
    beq $s2, $t2, imprime_ap_fim
    li $t1, 40
    mul $t1, $s2, $t1
    addi $t1, $t1, 248
    add $a0, $s0, $t1
    jal print_string_mmio
    la $a0, msg_sep_veiculo
    jal print_string_mmio
    li $t1, 40
    mul $t1, $s2, $t1
    addi $t1, $t1, 278
    add $a0, $s0, $t1
    jal print_string_mmio
    la $a0, msg_newline
    jal print_string_mmio
    addi $s2, $s2, 1
    j imprime_motos_loop
imprime_carro:
    la $a0, msg_carro_label
    jal print_string_mmio
    addi $a0, $s0, 248
    jal print_string_mmio
    la $a0, msg_sep_veiculo
    jal print_string_mmio
    addi $a0, $s0, 278
    jal print_string_mmio
    la $a0, msg_newline
    jal print_string_mmio
    j imprime_ap_fim
imprime_ap_vazio:
    la $a0, msg_ap_vazio
    jal print_string_mmio
imprime_ap_fim:
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    lw $s2, 12($sp)
    addi $sp, $sp, 16
    jr $ra

# =========================================================
# FUNÇÃO: comando_rmvMorador
# =========================================================
comando_rmvMorador:
    addi $sp, $sp, -16
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)
    sw $s2, 12($sp)
    move $s1, $a1
    jal converte_ap
    bltz $v0, rmv_mor_invalido
    move $a0, $v0
    jal endereco_ap
    move $s0, $v0
    li $s2, 0
rmv_mor_busca:
    lw $t0, 0($s0)
    beq $s2, $t0, rmv_mor_nao_acha
    li $t1, 40
    mul $t1, $s2, $t1
    addi $t1, $t1, 4
    add $a0, $s0, $t1
    move $a1, $s1
    jal strcmp
    beqz $v0, rmv_mor_achou
    addi $s2, $s2, 1
    j rmv_mor_busca
rmv_mor_achou:
    lw $t0, 0($s0)
    addi $t0, $t0, -1
    sw $t0, 0($s0)
rmv_mor_compacta:
    lw $t0, 0($s0)
    beq $s2, $t0, rmv_mor_limpa_ult
    addi $t1, $s2, 1
    li $t2, 40
    mul $t3, $t1, $t2
    addi $t3, $t3, 4
    add $a1, $s0, $t3
    mul $t3, $s2, $t2
    addi $t3, $t3, 4
    add $a0, $s0, $t3
    li $a2, 39
    jal strcpy
    addi $s2, $s2, 1
    j rmv_mor_compacta
rmv_mor_limpa_ult:
    lw $t0, 0($s0)
    li $t1, 40
    mul $t1, $t0, $t1
    addi $t1, $t1, 4
    add $t1, $s0, $t1
    li $t2, 40
rmv_mor_zera_ult:
    sb $zero, 0($t1)
    addi $t1, $t1, 1
    addi $t2, $t2, -1
    bnez $t2, rmv_mor_zera_ult
    lw $t0, 0($s0)
    bnez $t0, rmv_mor_fim
rmv_mor_apaga_veiculos:
    addi $t0, $s0, 244
    li $t1, 21
rmv_mor_zera_veic:
    sw $zero, 0($t0)
    addi $t0, $t0, 4
    addi $t1, $t1, -1
    bnez $t1, rmv_mor_zera_veic
    j rmv_mor_fim
rmv_mor_nao_acha:
    la $a0, msg_nao_encontrado
    jal print_string_mmio
    j rmv_mor_fim
rmv_mor_invalido:
    la $a0, msg_ap_invalido
    jal print_string_mmio
rmv_mor_fim:
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    lw $s2, 12($sp)
    addi $sp, $sp, 16
    jr $ra

# =========================================================
# FUNÇÃO: comando_addAuto
# =========================================================
# Cadastra um veículo | $a0 = AP, $a1 = tipo, $a2 = modelo, $a3 = placa
comando_addAuto:
    addi $sp, $sp, -20               # Abre 20 bytes na pilha
    sw $ra, 0($sp)                   # Salva o $ra
    sw $s0, 4($sp)                   # Salva o $s0 (endereço base do AP)
    sw $s1, 8($sp)                   # Salva o $s1 (tipo do veículo)
    sw $s2, 12($sp)                  # Salva o $s2 (modelo)
    sw $s3, 16($sp)                  # Salva o $s3 (placa)
    move $s1, $a1                    # Guarda o tipo antes das próximas chamadas
    move $s2, $a2                    # Guarda o modelo
    move $s3, $a3                    # Guarda a placa

    jal converte_ap                  # Converte texto do AP em índice
    bltz $v0, add_auto_invalido      # -1 = AP inválido

    move $a0, $v0
    jal endereco_ap                  # Calcula o endereço base do AP
    move $s0, $v0                    # $s0 = endereço do AP

    # Valida o tipo ANTES de qualquer outra checagem (igual ao enunciado)
    lb $t0, 0($s1)                   # Primeiro caractere do tipo
    lb $t1, 1($s1)                   # Segundo caractere (deve ser \0)
    bnez $t1, add_auto_tipo_inv      # Tipo com mais de 1 caractere é inválido
    li $t2, 99                       # ASCII 'c'
    beq $t0, $t2, add_auto_tipo_ok   # Tipo é 'c': válido
    li $t2, 109                      # ASCII 'm'
    beq $t0, $t2, add_auto_tipo_ok   # Tipo é 'm': válido
    j add_auto_tipo_inv              # Qualquer outro caractere: inválido

add_auto_tipo_ok:                    # Tipo validado; agora checa se AP tem moradores
    lw $t0, 0($s0)                   # Quantidade de moradores
    beqz $t0, add_auto_vazio         # AP sem moradores não pode ter veículo

    # Checa a regra de limite: 1 carro ou até 2 motos, sem mistura
    lb $t0, 244($s0)                 # Tipo atual de veículo no AP
    beqz $t0, add_auto_livre         # Nenhum veículo ainda: pode cadastrar

    # Já tem algum veículo — aplica a regra
    j add_auto_cheio                 # Qualquer veículo novo (carro no carro, moto no carro,
                                     # carro na moto, e a checagem de 2 motos vem abaixo)

add_auto_livre:                      # Primeiro veículo do AP
    lb $t0, 0($s1)                   # Lê o tipo do veículo a cadastrar
    li $t1, 99                       # 'c' = carro
    beq $t0, $t1, add_auto_grava     # Carro no AP vazio de veículos: OK
    j add_auto_grava_moto_check      # Moto: verifica quantas já tem (vai para 0 neste caso)

add_auto_grava_moto_check:           # Chegamos aqui quando o tipo já existente é 'm' ou quando vamos adicionar a 1ª moto
    lb $t0, 244($s0)                 # Tipo atual no AP
    beqz $t0, add_auto_grava         # Nenhum veículo ainda: pode gravar
    li $t1, 109                      # 'm'
    bne $t0, $t1, add_auto_cheio     # Tipo atual não é moto: rejeita (ex: carro no AP, chega moto)
    # Tipo atual é moto; agora checa se o novo também é moto
    lb $t0, 0($s1)
    li $t1, 109
    bne $t0, $t1, add_auto_cheio     # Novo veículo não é moto (é carro): rejeita
    lb $t0, 245($s0)                 # Quantidade atual de motos
    li $t1, 2
    bge $t0, $t1, add_auto_cheio     # Já tem 2 motos: rejeita
    j add_auto_grava                 # Cabe mais uma moto

add_auto_cheio:                      # Limite atingido ou regra violada
    la $a0, msg_max_autos            # "Falha: AP com numero max de automoveis"
    jal print_string_mmio
    j add_auto_fim

add_auto_vazio:                      # AP sem moradores
    la $a0, msg_ap_vazio_auto        # "Falha: AP vazio"
    jal print_string_mmio
    j add_auto_fim

add_auto_tipo_inv:                   # Tipo diferente de "c" ou "m"
    la $a0, msg_tipo_invalido        # "Falha: tipo invalido"
    jal print_string_mmio
    j add_auto_fim

add_auto_grava:                      # Gravação do veículo na memória
    lb $t0, 245($s0)                 # Quantidade atual de veículos (antes de gravar)
    li $t1, 40                       # Cada veículo ocupa 40 bytes
    mul $t1, $t0, $t1
    addi $t1, $t1, 248               # Offset do modelo: 248 + qtd * 40
    add $a0, $s0, $t1                # Endereço do modelo
    move $a1, $s2                    # Modelo a gravar
    li $a2, 29                       # Máximo de 29 caracteres para o modelo
    jal strcpy

    lb $t0, 245($s0)                 # Relê a quantidade para calcular o offset da placa
    li $t1, 40
    mul $t1, $t0, $t1
    addi $t1, $t1, 278               # Offset da placa: 248 + qtd*40 + 30
    add $a0, $s0, $t1                # Endereço da placa
    move $a1, $s3                    # Placa a gravar
    li $a2, 9                        # Máximo de 9 caracteres para a placa
    jal strcpy

    lb $t0, 0($s1)                   # Tipo do veículo a gravar
    sb $t0, 244($s0)                 # Atualiza o tipo no offset 244

    lb $t0, 245($s0)                 # Quantidade atual
    addi $t0, $t0, 1                 # Mais um veículo
    sb $t0, 245($s0)                 # Grava a nova quantidade no offset 245
    j add_auto_fim

add_auto_invalido:                   # AP digitado fora do intervalo do condomínio
    la $a0, msg_ap_invalido
    jal print_string_mmio

add_auto_fim:                        # Encerramento do addAuto
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    lw $s2, 12($sp)
    lw $s3, 16($sp)
    addi $sp, $sp, 20
    jr $ra