# =========================================================
# CABEÇALHO DA ATIVIDADE
# Nome do Grupo: Letícia Medeiros Cavalcante e Sarah Pereira de Lima
# Atividade: Projeto 01 (PE1) da 1a VA
# Disciplina: Arquitetura e Organização de Computadores
# Semestre Letivo: 2026.2
# Breve descrição: Implementação da base do comando infoGeral, que
#                  percorre os 24 apartamentos e exibe a quantidade
#                  e a porcentagem de APs vazios e não vazios.
# =========================================================

.data                                # Seção de variáveis estáticas na memória
    banner:              .asciiz "LS-shell>> " # Banner com nossas iniciais exigido pelo projeto
    msg_invalido:        .asciiz "Comando invalido\n" # Mensagem padrão para comandos não reconhecidos

    msg_info_nao_vazios: .asciiz "Nao vazios:\t" # Rótulo da linha de APs ocupados (sem acento por causa do MMIO)
    msg_info_vazios:     .asciiz "Vazios:\t\t"   # Rótulo da linha de APs desocupados
    msg_porcentagem_ini: .asciiz " ("            # Abre o parêntese da porcentagem
    msg_porcentagem_fim: .asciiz "%)\n"          # Fecha a porcentagem e quebra a linha

    buffer_comando:      .space 256  # Reserva 256 bytes contíguos para armazenar o input do usuário
    buffer_int:          .space 12   # Espaço para converter um inteiro em texto antes de imprimir
    .align 2                         # Alinha o próximo dado em endereço múltiplo de 4 (exigido pelo lw)
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
    bnez $t2, int_loop               # Repete enquanto ainda houver dígitos (imprime "0" se for zero)

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

    addi $t2, $t2, 1                 # Avança o ponteiro do buffer
    j read_loop                      # Espera a próxima tecla
read_fim:                            # Finalização do buffer
    li $t8, 0                        # Carrega o valor do \0
    addi $t2, $t2, 1                 # Avança uma casa
    sb $t8, 0($t2)                   # Insere o terminador nulo na string
    jr $ra                           # Retorna

# =========================================================
# FUNÇÃO: parser_comandos
# =========================================================
parser_comandos:                     # Rotina de interpretação (decifra o que o usuário quer)
    lb $t0, 0($a0)                   # Lê o primeiro caractere digitado no buffer
    li $t1, 10                       # Carrega o código do Enter
    beq $t0, $t1, parser_fim         # Se for apenas Enter, ignoramos e voltamos para o prompt

    la $a0, msg_invalido             # Caso o comando seja desconhecido, puxa a mensagem de erro

    addi $sp, $sp, -4                # Abre um espaço de 4 bytes na pilha (stack)
    sw $ra, 0($sp)                   # Salva nosso $ra na pilha para não perdermos a volta após o jal

    jal print_string_mmio            # Chama a função de print para exibir "Comando invalido"

    lw $ra, 0($sp)                   # Recupera nosso $ra original da pilha
    addi $sp, $sp, 4                 # Desaloca o espaço da pilha (restaura o $sp)

parser_fim:                          # Encerramento do interpretador
    jr $ra                           # Retorna para o loop do shell

# =========================================================
# FUNÇÃO: comando_infoGeral
# =========================================================
comando_infoGeral:                   # Conta e exibe APs vazios e não vazios
    addi $sp, $sp, -12               # Abre 12 bytes na pilha
    sw $ra, 0($sp)                   # Salva o $ra (vamos chamar outras funções)
    sw $s0, 4($sp)                   # Salva o $s0 para usar como contador
    sw $s1, 8($sp)                   # Salva o $s1 para usar como contador

    li $s0, 0                        # $s0 = quantidade de APs vazios
    li $s1, 0                        # $s1 = quantidade de APs não vazios
    li $t2, 24                       # Total de APs no condomínio (12 andares x 2 APs)
    la $t3, condominio               # Ponteiro para o primeiro AP

loop_contagem:                       # Percorre todos os APs
    beqz $t2, exibe_relatorio        # Quando acabarem os APs, vai exibir o resultado
    lw $t4, 0($t3)                   # Lê a primeira word do AP (0 = AP vazio)
    beqz $t4, soma_vazio             # Se for zero, conta como vazio
    addi $s1, $s1, 1                 # Senão, conta como não vazio
    j proximo_ap                     # Pula para o próximo AP
soma_vazio:                          # AP sem moradores
    addi $s0, $s0, 1                 # Incrementa os vazios
proximo_ap:                          # Avança na memória
    addi $t3, $t3, 328               # Pula os 328 bytes do AP atual
    addi $t2, $t2, -1                # Um AP a menos para verificar
    j loop_contagem                  # Repete o laço

exibe_relatorio:                     # Imprime as duas linhas do relatório
    la $a0, msg_info_nao_vazios      # Rótulo "Nao vazios:"
    move $a1, $s1                    # Quantidade de não vazios
    jal imprime_linha_info           # Imprime a linha com quantidade e porcentagem

    la $a0, msg_info_vazios          # Rótulo "Vazios:"
    move $a1, $s0                    # Quantidade de vazios
    jal imprime_linha_info           # Imprime a linha com quantidade e porcentagem

    lw $ra, 0($sp)                   # Restaura o $ra
    lw $s0, 4($sp)                   # Restaura o $s0
    lw $s1, 8($sp)                   # Restaura o $s1
    addi $sp, $sp, 12                # Desaloca a pilha
    jr $ra                           # Retorna para quem chamou

# =========================================================
# FUNÇÃO: imprime_linha_info
# =========================================================
imprime_linha_info:                  # Imprime "<rótulo><qtd> (<pct>%)" | $a0 = rótulo, $a1 = qtd
    addi $sp, $sp, -8                # Abre 8 bytes na pilha
    sw $ra, 0($sp)                   # Salva o $ra
    sw $s0, 4($sp)                   # Salva o $s0
    move $s0, $a1                    # Guarda a quantidade (as chamadas abaixo sobrescrevem $t e $a)

    jal print_string_mmio            # Imprime o rótulo que veio em $a0

    move $a0, $s0                    # Passa a quantidade
    jal print_int_mmio               # Imprime a quantidade

    la $a0, msg_porcentagem_ini      # Carrega " ("
    jal print_string_mmio            # Imprime " ("

    li $t0, 100                      # Fator para calcular a porcentagem
    mul $t0, $s0, $t0                # quantidade x 100
    li $t1, 24                       # Total de APs
    div $t0, $t1                     # (quantidade x 100) / 24
    mflo $a0                         # Pega o quociente (porcentagem inteira)
    jal print_int_mmio               # Imprime a porcentagem

    la $a0, msg_porcentagem_fim      # Carrega "%)\n"
    jal print_string_mmio            # Imprime "%)" e quebra a linha

    lw $ra, 0($sp)                   # Restaura o $ra
    lw $s0, 4($sp)                   # Restaura o $s0
    addi $sp, $sp, 8                 # Desaloca a pilha
    jr $ra                           # Retorna