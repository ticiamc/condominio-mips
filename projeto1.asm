# =========================================================
# Grupo: Letícia Medeiros Cavalcante e Sarah Pereira de Lima
# Atividade: Projeto 01 - 1VA
# Disciplina: Arquitetura e Organização de Computadores
# Semestre: 2026.2
# Descrição: Sistema de cadastro de pessoas e automóveis para
#            um condomínio operado via terminal.
# =========================================================

.data
    # -----------------------------------------------------
    # STRINGS CONSTANTES
    # -----------------------------------------------------
    # Banner com as iniciais exigido pelo projeto
    banner:          .asciiz "LMC-shell>> "
    msg_invalido:    .asciiz "Comando invalido\n"
    
    # -----------------------------------------------------
    # BUFFERS E BANCO DE DADOS
    # -----------------------------------------------------
    # Reserva 256 bytes para ler os comandos do usuário
    buffer_comando:  .space 256 

    # O condomínio tem 12 andares com 2 apartamentos cada (24 APs).
    # Cada AP gasta 328 bytes. 24 x 328 = 7872 bytes.
    condominio:      .space 7872  

.text
.globl main

main:
    # -----------------------------------------------------
    # LOOP PRINCIPAL DO SHELL
    # -----------------------------------------------------
loop_shell:
    # 1. Imprime o banner
    la $a0, banner
    jal print_string_mmio
    
    # TODO: Ler teclado 
    # TODO: Interpretar comando 
    
    # Reinicia o loop
    j loop_shell

# =========================================================
# FUNÇÃO: print_string_mmio
# Entrada: $a0 = endereço da string
# =========================================================
print_string_mmio:
    li $t0, 0xFFFF0008     # Transmitter Control
    li $t1, 0xFFFF000C     # Transmitter Data
    move $t2, $a0          # Copia endereço da string

print_loop:
    lb $t3, 0($t2)         # Carrega um byte da string
    beqz $t3, print_fim    # Se for nulo (\0), fim

aguarda_display:
    lw $t4, 0($t0)         # Lê Transmitter Control
    andi $t4, $t4, 1       # Isola o bit Ready
    beqz $t4, aguarda_display

    sw $t3, 0($t1)         # Envia o caractere
    addi $t2, $t2, 1       # Próximo caractere
    j print_loop

print_fim:
    jr $ra                 # Retorna