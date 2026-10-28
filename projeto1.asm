# =========================================================
# Nome do Grupo: Letícia Medeiros Cavalcante e Sarah Pereira de Lima
# Atividade: Projeto 01 (PE1) da 1a VA
# Disciplina: Arquitetura e Organização de Computadores
# Semestre Letivo: 2026.2
# Breve descrição: Implementação do comando infoAp, que exibe todos
#                  os moradores e veículos de um AP específico ou de
#                  todos os APs em sequência quando passada a opção
#                  "--all". Inclui função auxiliar imprime_ap.
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

    # Nomes dos comandos: o parser compara o que o usuário digitou com cada um deles
    cmd_infoGeral:       .asciiz "infoGeral"  # Comando que mostra o panorama de APs vazios e não vazios
    cmd_formatar:        .asciiz "formatar"   # Comando que apaga todos os dados da execução atual
    cmd_limparAp:        .asciiz "limparAp"   # Comando que exclui moradores e automóveis de um AP
    cmd_addMorador:      .asciiz "addMorador" # Comando que cadastra um morador em um AP
    cmd_infoAp:          .asciiz "infoAp"     # Comando que exibe as informações de um AP ou de todos

    msg_info_nao_vazios: .asciiz "Nao vazios:\t" # Rótulo da linha de APs ocupados (sem acento por causa do MMIO)
    msg_info_vazios:     .asciiz "Vazios:\t\t"   # Rótulo da linha de APs desocupados
    msg_porcentagem_ini: .asciiz " ("            # Abre o parêntese da porcentagem
    msg_porcentagem_fim: .asciiz "%)\n"          # Fecha a porcentagem e quebra a linha

    msg_ap_label:        .asciiz "AP: "          # Rótulo da linha com o número do AP
    msg_ap_vazio:        .asciiz "Apartamento vazio\n" # Texto para AP sem moradores
    msg_moradores_label: .asciiz "Moradores:\n"  # Cabeçalho da lista de moradores
    msg_carro_label:     .asciiz "Carro:\n"      # Cabeçalho da seção de carro
    msg_moto_label:      .asciiz "Moto:\n"       # Cabeçalho da seção de motos
    msg_sep_veiculo:     .asciiz " / "           # Separador entre modelo e placa de cada veículo
    msg_newline:         .asciiz "\n"            # Quebra de linha para separar os APs no infoAp --all
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
    j read_loop                      # Espera a próxima tecla (ela sobrescreve o caractere apagado)
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
# FUNÇÃO: strcpy
# =========================================================
strcpy:                              # Copia uma string com limite | $a0 = destino, $a1 = origem, $a2 = máx. de caracteres
strcpy_loop:                         # Laço que copia caractere a caractere
    beqz $a2, strcpy_fim             # Se já copiamos o máximo permitido, paramos (o resto é cortado)
    lb $t0, 0($a1)                   # Carrega 1 byte da string de origem
    beqz $t0, strcpy_fim             # Se chegamos no \0 da origem, terminamos de copiar
    sb $t0, 0($a0)                   # Grava o caractere no destino
    addi $a0, $a0, 1                 # Avança no destino
    addi $a1, $a1, 1                 # Avança na origem
    addi $a2, $a2, -1                # Um caractere a menos que ainda cabe
    j strcpy_loop                    # Reinicia o laço de cópia
strcpy_fim:                          # Fim da cópia
    sb $zero, 0($a0)                 # Coloca o \0 para fechar a string copiada
    jr $ra                           # Retorna para a rotina chamadora

# =========================================================
# FUNÇÃO: parser_comandos
# =========================================================
parser_comandos:                     # Rotina de interpretação (decifra o que o usuário quer)
    addi $sp, $sp, -12               # Abre um espaço de 12 bytes na pilha (stack)
    sw $ra, 0($sp)                   # Salva nosso $ra na pilha para não perdermos a volta após os jal
    sw $s0, 4($sp)                   # Salva o $s0 também, porque vamos usá-lo aqui
    sw $s1, 8($sp)                   # Salva o $s1, onde vamos guardar a quantidade de opções
    move $s0, $a0                    # Guardamos o endereço do buffer no $s0, já que o strcmp mexe no $a0

    lb $t0, 0($s0)                   # Lê o primeiro caractere digitado no buffer
    beqz $t0, parser_fim             # Se for apenas Enter (agora virou \0), ignoramos e voltamos para o prompt

    move $a0, $s0                    # Passa o comando digitado para separarmos as opções
    jal separa_opcoes                # Corta a string em cada " --" e guarda onde começa cada opção
    move $s1, $v0                    # Guardamos no $s1 quantas opções o usuário digitou

    move $a0, $s0                    # Passa o comando digitado como 1º argumento
    la $a1, cmd_infoGeral            # Passa a string "infoGeral" como 2º argumento
    jal strcmp                       # Chama nossa rotina de comparação
    beqz $v0, executa_infoGeral      # Se deu 0 (iguais), pulamos para o infoGeral

    move $a0, $s0                    # Passa o comando digitado como 1º argumento
    la $a1, cmd_formatar             # Passa a string "formatar" como 2º argumento
    jal strcmp                       # Chama nossa rotina de comparação
    beqz $v0, executa_formatar       # Se deu 0 (iguais), pulamos para o formatar

    move $a0, $s0                    # Passa o comando digitado como 1º argumento
    la $a1, cmd_limparAp             # Passa a string "limparAp" como 2º argumento
    jal strcmp                       # Chama nossa rotina de comparação
    beqz $v0, executa_limparAp       # Se deu 0 (iguais), pulamos para o limparAp

    move $a0, $s0                    # Passa o comando digitado como 1º argumento
    la $a1, cmd_addMorador           # Passa a string "addMorador" como 2º argumento
    jal strcmp                       # Chama nossa rotina de comparação
    beqz $v0, executa_addMorador     # Se deu 0 (iguais), pulamos para o addMorador

    move $a0, $s0                    # Passa o comando digitado como 1º argumento
    la $a1, cmd_infoAp               # Passa a string "infoAp" como 2º argumento
    jal strcmp                       # Chama nossa rotina de comparação
    beqz $v0, executa_infoAp         # Se deu 0 (iguais), pulamos para o infoAp

comando_invalido:                    # Chegamos aqui se o comando não existe ou veio com opções erradas
    la $a0, msg_invalido             # Caso o comando seja desconhecido, puxa a mensagem de erro
    jal print_string_mmio            # Chama a função de print para exibir "Comando invalido"
    j parser_fim                     # Vai para o encerramento do interpretador

executa_infoGeral:                   # Desvio do comando infoGeral
    bnez $s1, comando_invalido       # O infoGeral não tem opções; se o usuário mandou alguma, é inválido
    jal comando_infoGeral            # Chama a rotina que mostra o panorama do condomínio
    j parser_fim                     # Vai para o encerramento do interpretador

executa_formatar:                    # Desvio do comando formatar
    bnez $s1, comando_invalido       # O formatar também não tem opções
    jal comando_formatar             # Chama a rotina que apaga os dados da memória
    j parser_fim                     # Vai para o encerramento do interpretador

executa_limparAp:                    # Desvio do comando limparAp
    li $t0, 1                        # O limparAp precisa de exatamente 1 opção (o número do AP)
    bne $s1, $t0, comando_invalido   # Se veio outra quantidade de opções, é inválido
    la $t0, opcoes                   # Carrega o endereço do nosso vetor de opções
    lw $a0, 0($t0)                   # Pega o endereço da 1ª opção (o número do AP digitado)
    jal comando_limparAp             # Chama a rotina que esvazia o AP
    j parser_fim                     # Vai para o encerramento do interpretador

executa_addMorador:                  # Desvio do comando addMorador
    li $t0, 2                        # O addMorador precisa de exatamente 2 opções (AP e nome)
    bne $s1, $t0, comando_invalido   # Se veio outra quantidade de opções, é inválido
    la $t0, opcoes                   # Carrega o endereço do nosso vetor de opções
    lw $a0, 0($t0)                   # 1ª opção: o número do AP
    lw $a1, 4($t0)                   # 2ª opção: o nome do morador
    lb $t1, 0($a1)                   # Olha o primeiro caractere do nome
    beqz $t1, comando_invalido       # Nome vazio ("--" sem nada depois) não vale
    jal comando_addMorador           # Chama a rotina que cadastra o morador
    j parser_fim                     # Vai para o encerramento do interpretador

executa_infoAp:                      # Desvio do comando infoAp
    li $t0, 1                        # O infoAp exige exatamente 1 opção
    bne $s1, $t0, comando_invalido   # Quantidade diferente de 1 opção é inválido
    la $t0, opcoes                   # Carrega o endereço do vetor de opções
    lw $a0, 0($t0)                   # 1ª opção: número do AP ou "all"
    jal comando_infoAp               # Chama a rotina que exibe as informações
    j parser_fim                     # Vai para o encerramento do interpretador

parser_fim:                          # Encerramento do interpretador
    lw $ra, 0($sp)                   # Recupera nosso $ra original da pilha
    lw $s0, 4($sp)                   # Recupera o $s0 original da pilha
    lw $s1, 8($sp)                   # Recupera o $s1 original da pilha
    addi $sp, $sp, 12                # Desaloca o espaço da pilha (restaura o $sp)
    jr $ra                           # Retorna para o loop do shell

# =========================================================
# FUNÇÃO: separa_opcoes
# =========================================================
separa_opcoes:                       # Rotina que divide o comando em cada " --" | $a0 = buffer, $v0 = qtd de opções
    li $v0, 0                        # Começamos com zero opções encontradas
    la $t5, opcoes                   # Carrega o endereço do nosso vetor de opções
sep_loop:                            # Laço que anda pela string procurando " --"
    lb $t0, 0($a0)                   # Carrega 1 byte (caractere atual)
    beqz $t0, sep_fim                # Se chegamos no \0, terminamos de procurar
    li $t1, 32                       # Código ASCII do espaço (0x20)
    bne $t0, $t1, sep_proximo        # Se não for espaço, não é começo de opção
    lb $t2, 1($a0)                   # Olha o caractere seguinte
    li $t1, 45                       # Código ASCII do '-' (0x2d)
    bne $t2, $t1, sep_proximo        # Se não for '-', era só um espaço normal (ex: "Claude Shannon")
    lb $t2, 2($a0)                   # Olha mais um caractere à frente
    bne $t2, $t1, sep_proximo        # Precisa ter dois '-' seguidos para ser opção

    sb $zero, 0($a0)                 # Trocamos o espaço por \0, encerrando a parte anterior da string
    li $t3, 4                        # Nosso vetor guarda no máximo 4 opções
    bge $v0, $t3, sep_conta          # Se já guardamos 4, só contamos (o comando vai acusar o excesso)
    sll $t4, $v0, 2                  # Multiplica a posição por 4 (cada endereço ocupa 1 palavra)
    add $t4, $t5, $t4                # Calcula onde guardar dentro do vetor
    addi $t6, $a0, 3                 # A opção começa logo depois do " --" (3 caracteres)
    sw $t6, 0($t4)                   # Guarda o endereço do início da opção
sep_conta:                           # Conta a opção encontrada
    addi $v0, $v0, 1                 # Mais uma opção
    addi $a0, $a0, 3                 # Pula o " --" para continuar procurando
    j sep_loop                       # Reinicia o laço
sep_proximo:                         # Caractere comum
    addi $a0, $a0, 1                 # Avança para o próximo caractere
    j sep_loop                       # Reinicia o laço
sep_fim:                             # Fim da separação
    jr $ra                           # Retorna com a quantidade de opções no $v0

# =========================================================
# FUNÇÃO: converte_ap
# =========================================================
converte_ap:                         # Transforma o texto do AP em índice | $a0 = string, $v0 = índice (0 a 23) ou -1
    li $t0, 0                        # $t0 vai acumular o número digitado
    li $t1, 0                        # $t1 conta quantos dígitos já lemos
conv_loop:                           # Laço que lê os dígitos um por um
    lb $t2, 0($a0)                   # Carrega 1 byte (caractere atual)
    beqz $t2, conv_valida            # Se chegamos no \0, vamos conferir o número
    li $t3, 48                       # Código ASCII do '0'
    blt $t2, $t3, conv_invalido      # Abaixo de '0' não é dígito
    li $t3, 57                       # Código ASCII do '9'
    bgt $t2, $t3, conv_invalido      # Acima de '9' não é dígito
    addi $t2, $t2, -48               # Converte o caractere para o valor numérico
    li $t3, 10                       # Base 10
    mul $t0, $t0, $t3                # Desloca o número acumulado uma casa decimal
    add $t0, $t0, $t2                # Soma o novo dígito
    addi $t1, $t1, 1                 # Mais um dígito lido
    li $t3, 4                        # Um AP tem no máximo 4 dígitos (ex: 1202)
    bgt $t1, $t3, conv_invalido      # Se passou disso, é inválido
    addi $a0, $a0, 1                 # Avança para o próximo caractere
    j conv_loop                      # Reinicia o laço
conv_valida:                         # Confere se o número é um AP que existe
    li $t3, 3                        # Um AP tem no mínimo 3 dígitos (ex: 101)
    blt $t1, $t3, conv_invalido      # Menos que isso (ou vazio) é inválido
    li $t3, 100                      # Dividimos por 100 para separar andar e final
    div $t0, $t3                     # Ex: 1102 / 100
    mflo $t4                         # Quociente = andar (11)
    mfhi $t5                         # Resto = final do AP (2)
    li $t3, 1                        # Menor andar e menor final válidos
    blt $t4, $t3, conv_invalido      # Andar abaixo de 1 é inválido
    blt $t5, $t3, conv_invalido      # Final abaixo de 01 é inválido
    li $t3, 12                       # Maior andar do condomínio
    bgt $t4, $t3, conv_invalido      # Andar acima de 12 é inválido
    li $t3, 2                        # Maior final (2 APs por andar)
    bgt $t5, $t3, conv_invalido      # Final acima de 02 é inválido
    addi $t4, $t4, -1                # andar - 1
    sll $t4, $t4, 1                  # (andar - 1) * 2
    addi $t5, $t5, -1                # final - 1
    add $v0, $t4, $t5                # Índice = (andar - 1) * 2 + (final - 1)
    jr $ra                           # Retorna com o índice no $v0
conv_invalido:                       # Caso o AP não exista
    li $v0, -1                       # Devolvemos -1 para avisar que é inválido
    jr $ra                           # Retorna para a rotina chamadora

# =========================================================
# FUNÇÃO: endereco_ap
# =========================================================
endereco_ap:                         # Calcula onde o AP começa na memória | $a0 = índice, $v0 = endereço
    li $t0, 328                      # Tamanho de cada AP em bytes
    mul $t0, $a0, $t0                # índice * 328
    la $v0, condominio               # Início do nosso banco de dados
    add $v0, $v0, $t0                # Soma o deslocamento para chegar no AP
    jr $ra                           # Retorna com o endereço no $v0

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

# =========================================================
# FUNÇÃO: comando_limparAp
# =========================================================
comando_limparAp:                    # Exclui moradores e automóveis de um AP | $a0 = string com o número do AP
    addi $sp, $sp, -4                # Abre espaço na pilha
    sw $ra, 0($sp)                   # Salva nosso $ra, pois vamos chamar outras funções

    jal converte_ap                  # Transforma o texto do AP no índice
    bltz $v0, limpar_invalido        # Se veio -1, o AP não existe

    move $a0, $v0                    # Passa o índice do AP
    jal endereco_ap                  # Descobre onde o AP começa na memória
    li $t1, 82                       # Quantidade de palavras de um AP (328 bytes / 4)
limpar_loop:                         # Laço para zerar o AP
    sw $zero, 0($v0)                 # Zera 4 bytes de uma vez
    addi $v0, $v0, 4                 # Avança para a próxima palavra
    addi $t1, $t1, -1                # Diminui o contador de palavras que faltam
    bnez $t1, limpar_loop            # Continua no loop até zerar o AP inteiro
    j limpar_fim                     # AP vazio: vai para o encerramento

limpar_invalido:                     # Caso o AP digitado não exista
    la $a0, msg_ap_invalido          # Puxa a mensagem "Falha: AP invalido"
    jal print_string_mmio            # Exibe a mensagem no terminal

limpar_fim:                          # Encerramento do comando
    lw $ra, 0($sp)                   # Recupera nosso $ra original da pilha
    addi $sp, $sp, 4                 # Desaloca o espaço da pilha
    jr $ra                           # Retorna para o parser

# =========================================================
# FUNÇÃO: comando_addMorador
# =========================================================
comando_addMorador:                  # Cadastra um morador | $a0 = string do AP, $a1 = nome do morador
    addi $sp, $sp, -12               # Abre um espaço de 12 bytes na pilha
    sw $ra, 0($sp)                   # Salva nosso $ra, pois vamos chamar outras funções
    sw $s0, 4($sp)                   # Salva o $s0, onde vamos guardar o endereço do AP
    sw $s1, 8($sp)                   # Salva o $s1, onde vamos guardar o endereço do nome
    move $s1, $a1                    # Guardamos o nome, já que as próximas chamadas mexem nos $a

    jal converte_ap                  # Transforma o texto do AP no índice
    bltz $v0, add_mor_invalido       # Se veio -1, o AP não existe

    move $a0, $v0                    # Passa o índice do AP
    jal endereco_ap                  # Descobre onde o AP começa na memória
    move $s0, $v0                    # $s0 = início do AP

    lw $t0, 0($s0)                   # Lê a quantidade de moradores (primeira palavra do AP)
    li $t1, 6                        # Limite do regimento: 6 moradores por AP
    bge $t0, $t1, add_mor_cheio      # Se já tem 6, não deixamos cadastrar o 7º

    li $t1, 40                       # Cada nome ocupa 40 bytes
    mul $t1, $t0, $t1                # Pula os nomes que já existem (quantidade x 40)
    addi $t1, $t1, 4                 # Os nomes começam depois da palavra da quantidade
    add $a0, $s0, $t1                # Destino: próxima vaga livre de nome
    move $a1, $s1                    # Origem: nome digitado pelo usuário
    li $a2, 39                       # No máximo 39 caracteres (o 40º byte é do \0)
    jal strcpy                       # Copia o nome para a vaga

    lw $t0, 0($s0)                   # Lê de novo a quantidade de moradores
    addi $t0, $t0, 1                 # Mais um morador (se era 0, o AP deixa de ser vazio)
    sw $t0, 0($s0)                   # Grava a nova quantidade
    j add_mor_fim                    # Cadastro feito: vai para o encerramento

add_mor_invalido:                    # Caso o AP digitado não exista
    la $a0, msg_ap_invalido          # Puxa a mensagem "Falha: AP invalido"
    jal print_string_mmio            # Exibe a mensagem no terminal
    j add_mor_fim                    # Vai para o encerramento

add_mor_cheio:                       # Caso o AP já tenha 6 moradores
    la $a0, msg_max_moradores        # Puxa a mensagem "Falha: AP com numero max de moradores"
    jal print_string_mmio            # Exibe a mensagem no terminal

add_mor_fim:                         # Encerramento do comando
    lw $ra, 0($sp)                   # Recupera nosso $ra original da pilha
    lw $s0, 4($sp)                   # Recupera o $s0 original da pilha
    lw $s1, 8($sp)                   # Recupera o $s1 original da pilha
    addi $sp, $sp, 12                # Desaloca o espaço da pilha
    jr $ra                           # Retorna para o parser

# =========================================================
# FUNÇÃO: comando_infoAp
# =========================================================
# Exibe informações de um AP ou de todos | $a0 = string da opção ("all" ou número do AP)
comando_infoAp:
    addi $sp, $sp, -12               # Abre 12 bytes na pilha
    sw $ra, 0($sp)                   # Salva o $ra, pois chamamos outras funções
    sw $s0, 4($sp)                   # Salva o $s0 (índice atual no laço do --all)
    sw $s1, 8($sp)                   # Salva o $s1 (endereço da opção recebida)
    move $s1, $a0                    # Guarda a string da opção, já que converte_ap mexe em $a0

    la $a1, str_all                  # Prepara "all" para comparação
    move $a0, $s1                    # Passa a opção digitada
    jal strcmp                       # Compara com "all"
    bnez $v0, info_ap_unico          # Se não for "all", vai exibir só um AP

info_ap_all:                         # Modo --all: percorre os 24 APs em ordem crescente
    li $s0, 0                        # Começa pelo índice 0 (AP 101)
info_all_loop:                       # Laço que imprime cada AP
    li $t0, 24                       # Total de APs
    beq $s0, $t0, info_fim           # Se o índice chegou a 24, terminamos
    move $a0, $s0                    # Passa o índice do AP atual
    jal imprime_ap                   # Chama a função que imprime um AP pelo índice
    addi $s0, $s0, 1                 # Avança para o próximo AP
    j info_all_loop                  # Continua o laço

info_ap_unico:                       # Modo com número de AP específico
    move $a0, $s1                    # Passa a string do AP para converter
    jal converte_ap                  # Converte o texto no índice
    bltz $v0, info_ap_invalido       # Índice -1 significa AP inválido
    move $a0, $v0                    # Passa o índice para a função de impressão
    jal imprime_ap                   # Imprime as informações do AP
    j info_fim                       # Vai para o encerramento

info_ap_invalido:                    # AP digitado fora do intervalo do condomínio
    la $a0, msg_ap_invalido          # Puxa "Falha: AP invalido"
    jal print_string_mmio            # Exibe no terminal

info_fim:                            # Encerramento do infoAp
    lw $ra, 0($sp)                   # Recupera o $ra
    lw $s0, 4($sp)                   # Recupera o $s0
    lw $s1, 8($sp)                   # Recupera o $s1
    addi $sp, $sp, 12                # Desaloca a pilha
    jr $ra                           # Retorna para o parser

# =========================================================
# FUNÇÃO: imprime_ap
# =========================================================
# Imprime todas as informações de um AP dado seu índice | $a0 = índice (0 a 23)
imprime_ap:
    addi $sp, $sp, -16               # Abre 16 bytes na pilha
    sw $ra, 0($sp)                   # Salva o $ra
    sw $s0, 4($sp)                   # Salva o $s0 (endereço base do AP)
    sw $s1, 8($sp)                   # Salva o $s1 (índice recebido — para calcular o número do AP)
    sw $s2, 12($sp)                  # Salva o $s2 (contador de laços)
    move $s1, $a0                    # Guarda o índice antes de chamar endereco_ap

    jal endereco_ap                  # Calcula o endereço base do AP
    move $s0, $v0                    # $s0 = endereço do AP na memória

    # --- Imprime "AP: <numero>\n" ---
    la $a0, msg_ap_label             # "AP: "
    jal print_string_mmio            # Imprime o rótulo

    # Converte índice em número do AP: (índice/2 + 1)*100 + (índice mod 2) + 1
    srl $t0, $s1, 1                  # índice / 2 (andar - 1)
    addi $t0, $t0, 1                 # + 1 = andar
    li $t1, 100                      # Fator do andar
    mul $t0, $t0, $t1                # andar * 100
    andi $t1, $s1, 1                 # índice mod 2 (0 ou 1)
    addi $t1, $t1, 1                 # + 1 = número do AP no andar
    add $a0, $t0, $t1                # número completo do AP
    jal print_int_mmio               # Imprime o número

    la $a0, msg_newline              # "\n"
    jal print_string_mmio            # Quebra a linha após o número do AP

    # --- Verifica se o AP está vazio ---
    lw $t0, 0($s0)                   # Lê a quantidade de moradores
    beqz $t0, imprime_ap_vazio       # Se for 0, imprime "Apartamento vazio" e encerra

    # --- Imprime "Moradores:\n" e cada nome ---
    la $a0, msg_moradores_label      # "Moradores:\n"
    jal print_string_mmio            # Cabeçalho da lista

    li $s2, 0                        # Contador de moradores já impressos
imprime_moradores_loop:              # Laço pelos nomes cadastrados
    lw $t0, 0($s0)                   # Relê a quantidade (pode ter mudado entre chamadas, por segurança)
    beq $s2, $t0, imprime_moradores_fim # Imprimiu todos os moradores
    li $t1, 40                       # Cada nome tem 40 bytes
    mul $t1, $s2, $t1                # Deslocamento do nome atual
    addi $t1, $t1, 4                 # Os nomes começam no offset 4
    add $a0, $s0, $t1                # Endereço do nome atual
    jal print_string_mmio            # Imprime o nome
    la $a0, msg_newline              # "\n"
    jal print_string_mmio            # Quebra de linha após o nome
    addi $s2, $s2, 1                 # Próximo morador
    j imprime_moradores_loop         # Continua o laço

imprime_moradores_fim:               # Acabou a lista de moradores
    # --- Verifica e imprime veículos ---
    lb $t0, 244($s0)                 # Tipo do veículo (offset 244): 0, 'c' ou 'm'
    beqz $t0, imprime_ap_fim         # Sem veículo nenhum: encerra

    li $t1, 99                       # ASCII de 'c'
    beq $t0, $t1, imprime_carro      # Tipo é 'c': vai para a seção de carro

imprime_motos:                       # Tipo é 'm': imprime o rótulo e as motos
    la $a0, msg_moto_label           # "Moto:\n"
    jal print_string_mmio            # Cabeçalho da seção de motos

    li $s2, 0                        # Contador de motos já impressas
    lb $t2, 245($s0)                 # Quantidade de motos cadastradas (offset 245)
imprime_motos_loop:                  # Laço pelas motos
    beq $s2, $t2, imprime_ap_fim     # Imprimiu todas as motos
    li $t1, 40                       # Cada veículo ocupa 40 bytes (30 modelo + 10 placa)
    mul $t1, $s2, $t1                # Deslocamento do veículo atual
    addi $t1, $t1, 248               # Os veículos começam no offset 248
    add $a0, $s0, $t1                # Endereço do modelo da moto atual
    jal print_string_mmio            # Imprime o modelo
    la $a0, msg_sep_veiculo          # " / "
    jal print_string_mmio            # Separador entre modelo e placa
    li $t1, 40                       # Recalcula o deslocamento para a placa
    mul $t1, $s2, $t1
    addi $t1, $t1, 278               # offset 248 + 30 bytes de modelo = offset 278
    add $a0, $s0, $t1                # Endereço da placa da moto atual
    jal print_string_mmio            # Imprime a placa
    la $a0, msg_newline              # "\n"
    jal print_string_mmio            # Quebra de linha após cada moto
    addi $s2, $s2, 1                 # Próxima moto
    j imprime_motos_loop             # Continua o laço

imprime_carro:                       # Seção de exibição do carro
    la $a0, msg_carro_label          # "Carro:\n"
    jal print_string_mmio            # Cabeçalho da seção de carro
    addi $a0, $s0, 248               # Modelo do carro começa no offset 248
    jal print_string_mmio            # Imprime o modelo
    la $a0, msg_sep_veiculo          # " / "
    jal print_string_mmio            # Separador
    addi $a0, $s0, 278               # Placa do carro: offset 248 + 30 bytes de modelo
    jal print_string_mmio            # Imprime a placa
    la $a0, msg_newline              # "\n"
    jal print_string_mmio            # Quebra de linha
    j imprime_ap_fim                 # Encerra a impressão do AP

imprime_ap_vazio:                    # AP sem moradores
    la $a0, msg_ap_vazio             # "Apartamento vazio\n"
    jal print_string_mmio            # Exibe a mensagem

imprime_ap_fim:                      # Encerramento da função imprime_ap
    lw $ra, 0($sp)                   # Recupera o $ra
    lw $s0, 4($sp)                   # Recupera o $s0
    lw $s1, 8($sp)                   # Recupera o $s1
    lw $s2, 12($sp)                  # Recupera o $s2
    addi $sp, $sp, 16                # Desaloca a pilha
    jr $ra                           # Retorna para quem chamou