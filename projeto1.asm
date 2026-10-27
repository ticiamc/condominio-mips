# =========================================================
# Nome do Grupo: Letícia Medeiros Cavalcante e Sarah Pereira de Lima
# Atividade: Projeto 01 (PE1) da 1a VA
# Disciplina: Arquitetura e Organização de Computadores
# Semestre Letivo: 2026.2
# Breve descrição: Adição da comparação de strings (strcmp) no
#                  parser, que passa a reconhecer os comandos
#                  infoGeral e formatar.
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
 
    cmd_infoGeral:       .asciiz "infoGeral" # Nome do comando que vamos comparar com o que o usuário digitou
    cmd_formatar:        .asciiz "formatar"  # Nome do comando que vamos comparar com o que o usuário digitou
 
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
 
    li $t8, 255                      # Limite do nosso buffer (o último byte fica para o \0)
    beq $t9, $t8, read_loop          # Se o buffer encheu, não avançamos mais para não estourar a memória
 
    addi $t2, $t2, 1                 # Avança o ponteiro do buffer
    addi $t9, $t9, 1                 # Conta mais um caractere guardado
    j read_loop                      # Espera a próxima tecla
read_fim:                            # Finalização do buffer
    li $t8, 0                        # Carrega o valor do \0
    sb $t8, 0($t2)                   # Trocamos o \n pelo \0 para facilitar a comparação de strings no parser
    jr $ra                           # Retorna
 
# =========================================================
# FUNÇÃO: strcmp
# =========================================================
strcmp:                              # Rotina que compara duas strings ($a0 e $a1) e devolve o resultado no $v0
strcmp_loop:                         # Laço que anda pelas duas strings ao mesmo tempo
    lb $t0, 0($a0)                   # Carrega 1 byte da primeira string
    lb $t1, 0($a1)                   # Carrega 1 byte da segunda string
    bne $t0, $t1, strcmp_diferente   # Se os caracteres forem diferentes, já sabemos que não são iguais
    beqz $t0, strcmp_igual           # Se chegamos no \0 das duas juntas, as strings são iguais
    addi $a0, $a0, 1                 # Avança para o próximo caractere da primeira string
    addi $a1, $a1, 1                 # Avança para o próximo caractere da segunda string
    j strcmp_loop                    # Reinicia o laço de comparação
strcmp_diferente:                    # Caso as strings sejam diferentes
    li $v0, 1                        # Devolvemos 1 no $v0
    jr $ra                           # Retorna para a rotina chamadora
strcmp_igual:                        # Caso as strings sejam iguais
    li $v0, 0                        # Devolvemos 0 no $v0
    jr $ra                           # Retorna para a rotina chamadora
 
# =========================================================
# FUNÇÃO: parser_comandos
# =========================================================
parser_comandos:                     # Rotina de interpretação (decifra o que o usuário quer)
    addi $sp, $sp, -8                # Abre um espaço de 8 bytes na pilha (stack)
    sw $ra, 0($sp)                   # Salva nosso $ra na pilha para não perdermos a volta após os jal
    sw $s0, 4($sp)                   # Salva o $s0 também, porque vamos usá-lo aqui
    move $s0, $a0                    # Guardamos o endereço do buffer no $s0, já que o strcmp mexe no $a0
 
    lb $t0, 0($s0)                   # Lê o primeiro caractere digitado no buffer
    beqz $t0, parser_fim             # Se for apenas Enter (agora virou \0), ignoramos e voltamos para o prompt
 
    move $a0, $s0                    # Passa o comando digitado como 1º argumento
    la $a1, cmd_infoGeral            # Passa a string "infoGeral" como 2º argumento
    jal strcmp                       # Chama nossa rotina de comparação
    beqz $v0, executa_infoGeral      # Se deu 0 (iguais), pulamos para o infoGeral
 
    move $a0, $s0                    # Passa o comando digitado como 1º argumento
    la $a1, cmd_formatar             # Passa a string "formatar" como 2º argumento
    jal strcmp                       # Chama nossa rotina de comparação
    beqz $v0, executa_formatar       # Se deu 0 (iguais), pulamos para o formatar
 
    la $a0, msg_invalido             # Caso o comando seja desconhecido, puxa a mensagem de erro
    jal print_string_mmio            # Chama a função de print para exibir "Comando invalido"
    j parser_fim                     # Vai para o encerramento do interpretador
 
executa_infoGeral:                   # Desvio do comando infoGeral
    jal comando_infoGeral            # Chama a rotina que mostra o panorama do condomínio
    j parser_fim                     # Vai para o encerramento do interpretador
 
executa_formatar:                    # Desvio do comando formatar
    jal comando_formatar             # Chama a rotina que apaga os dados da memória
    j parser_fim                     # Vai para o encerramento do interpretador
 
parser_fim:                          # Encerramento do interpretador
    lw $ra, 0($sp)                   # Recupera nosso $ra original da pilha
    lw $s0, 4($sp)                   # Recupera o $s0 original da pilha
    addi $sp, $sp, 8                 # Desaloca o espaço da pilha (restaura o $sp)
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
    lw $t4, 0($t3)                   # Lê a primeira palavra (4 bytes) do AP (0 = AP vazio)
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
 
# =========================================================
# FUNÇÃO: comando_formatar
# =========================================================
comando_formatar:                    # Rotina que apaga tudo da execução atual (não mexe no arquivo salvo)
    la $t0, condominio               # Carrega o endereço do início do nosso banco de dados
    li $t1, 1968                     # Quantidade de palavras (4 bytes) para zerar (7872 bytes / 4)
formatar_loop:                       # Laço para zerar a memória
    sw $zero, 0($t0)                 # Zera 4 bytes de uma vez
    addi $t0, $t0, 4                 # Avança para a próxima palavra
    addi $t1, $t1, -1                # Diminui o contador de palavras que faltam
    bnez $t1, formatar_loop          # Continua no loop até zerar tudo
    jr $ra                           # Retorna com todos os APs vazios
 