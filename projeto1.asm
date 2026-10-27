# =========================================================
# CABEÇALHO DA ATIVIDADE
# Nome do Grupo: Letícia Medeiros Cavalcante e Sarah Pereira de Lima
# Atividade: Projeto 01 (PE1) da 1a VA
# Disciplina: Arquitetura e Organização de Computadores
# Semestre Letivo: 2026.2
# Breve descrição: Estrutura inicial do sistema de cadastro do condomínio.
#                  Contém o loop principal do terminal (shell) e as funções 
#                  de entrada/saída utilizando Keyboard e Display MMIO.
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
    
    j loop_shell                     # Retorna ao início do loop para pedir o próximo comando

# =========================================================
# FUNÇÃO: print_string_mmio
# =========================================================
print_string_mmio:                   # Rotina para imprimir strings no terminal via Display MMIO
    li $t0, 0xFFFF0008               # Carrega o endereço do Transmitter Control (status do display)
    li $t1, 0xFFFF000C               # Carrega o endereço do Transmitter Data (onde enviamos o caractere)
    move $t2,$a0                    # Copia o endereço da string recebida em $a0 para o$t2

print_loop:                          # Laço para iterar caractere por caractere da nossa string
    lb $t3, 0($t2)                   # Carrega 1 byte (caractere atual) da string na memória
    beqz $t3, print_fim              # Se o caractere for \0 (nulo), chegamos ao fim da string, então sai

aguarda_display:                     # Laço de espera ocupada (polling) do display
    lw $t4, 0($t0)                   # Lê o status atual do controle do display
    andi $t4,$t4, 1                 # Faz um bitwise AND para isolar o bit 0 (bit de Ready / Pronto)
    beqz $t4, aguarda_display        # Se o bit for 0, o hardware está ocupado, continua esperando

    sw $t3, 0($t1)                   # Envia o nosso caractere para o display mostrar na tela
    addi $t2,$t2, 1                 # Avança nosso ponteiro da string em 1 byte (próxima letra)
    j print_loop                     # Volta pro início do loop para processar o restante da string

print_fim:                           # Ponto de saída da rotina de impressão
    jr $ra                           # Retorna o fluxo de execução para quem chamou a função

# =========================================================
# FUNÇÃO: read_string_mmio
# =========================================================
read_string_mmio:                    # Rotina para capturar a digitação do usuário via Keyboard MMIO
    li $t0, 0xFFFF0000               # Carrega o endereço do Receiver Control (status do teclado)
    li $t1, 0xFFFF0004               # Carrega o endereço do Receiver Data (a tecla pressionada)
    move $t2,$a0                    # Copia o endereço base do nosso buffer_comando para iterar

read_loop:                           # Laço de espera pela digitação do usuário
    lw $t3, 0($t0)                   # Lê o registrador de controle do teclado
    andi $t3,$t3, 1                 # Isola o bit de Ready para verificar se tem tecla nova
    beqz $t3, read_loop              # Se não tiver tecla (bit 0), continua girando no loop

    lw $t4, 0($t1)                   # Lê o valor ASCII da tecla que o usuário acabou de apertar
    
    li $t5, 0xFFFF0008               # Endereço do controle do display para fazer o echo da tecla
    li $t6, 0xFFFF000C               # Endereço de dados do display para o echo
echo_wait:                           # Pequeno loop para garantir que o display pode receber o echo
    lw $t7, 0($t5)                   # Lê o status do display
    andi $t7,$t7, 1                 # Isola o bit Ready
    beqz $t7, echo_wait              # Aguarda o hardware liberar
    sw $t4, 0($t6)                   # Imprime a tecla na tela para dar feedback visual ao usuário

    sb $t4, 0($t2)                   # Salva o byte capturado na posição atual do nosso buffer
    
    li $t8, 10                       # Carrega o valor 10 (código ASCII para a quebra de linha '\n')
    beq $t4,$t8, read_fim           # Se a tecla apertada for o Enter, finalizamos a leitura
    
    addi $t2,$t2, 1                 # Avança o ponteiro do buffer para a próxima posição livre
    j read_loop                      # Volta para aguardar a digitação da próxima letra

read_fim:                            # Finaliza o preenchimento do nosso buffer
    li $t8, 0                        # Carrega o valor 0 (terminador de string nulo '\0')
    addi $t2,$t2, 1                 # Avança para a última posição após o '\n'
    sb $t8, 0($t2)                   # Salva o terminador nulo fechando a string corretamente
    jr $ra                           # Retorna o fluxo para o loop principal do shell