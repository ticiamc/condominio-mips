# =========================================================
# CABEÇALHO DA ATIVIDADE
# Nome do Grupo: Letícia Medeiros Cavalcante e Sarah Pereira de Lima
# Atividade: Projeto 01 (PE1) da 1a VA
# Disciplina: Arquitetura e Organização de Computadores
# Semestre Letivo: 2026.2
# Breve descrição: Adição da base do Parser. Esta rotina será
#                  responsável por interpretar as strings lidas 
#                  no terminal e direcionar para os comandos.
# =========================================================

.data                                # Seção de variáveis estáticas na memória
    banner:          .asciiz "LS-shell>> " # Banner com nossas iniciais exigido pelo projeto
    msg_invalido:    .asciiz "Comando invalido\n" # Mensagem padrão para comandos não reconhecidos
    buffer_comando:  .space 256      # Reserva 256 bytes contíguos para armazenar o input do usuário
    condominio:      .space 7872     # Memória do banco de dados: 24 APs gastando 328 bytes cada

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