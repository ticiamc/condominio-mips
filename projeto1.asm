# =========================================================
# Nome do Grupo: Letícia Medeiros Cavalcante e Sarah Pereira de Lima
# Atividade: Projeto 01 (PE1) da 1a VA
# Disciplina: Arquitetura e Organização de Computadores
# Semestre Letivo: 2026.2
# Breve descrição: Implementação do comando rmvMorador, que remove
#                  um morador de um AP pelo nome, compacta a lista
#                  de nomes e, se o AP esvaziar, apaga os veículos.
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

    # Nomes dos comandos: o parser compara o que o usuário digitou com cada um deles
    cmd_infoGeral:       .asciiz "infoGeral"   # Comando que mostra o panorama de APs vazios e não vazios
    cmd_formatar:        .asciiz "formatar"    # Comando que apaga todos os dados da execução atual
    cmd_limparAp:        .asciiz "limparAp"    # Comando que exclui moradores e automóveis de um AP
    cmd_addMorador:      .asciiz "addMorador"  # Comando que cadastra um morador em um AP
    cmd_infoAp:          .asciiz "infoAp"      # Comando que exibe as informações de um AP ou de todos
    cmd_rmvMorador:      .asciiz "rmvMorador"  # Comando que remove um morador de um AP pelo nome

    msg_info_nao_vazios: .asciiz "Nao vazios:\t" # Rótulo da linha de APs ocupados
    msg_info_vazios:     .asciiz "Vazios:\t\t"   # Rótulo da linha de APs desocupados
    msg_porcentagem_ini: .asciiz " ("            # Abre o parêntese da porcentagem
    msg_porcentagem_fim: .asciiz "%)\n"          # Fecha a porcentagem e quebra a linha

    msg_ap_label:        .asciiz "AP: "          # Rótulo da linha com o número do AP
    msg_ap_vazio:        .asciiz "Apartamento vazio\n" # Texto para AP sem moradores
    msg_moradores_label: .asciiz "Moradores:\n"  # Cabeçalho da lista de moradores
    msg_carro_label:     .asciiz "Carro:\n"      # Cabeçalho da seção de carro
    msg_moto_label:      .asciiz "Moto:\n"       # Cabeçalho da seção de motos
    msg_sep_veiculo:     .asciiz " / "           # Separador entre modelo e placa de cada veículo
    msg_newline:         .asciiz "\n"            # Quebra de linha genérica
    str_all:             .asciiz "all"           # Constante para comparar com a opção --all

    buffer_comando:      .space 256  # Reserva 256 bytes contíguos para armazenar o input do usuário
    buffer_int:          .space 12   # Espaço para converter um inteiro em texto antes de imprimir
    .align 2                         # Alinha o próximo dado em endereço múltiplo de 4 (exigido pelo lw)
    opcoes:              .space 16   # Guardamos aqui o endereço de até 4 opções (4 palavras de 4 bytes)
    condominio:          .space 7872 # Memória do banco de dados: 24 APs gastando 328 bytes cada

.text                                # Seção onde começam as instruções de código
.globl main                          # Declara a função main como ponto de entrada global

main:                                # Ponto de partida do programa
loop_shell:                          # Loop infinito que mantém nosso terminal rodando
    la $a0, banner                   # Carrega o endereço do nosso banner no registrador $a0
    jal print_string_mmio            # Chama a função de imprimir e salva o retorno no $ra

    la $a0, buffer_comando           # Passa o endereço do nosso buffer para guardar o texto
    jal read_string_mmio             # Chama a rotina de leitura do teclado byte a byte

    la $a0, buffer_comando           # Passa o buffer preenchido como argumento
    jal parser_comandos              # Envia a string para o interpretador de comandos

    j loop_shell                     # Retorna ao início do loop para pedir o próximo comando

# =========================================================
# FUNÇÃO: print_string_mmio
# =========================================================
print_string_mmio:                   # Rotina para imprimir strings no terminal via Display MMIO
    li $t0, 0xFFFF0008               # Carrega o endereço do Transmitter Control
    li $t1, 0xFFFF000C               # Carrega o endereço do Transmitter Data
    move $t2, $a0                    # Copia o endereço da string recebida para iteração
print_loop:                          # Laço para iterar a string
    lb $t3, 0($t2)                   # Carrega 1 byte (caractere atual)
    beqz $t3, print_fim              # Sai da função se encontrar o caractere nulo
aguarda_display:                     # Laço de espera ocupada (polling) do display
    lw $t4, 0($t0)                   # Lê o status atual do controle
    andi $t4, $t4, 1                 # Isola o bit 0 (Ready)
    beqz $t4, aguarda_display        # Continua no loop se o hardware estiver ocupado
    sw $t3, 0($t1)                   # Envia o caractere para exibição
    addi $t2, $t2, 1                 # Avança para o próximo caractere
    j print_loop                     # Reinicia o laço de leitura
print_fim:                           # Fim da impressão
    jr $ra                           # Retorna para a rotina chamadora

# =========================================================
# FUNÇÃO: print_int_mmio
# =========================================================
print_int_mmio:                      # Rotina para imprimir um inteiro não negativo via Display MMIO
    addi $sp, $sp, -4                # Abre espaço na pilha
    sw $ra, 0($sp)                   # Salva o $ra, pois vamos chamar print_string_mmio

    la $t0, buffer_int               # Carrega o início do buffer de conversão
    addi $t0, $t0, 11                # Aponta para o último byte do buffer
    sb $zero, 0($t0)                 # Coloca o terminador nulo no final
    li $t1, 10                       # Divisor 10 para separar os dígitos
    move $t2, $a0                    # Copia o número recebido
int_loop:                            # Laço que monta os dígitos de trás para frente
    addi $t0, $t0, -1                # Recua uma posição no buffer
    divu $t2, $t1                    # Divide o número por 10
    mfhi $t3                         # Resto = dígito atual
    mflo $t2                         # Quociente = número que sobra
    addi $t3, $t3, 48                # Converte o dígito para ASCII ('0' = 48)
    sb $t3, 0($t0)                   # Guarda o caractere no buffer
    bnez $t2, int_loop               # Repete enquanto ainda houver dígitos

    move $a0, $t0                    # Passa o início do número montado
    jal print_string_mmio            # Imprime o número como string

    lw $ra, 0($sp)                   # Recupera o $ra
    addi $sp, $sp, 4                 # Desaloca a pilha
    jr $ra                           # Retorna

# =========================================================
# FUNÇÃO: read_string_mmio
# =========================================================
read_string_mmio:                    # Rotina para capturar a digitação do usuário via Keyboard MMIO
    li $t0, 0xFFFF0000               # Carrega o endereço do Receiver Control
    li $t1, 0xFFFF0004               # Carrega o endereço do Receiver Data
    move $t2, $a0                    # Usa o $t2 para iterar no nosso buffer
    li $t9, 0                        # Usa o $t9 para contar quantos caracteres já guardamos
read_loop:                           # Laço de espera pela digitação
    lw $t3, 0($t0)                   # Lê o status do teclado
    andi $t3, $t3, 1                 # Isola o bit Ready
    beqz $t3, read_loop              # Segura no loop até ter uma tecla nova
    lw $t4, 0($t1)                   # Lê a tecla digitada

    li $t5, 0xFFFF0008               # Endereço controle display (Echo)
    li $t6, 0xFFFF000C               # Endereço dados display (Echo)
echo_wait:                           # Aguarda o display liberar para o echo
    lw $t7, 0($t5)                   # Lê o controle do display
    andi $t7, $t7, 1                 # Isola o bit pronto
    beqz $t7, echo_wait              # Segura o loop
    sw $t4, 0($t6)                   # Imprime a tecla dando feedback visual ao usuário

    sb $t4, 0($t2)                   # Salva a tecla lida no buffer

    li $t8, 10                       # Código ASCII do Enter (\n)
    beq $t4, $t8, read_fim           # Sai do loop de leitura se o usuário der Enter

    li $t8, 8                        # Código ASCII do Backspace
    beq $t4, $t8, read_apaga         # Se o usuário apagou um caractere, tratamos separado

    li $t8, 255                      # Limite do nosso buffer (o último byte fica para o \0)
    beq $t9, $t8, read_loop          # Se o buffer encheu, não avançamos mais para não estourar a memória

    addi $t2, $t2, 1                 # Avança o ponteiro do buffer
    addi $t9, $t9, 1                 # Conta mais um caractere guardado
    j read_loop                      # Espera a próxima tecla
read_apaga:                          # Tratamento do Backspace
    beqz $t9, read_loop              # Se o buffer estiver vazio, não tem o que apagar
    addi $t2, $t2, -1                # Volta uma posição no nosso buffer
    addi $t9, $t9, -1                # Desconta o caractere apagado
    j read_loop                      # Espera a próxima tecla
read_fim:                            # Finalização do buffer
    li $t8, 0                        # Carrega o valor do \0
    sb $t8, 0($t2)                   # Trocamos o \n pelo \0 para facilitar a comparação no parser
    jr $ra                           # Retorna

# =========================================================
# FUNÇÃO: strcmp
# =========================================================
strcmp:                              # Compara duas strings ($a0 e $a1) e devolve o resultado no $v0
strcmp_loop:                         # Laço que anda pelas duas strings ao mesmo tempo
    lb $t0, 0($a0)                   # Carrega 1 byte da primeira string
    lb $t1, 0($a1)                   # Carrega 1 byte da segunda string
    bne $t0, $t1, strcmp_diferente   # Caracteres diferentes: strings diferentes
    beqz $t0, strcmp_igual           # \0 em ambas: strings iguais
    addi $a0, $a0, 1                 # Avança na primeira string
    addi $a1, $a1, 1                 # Avança na segunda string
    j strcmp_loop                    # Reinicia o laço
strcmp_diferente:                    # Strings diferentes
    li $v0, 1                        # Devolve 1
    jr $ra                           # Retorna
strcmp_igual:                        # Strings iguais
    li $v0, 0                        # Devolve 0
    jr $ra                           # Retorna

# =========================================================
# FUNÇÃO: strcpy
# =========================================================
strcpy:                              # Copia uma string com limite | $a0 = destino, $a1 = origem, $a2 = máx.
strcpy_loop:                         # Laço que copia caractere a caractere
    beqz $a2, strcpy_fim             # Atingiu o máximo: para
    lb $t0, 0($a1)                   # Carrega 1 byte da origem
    beqz $t0, strcpy_fim             # \0 da origem: termina
    sb $t0, 0($a0)                   # Grava no destino
    addi $a0, $a0, 1                 # Avança no destino
    addi $a1, $a1, 1                 # Avança na origem
    addi $a2, $a2, -1                # Um caractere a menos que cabe
    j strcpy_loop                    # Reinicia o laço
strcpy_fim:                          # Fim da cópia
    sb $zero, 0($a0)                 # Fecha a string com \0
    jr $ra                           # Retorna

# =========================================================
# FUNÇÃO: parser_comandos
# =========================================================
parser_comandos:                     # Rotina de interpretação (decifra o que o usuário quer)
    addi $sp, $sp, -12               # Abre 12 bytes na pilha
    sw $ra, 0($sp)                   # Salva o $ra
    sw $s0, 4($sp)                   # Salva o $s0
    sw $s1, 8($sp)                   # Salva o $s1 (quantidade de opções)
    move $s0, $a0                    # Guarda o endereço do buffer

    lb $t0, 0($s0)                   # Lê o primeiro caractere
    beqz $t0, parser_fim             # Linha vazia: ignora

    move $a0, $s0                    # Passa o buffer para separar as opções
    jal separa_opcoes                # Corta a string em cada " --"
    move $s1, $v0                    # Guarda a quantidade de opções

    move $a0, $s0                    # Compara com "infoGeral"
    la $a1, cmd_infoGeral
    jal strcmp
    beqz $v0, executa_infoGeral

    move $a0, $s0                    # Compara com "formatar"
    la $a1, cmd_formatar
    jal strcmp
    beqz $v0, executa_formatar

    move $a0, $s0                    # Compara com "limparAp"
    la $a1, cmd_limparAp
    jal strcmp
    beqz $v0, executa_limparAp

    move $a0, $s0                    # Compara com "addMorador"
    la $a1, cmd_addMorador
    jal strcmp
    beqz $v0, executa_addMorador

    move $a0, $s0                    # Compara com "infoAp"
    la $a1, cmd_infoAp
    jal strcmp
    beqz $v0, executa_infoAp

    move $a0, $s0                    # Compara com "rmvMorador"
    la $a1, cmd_rmvMorador
    jal strcmp
    beqz $v0, executa_rmvMorador

comando_invalido:                    # Comando não reconhecido ou opções erradas
    la $a0, msg_invalido             # "Comando invalido"
    jal print_string_mmio
    j parser_fim

executa_infoGeral:
    bnez $s1, comando_invalido       # infoGeral não aceita opções
    jal comando_infoGeral
    j parser_fim

executa_formatar:
    bnez $s1, comando_invalido       # formatar não aceita opções
    jal comando_formatar
    j parser_fim

executa_limparAp:
    li $t0, 1
    bne $s1, $t0, comando_invalido   # limparAp exige 1 opção
    la $t0, opcoes
    lw $a0, 0($t0)                   # 1ª opção: número do AP
    jal comando_limparAp
    j parser_fim

executa_addMorador:
    li $t0, 2
    bne $s1, $t0, comando_invalido   # addMorador exige 2 opções
    la $t0, opcoes
    lw $a0, 0($t0)                   # 1ª opção: número do AP
    lw $a1, 4($t0)                   # 2ª opção: nome do morador
    lb $t1, 0($a1)
    beqz $t1, comando_invalido       # Nome vazio não vale
    jal comando_addMorador
    j parser_fim

executa_infoAp:
    li $t0, 1
    bne $s1, $t0, comando_invalido   # infoAp exige 1 opção
    la $t0, opcoes
    lw $a0, 0($t0)                   # 1ª opção: AP ou "all"
    jal comando_infoAp
    j parser_fim

executa_rmvMorador:                  # Desvio do comando rmvMorador
    li $t0, 2
    bne $s1, $t0, comando_invalido   # rmvMorador exige 2 opções (AP e nome)
    la $t0, opcoes
    lw $a0, 0($t0)                   # 1ª opção: número do AP
    lw $a1, 4($t0)                   # 2ª opção: nome do morador a remover
    lb $t1, 0($a1)
    beqz $t1, comando_invalido       # Nome vazio não vale
    jal comando_rmvMorador
    j parser_fim

parser_fim:                          # Encerramento do interpretador
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    addi $sp, $sp, 12
    jr $ra

# =========================================================
# FUNÇÃO: separa_opcoes
# =========================================================
separa_opcoes:                       # Divide o comando em cada " --" | $a0 = buffer, $v0 = qtd de opções
    li $v0, 0
    la $t5, opcoes
sep_loop:
    lb $t0, 0($a0)
    beqz $t0, sep_fim
    li $t1, 32                       # ASCII do espaço
    bne $t0, $t1, sep_proximo
    lb $t2, 1($a0)
    li $t1, 45                       # ASCII do '-'
    bne $t2, $t1, sep_proximo
    lb $t2, 2($a0)
    bne $t2, $t1, sep_proximo        # Precisa de dois '-'

    sb $zero, 0($a0)                 # Encerra a parte anterior com \0
    li $t3, 4
    bge $v0, $t3, sep_conta          # Vetor cheio: só conta
    sll $t4, $v0, 2
    add $t4, $t5, $t4
    addi $t6, $a0, 3                 # A opção começa 3 bytes à frente do " --"
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
converte_ap:                         # Transforma o texto do AP em índice | $a0 = string, $v0 = 0..23 ou -1
    li $t0, 0
    li $t1, 0
conv_loop:
    lb $t2, 0($a0)
    beqz $t2, conv_valida
    li $t3, 48                       # ASCII '0'
    blt $t2, $t3, conv_invalido
    li $t3, 57                       # ASCII '9'
    bgt $t2, $t3, conv_invalido
    addi $t2, $t2, -48               # Valor numérico do dígito
    li $t3, 10
    mul $t0, $t0, $t3
    add $t0, $t0, $t2
    addi $t1, $t1, 1
    li $t3, 4
    bgt $t1, $t3, conv_invalido      # Mais de 4 dígitos: inválido
    addi $a0, $a0, 1
    j conv_loop
conv_valida:
    li $t3, 3
    blt $t1, $t3, conv_invalido      # Menos de 3 dígitos: inválido
    li $t3, 100
    div $t0, $t3
    mflo $t4                         # Andar
    mfhi $t5                         # Final do AP
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
    add $v0, $t4, $t5                # Índice = (andar-1)*2 + (final-1)
    jr $ra
conv_invalido:
    li $v0, -1
    jr $ra

# =========================================================
# FUNÇÃO: endereco_ap
# =========================================================
endereco_ap:                         # Calcula o endereço do AP na memória | $a0 = índice, $v0 = endereço
    li $t0, 328                      # Tamanho de cada AP em bytes
    mul $t0, $a0, $t0
    la $v0, condominio
    add $v0, $v0, $t0
    jr $ra

# =========================================================
# FUNÇÃO: comando_infoGeral
# =========================================================
comando_infoGeral:                   # Conta e exibe APs vazios e não vazios
    addi $sp, $sp, -12
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)

    li $s0, 0                        # Contador de APs vazios
    li $s1, 0                        # Contador de APs não vazios
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
imprime_linha_info:                  # Imprime "<rótulo><qtd> (<pct>%)" | $a0 = rótulo, $a1 = qtd
    addi $sp, $sp, -8
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    move $s0, $a1

    jal print_string_mmio            # Imprime o rótulo

    move $a0, $s0
    jal print_int_mmio               # Imprime a quantidade

    la $a0, msg_porcentagem_ini
    jal print_string_mmio

    li $t0, 100
    mul $t0, $s0, $t0
    li $t1, 24
    div $t0, $t1
    mflo $a0
    jal print_int_mmio               # Imprime a porcentagem

    la $a0, msg_porcentagem_fim
    jal print_string_mmio

    lw $ra, 0($sp)
    lw $s0, 4($sp)
    addi $sp, $sp, 8
    jr $ra

# =========================================================
# FUNÇÃO: comando_formatar
# =========================================================
comando_formatar:                    # Zera todos os APs (não afeta o arquivo salvo)
    la $t0, condominio
    li $t1, 1968                     # 7872 bytes / 4 = 1968 palavras
formatar_loop:
    sw $zero, 0($t0)
    addi $t0, $t0, 4
    addi $t1, $t1, -1
    bnez $t1, formatar_loop
    jr $ra

# =========================================================
# FUNÇÃO: comando_limparAp
# =========================================================
comando_limparAp:                    # Esvazia um AP | $a0 = string com o número do AP
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    jal converte_ap
    bltz $v0, limpar_invalido

    move $a0, $v0
    jal endereco_ap
    li $t1, 82                       # 328 bytes / 4 = 82 palavras
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
comando_addMorador:                  # Cadastra um morador | $a0 = string do AP, $a1 = nome
    addi $sp, $sp, -12
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)
    move $s1, $a1                    # Guarda o nome antes das próximas chamadas

    jal converte_ap
    bltz $v0, add_mor_invalido

    move $a0, $v0
    jal endereco_ap
    move $s0, $v0                    # $s0 = endereço base do AP

    lw $t0, 0($s0)                   # Quantidade de moradores atual
    li $t1, 6
    bge $t0, $t1, add_mor_cheio     # Já tem 6: rejeita

    li $t1, 40
    mul $t1, $t0, $t1
    addi $t1, $t1, 4                 # Offset do próximo nome
    add $a0, $s0, $t1
    move $a1, $s1
    li $a2, 39                       # Máximo de 39 caracteres para o nome
    jal strcpy

    lw $t0, 0($s0)
    addi $t0, $t0, 1                 # Incrementa o contador de moradores
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
# Exibe informações de um AP ou de todos | $a0 = string da opção
comando_infoAp:
    addi $sp, $sp, -12
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)
    move $s1, $a0                    # Guarda a string da opção

    la $a1, str_all
    move $a0, $s1
    jal strcmp
    bnez $v0, info_ap_unico          # Se não for "all", exibe apenas um AP

info_ap_all:                         # Percorre os 24 APs em ordem
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
# Imprime todas as informações de um AP | $a0 = índice (0 a 23)
imprime_ap:
    addi $sp, $sp, -16
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)
    sw $s2, 12($sp)
    move $s1, $a0                    # Guarda o índice para calcular o número do AP

    jal endereco_ap
    move $s0, $v0                    # $s0 = endereço base do AP

    la $a0, msg_ap_label             # "AP: "
    jal print_string_mmio

    srl $t0, $s1, 1                  # índice / 2 = andar - 1
    addi $t0, $t0, 1                 # andar
    li $t1, 100
    mul $t0, $t0, $t1                # andar * 100
    andi $t1, $s1, 1                 # índice mod 2
    addi $t1, $t1, 1                 # número do AP no andar
    add $a0, $t0, $t1                # número completo do AP
    jal print_int_mmio

    la $a0, msg_newline
    jal print_string_mmio

    lw $t0, 0($s0)                   # Quantidade de moradores
    beqz $t0, imprime_ap_vazio       # AP vazio: mostra mensagem e encerra

    la $a0, msg_moradores_label      # "Moradores:\n"
    jal print_string_mmio

    li $s2, 0                        # Contador de moradores impressos
imprime_moradores_loop:
    lw $t0, 0($s0)
    beq $s2, $t0, imprime_moradores_fim
    li $t1, 40
    mul $t1, $s2, $t1
    addi $t1, $t1, 4                 # Offset do nome atual
    add $a0, $s0, $t1
    jal print_string_mmio
    la $a0, msg_newline
    jal print_string_mmio
    addi $s2, $s2, 1
    j imprime_moradores_loop

imprime_moradores_fim:
    lb $t0, 244($s0)                 # Tipo de veículo
    beqz $t0, imprime_ap_fim         # Sem veículo: encerra

    li $t1, 99                       # ASCII 'c'
    beq $t0, $t1, imprime_carro

imprime_motos:
    la $a0, msg_moto_label           # "Moto:\n"
    jal print_string_mmio

    li $s2, 0
    lb $t2, 245($s0)                 # Quantidade de motos
imprime_motos_loop:
    beq $s2, $t2, imprime_ap_fim
    li $t1, 40
    mul $t1, $s2, $t1
    addi $t1, $t1, 248               # Offset do modelo da moto atual
    add $a0, $s0, $t1
    jal print_string_mmio
    la $a0, msg_sep_veiculo
    jal print_string_mmio
    li $t1, 40
    mul $t1, $s2, $t1
    addi $t1, $t1, 278               # Offset da placa (248 + 30)
    add $a0, $s0, $t1
    jal print_string_mmio
    la $a0, msg_newline
    jal print_string_mmio
    addi $s2, $s2, 1
    j imprime_motos_loop

imprime_carro:
    la $a0, msg_carro_label          # "Carro:\n"
    jal print_string_mmio
    addi $a0, $s0, 248               # Modelo do carro no offset 248
    jal print_string_mmio
    la $a0, msg_sep_veiculo
    jal print_string_mmio
    addi $a0, $s0, 278               # Placa do carro no offset 278
    jal print_string_mmio
    la $a0, msg_newline
    jal print_string_mmio
    j imprime_ap_fim

imprime_ap_vazio:
    la $a0, msg_ap_vazio             # "Apartamento vazio\n"
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
# Remove um morador de um AP | $a0 = string do AP, $a1 = nome do morador
comando_rmvMorador:
    addi $sp, $sp, -16               # Abre 16 bytes na pilha
    sw $ra, 0($sp)                   # Salva o $ra
    sw $s0, 4($sp)                   # Salva o $s0 (endereço base do AP)
    sw $s1, 8($sp)                   # Salva o $s1 (nome do morador a remover)
    sw $s2, 12($sp)                  # Salva o $s2 (índice da busca)
    move $s1, $a1                    # Guarda o nome antes das próximas chamadas

    jal converte_ap                  # Converte texto do AP em índice
    bltz $v0, rmv_mor_invalido       # -1 = AP inválido

    move $a0, $v0
    jal endereco_ap                  # Calcula o endereço base do AP
    move $s0, $v0                    # $s0 = endereço do AP

    li $s2, 0                        # Índice do morador atual na busca
rmv_mor_busca:                       # Laço para encontrar o nome na lista
    lw $t0, 0($s0)                   # Quantidade de moradores
    beq $s2, $t0, rmv_mor_nao_acha  # Percorreu todos sem encontrar
    li $t1, 40
    mul $t1, $s2, $t1
    addi $t1, $t1, 4                 # Offset do nome atual
    add $a0, $s0, $t1                # Endereço do nome atual
    move $a1, $s1                    # Nome a procurar
    jal strcmp                       # Compara
    beqz $v0, rmv_mor_achou         # Encontrou o morador
    addi $s2, $s2, 1                 # Avança para o próximo
    j rmv_mor_busca

rmv_mor_achou:                       # Morador encontrado na posição $s2
    lw $t0, 0($s0)                   # Quantidade atual de moradores
    addi $t0, $t0, -1                # Nova quantidade após a remoção
    sw $t0, 0($s0)                   # Atualiza o contador

    # Compacta: copia cada nome seguinte uma vaga para cima
rmv_mor_compacta:                    # Laço de compactação da lista
    lw $t0, 0($s0)                   # Quantidade após remoção
    beq $s2, $t0, rmv_mor_limpa_ult # Chegou na última vaga preenchida
    addi $t1, $s2, 1                 # Índice do próximo morador
    li $t2, 40
    mul $t3, $t1, $t2
    addi $t3, $t3, 4                 # Offset do nome seguinte (origem)
    add $a1, $s0, $t3                # Endereço da origem
    mul $t3, $s2, $t2
    addi $t3, $t3, 4                 # Offset da vaga atual (destino)
    add $a0, $s0, $t3                # Endereço do destino
    li $a2, 39                       # Máximo de 39 caracteres
    jal strcpy                       # Copia o nome seguinte para a posição atual
    addi $s2, $s2, 1                 # Avança para a próxima posição
    j rmv_mor_compacta               # Continua compactando

rmv_mor_limpa_ult:                   # Apaga o último nome (que ficou duplicado)
    lw $t0, 0($s0)                   # Quantidade atualizada
    li $t1, 40
    mul $t1, $t0, $t1
    addi $t1, $t1, 4                 # Offset da última vaga agora vazia
    add $t1, $s0, $t1                # Endereço da última vaga
    li $t2, 40                       # Zera os 40 bytes da vaga
rmv_mor_zera_ult:
    sb $zero, 0($t1)
    addi $t1, $t1, 1
    addi $t2, $t2, -1
    bnez $t2, rmv_mor_zera_ult

    # Se o AP ficou vazio, apaga os veículos também
    lw $t0, 0($s0)                   # Quantidade após remoção
    bnez $t0, rmv_mor_fim            # Ainda tem moradores: não apaga veículos

rmv_mor_apaga_veiculos:              # AP esvaziou: zera a área de veículos
    addi $t0, $s0, 244               # Começa no offset 244 (tipo de veículo)
    li $t1, 21                       # 84 bytes = 21 palavras (do offset 244 ao 327)
rmv_mor_zera_veic:
    sw $zero, 0($t0)
    addi $t0, $t0, 4
    addi $t1, $t1, -1
    bnez $t1, rmv_mor_zera_veic
    j rmv_mor_fim                    # Veículos apagados: encerra

rmv_mor_nao_acha:                    # Nome não encontrado na lista
    la $a0, msg_nao_encontrado       # "Falha: morador nao encontrado"
    jal print_string_mmio
    j rmv_mor_fim

rmv_mor_invalido:                    # AP digitado fora do intervalo do condomínio
    la $a0, msg_ap_invalido          # "Falha: AP invalido"
    jal print_string_mmio

rmv_mor_fim:                         # Encerramento do rmvMorador
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    lw $s2, 12($sp)
    addi $sp, $sp, 16
    jr $ra