# =========================================================
# Nome do Grupo: Letícia Medeiros Cavalcante e Sarah Pereira de Araújo Lima
# Atividade: Projeto 01 (PE1) da 1a VA
# Disciplina: Arquitetura e Organização de Computadores
# Professor: Vítor A Coutinho
# Semestre Letivo: 2026.2
# Breve descrição: Sistema de cadastro de moradores e automóveis de um
#                  condomínio de 12 andares com 2 APs por andar, operado
#                  por um terminal (LS-shell) via Keyboard e Display MMIO.
#                  Comandos: addMorador, rmvMorador, addAuto, rmvAuto,
#                  limparAp, infoAp, infoGeral, salvar, recarregar e
#                  formatar. Os dados ficam em condominio.dat (syscalls
#                  13 a 16) e são carregados automaticamente ao iniciar.
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

    # Mensagens de erro (sem acento, porque o display MMIO não mostra UTF-8)
    msg_invalido:        .asciiz "Comando invalido\n" # Mensagem padrão para comandos não reconhecidos
    msg_ap_invalido:     .asciiz "Falha: AP invalido\n" # Mensagem para quando o AP digitado não existe no condomínio
    msg_max_moradores:   .asciiz "Falha: AP com numero max de moradores\n" # Mensagem para quando o AP já tem 6 moradores
    msg_nao_encontrado:  .asciiz "Falha: morador nao encontrado\n" # Mensagem do rmvMorador quando o nome não está no AP
    msg_max_autos:       .asciiz "Falha: AP com numero max de automoveis\n" # Mensagem para quando o AP já tem 1 carro ou 2 motos
    msg_tipo_invalido:   .asciiz "Falha: tipo invalido\n" # Mensagem para quando o tipo do veículo não é 'c' nem 'm'
    msg_ap_vazio_auto:   .asciiz "Falha: AP vazio\n" # Mensagem para quando tentam cadastrar veículo em AP sem moradores
    msg_auto_nao_enc:    .asciiz "Falha: automovel nao encontrado\n" # Mensagem do rmvAuto quando a placa não está no AP
    msg_erro_salvar:     .asciiz "Falha: erro ao salvar arquivo\n" # Mensagem para quando não conseguimos abrir o arquivo para escrita

    # Nomes dos comandos: o parser compara o que o usuário digitou com cada um deles
    cmd_infoGeral:       .asciiz "infoGeral" # Comando que mostra o panorama de APs vazios e não vazios
    cmd_formatar:        .asciiz "formatar"  # Comando que apaga todos os dados da execução atual
    cmd_limparAp:        .asciiz "limparAp"  # Comando que exclui moradores e automóveis de um AP
    cmd_addMorador:      .asciiz "addMorador" # Comando que cadastra um morador em um AP
    cmd_infoAp:          .asciiz "infoAp"     # Comando que mostra moradores e veículos de um AP (ou de todos)
    cmd_rmvMorador:      .asciiz "rmvMorador" # Comando que remove um morador de um AP
    cmd_addAuto_min:     .asciiz "addAuto"    # Comando que cadastra um veículo, escrito como no exemplo do enunciado
    cmd_addAuto_mai:     .asciiz "AddAuto"    # O mesmo comando com "A" maiúsculo, como aparece no título do enunciado
    cmd_rmvAuto:         .asciiz "rmvAuto"    # Comando que remove um veículo pela placa
    cmd_salvar:          .asciiz "salvar"     # Comando que grava o condomínio no arquivo externo
    cmd_recarregar:      .asciiz "recarregar" # Comando que restaura o condomínio a partir do arquivo externo

    nome_arquivo:        .asciiz "condominio.dat" # Nosso arquivo de dados (fica na pasta de onde o MARS foi aberto)

    # Textos usados para montar as saídas do infoGeral e do infoAp
    msg_info_nao_vazios: .asciiz "Nao vazios:\t" # Rótulo da linha de APs ocupados (sem acento por causa do MMIO)
    msg_info_vazios:     .asciiz "Vazios:\t\t"   # Rótulo da linha de APs desocupados
    msg_porcentagem_ini: .asciiz " ("            # Abre o parêntese da porcentagem
    msg_porcentagem_fim: .asciiz "%)\n"          # Fecha a porcentagem e quebra a linha
    msg_ap_label:        .asciiz "AP: "          # Começo da primeira linha do infoAp, antes do número do AP
    msg_ap_vazio:        .asciiz "Apartamento vazio\n" # Mostrada pelo infoAp quando o AP não tem moradores
    msg_moradores_label: .asciiz "Moradores:\n"  # Rótulo da lista de moradores
    msg_carro_label:     .asciiz "Carro:\n"      # Rótulo para quando o AP tem carro
    msg_moto_label:      .asciiz "Moto:\n"       # Rótulo para quando o AP tem moto(s)
    msg_sep_veiculo:     .asciiz " / "           # Separa o modelo da placa ("Fiat Uno / ABC1234")
    msg_newline:         .asciiz "\n"            # Quebra de linha avulsa
    msg_tab:             .asciiz "\t"            # Tabulação que recua cada morador e veículo no infoAp
    str_all:             .asciiz "all"           # Opção especial do infoAp que lista os 24 APs

    buffer_comando:      .space 256  # Reserva 256 bytes contíguos para armazenar o input do usuário
    buffer_int:          .space 12   # Espaço para converter um inteiro em texto antes de imprimir
    .align 2                         # Alinha o próximo dado em endereço múltiplo de 4 (exigido pelo lw)
    opcoes:              .space 16   # Guardamos aqui o endereço de até 4 opções (4 palavras de 4 bytes)
    condominio:          .space 7872 # Memória do banco de dados: 24 APs gastando 328 bytes cada

.text                                # Seção onde começam as instruções de código
.globl main                          # Declara a função main como ponto de entrada global

main:                                # Ponto de partida do programa
    jal rotina_recarregar            # Antes de abrir o terminal, carregamos os dados salvos (carga automática)
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

    move $a0, $s0                    # 1º argumento: o comando digitado, para testar contra "infoGeral"
    la $a1, cmd_infoGeral            # 2º argumento: a string "infoGeral"
    jal strcmp                       # É o infoGeral?
    beqz $v0, executa_infoGeral      # Se deu 0 (iguais), pulamos para o infoGeral

    move $a0, $s0                    # 1º argumento: o comando digitado, para testar contra "formatar"
    la $a1, cmd_formatar             # 2º argumento: a string "formatar"
    jal strcmp                       # É o formatar?
    beqz $v0, executa_formatar       # Se deu 0 (iguais), pulamos para o formatar

    move $a0, $s0                    # 1º argumento: o comando digitado, para testar contra "limparAp"
    la $a1, cmd_limparAp             # 2º argumento: a string "limparAp"
    jal strcmp                       # É o limparAp?
    beqz $v0, executa_limparAp       # Se deu 0 (iguais), pulamos para o limparAp

    move $a0, $s0                    # 1º argumento: o comando digitado, para testar contra "addMorador"
    la $a1, cmd_addMorador           # 2º argumento: a string "addMorador"
    jal strcmp                       # É o addMorador?
    beqz $v0, executa_addMorador     # Se deu 0 (iguais), pulamos para o addMorador

    move $a0, $s0                    # 1º argumento: o comando digitado, para testar contra "infoAp"
    la $a1, cmd_infoAp               # 2º argumento: a string "infoAp"
    jal strcmp                       # É o infoAp?
    beqz $v0, executa_infoAp         # Se deu 0 (iguais), pulamos para o infoAp

    move $a0, $s0                    # 1º argumento: o comando digitado, para testar contra "rmvMorador"
    la $a1, cmd_rmvMorador           # 2º argumento: a string "rmvMorador"
    jal strcmp                       # É o rmvMorador?
    beqz $v0, executa_rmvMorador     # Se deu 0 (iguais), pulamos para o rmvMorador

    move $a0, $s0                    # 1º argumento: o comando digitado, para testar contra "addAuto"
    la $a1, cmd_addAuto_min          # 2º argumento: a string "addAuto"
    jal strcmp                       # É o addAuto?
    beqz $v0, executa_addAuto        # Se deu 0 (iguais), pulamos para o addAuto

    move $a0, $s0                    # 1º argumento: o comando digitado, para testar contra "AddAuto"
    la $a1, cmd_addAuto_mai          # 2º argumento: a string "AddAuto"
    jal strcmp                       # É o addAuto (grafia com A maiúsculo)?
    beqz $v0, executa_addAuto        # Se deu 0 (iguais), pulamos para o addAuto

    move $a0, $s0                    # 1º argumento: o comando digitado, para testar contra "rmvAuto"
    la $a1, cmd_rmvAuto              # 2º argumento: a string "rmvAuto"
    jal strcmp                       # É o rmvAuto?
    beqz $v0, executa_rmvAuto        # Se deu 0 (iguais), pulamos para o rmvAuto

    move $a0, $s0                    # 1º argumento: o comando digitado, para testar contra "salvar"
    la $a1, cmd_salvar               # 2º argumento: a string "salvar"
    jal strcmp                       # É o salvar?
    beqz $v0, executa_salvar         # Se deu 0 (iguais), pulamos para o salvar

    move $a0, $s0                    # 1º argumento: o comando digitado, para testar contra "recarregar"
    la $a1, cmd_recarregar           # 2º argumento: a string "recarregar"
    jal strcmp                       # É o recarregar?
    beqz $v0, executa_recarregar     # Se deu 0 (iguais), pulamos para o recarregar

comando_invalido:                    # Chegamos aqui se o comando não existe ou veio com opções erradas
    la $a0, msg_invalido             # Caso o comando seja desconhecido, puxa a mensagem de erro
    jal print_string_mmio            # Chama a função de print para exibir "Comando invalido"
    j parser_fim                     # Vai para o encerramento do interpretador

executa_infoGeral:                   # Desvio do comando infoGeral
    bnez $s1, comando_invalido       # O infoGeral não tem opções; se o usuário mandou alguma, é inválido
    jal comando_infoGeral            # Chama a rotina que mostra o panorama do condomínio
    j parser_fim                     # infoGeral concluído: vamos para o encerramento

executa_formatar:                    # Desvio do comando formatar
    bnez $s1, comando_invalido       # O formatar também não tem opções
    jal comando_formatar             # Chama a rotina que apaga os dados da memória
    j parser_fim                     # formatar concluído: vamos para o encerramento

executa_limparAp:                    # Desvio do comando limparAp
    li $t0, 1                        # O limparAp precisa de exatamente 1 opção (o número do AP)
    bne $s1, $t0, comando_invalido   # Se veio outra quantidade de opções, é inválido
    la $t0, opcoes                   # Carrega o endereço do nosso vetor de opções
    lw $a0, 0($t0)                   # Pega o endereço da 1ª opção (o número do AP digitado)
    jal comando_limparAp             # Chama a rotina que esvazia o AP
    j parser_fim                     # limparAp concluído: vamos para o encerramento

executa_addMorador:                  # Desvio do comando addMorador
    li $t0, 2                        # O addMorador precisa de exatamente 2 opções (AP e nome)
    bne $s1, $t0, comando_invalido   # Se veio outra quantidade de opções, é inválido
    la $t0, opcoes                   # Vetor com os endereços das opções do addMorador
    lw $a0, 0($t0)                   # 1ª opção: o número do AP
    lw $a1, 4($t0)                   # 2ª opção: o nome do morador
    lb $t1, 0($a1)                   # Olha o primeiro caractere do nome
    beqz $t1, comando_invalido       # Nome vazio ("--" sem nada depois) não vale
    jal comando_addMorador           # Chama a rotina que cadastra o morador
    j parser_fim                     # addMorador concluído: vamos para o encerramento

executa_infoAp:                      # Desvio do comando infoAp
    li $t0, 1                        # O infoAp precisa de exatamente 1 opção (número do AP ou "all")
    bne $s1, $t0, comando_invalido   # Se veio outra quantidade de opções, é inválido
    la $t0, opcoes                   # Vetor com o endereço da opção do infoAp
    lw $a0, 0($t0)                   # 1ª opção: o AP pedido (ou "all")
    jal comando_infoAp               # Chama a rotina que mostra o AP
    j parser_fim                     # infoAp concluído: vamos para o encerramento

executa_rmvMorador:                  # Desvio do comando rmvMorador
    li $t0, 2                        # O rmvMorador precisa de exatamente 2 opções (AP e nome)
    bne $s1, $t0, comando_invalido   # Se veio outra quantidade de opções, é inválido
    la $t0, opcoes                   # Vetor com os endereços das opções do rmvMorador
    lw $a0, 0($t0)                   # 1ª opção: o número do AP
    lw $a1, 4($t0)                   # 2ª opção: o nome a remover
    lb $t1, 0($a1)                   # Olha o primeiro caractere do nome a remover
    beqz $t1, comando_invalido       # Nome vazio não vale
    jal comando_rmvMorador           # Chama a rotina que remove o morador
    j parser_fim                     # rmvMorador concluído: vamos para o encerramento

executa_addAuto:                     # Desvio do comando addAuto (as duas grafias chegam aqui)
    li $t0, 4                        # O addAuto precisa de exatamente 4 opções (AP, tipo, modelo e placa)
    bne $s1, $t0, comando_invalido   # Se veio outra quantidade de opções, é inválido
    la $t0, opcoes                   # Vetor com os endereços das opções do addAuto
    lw $a0, 0($t0)                   # 1ª opção: o número do AP
    lw $a1, 4($t0)                   # 2ª opção: o tipo ('c' ou 'm')
    lw $a2, 8($t0)                   # 3ª opção: o modelo
    lw $a3, 12($t0)                  # 4ª opção: a placa
    lb $t1, 0($a2)                   # Olha o primeiro caractere do modelo
    beqz $t1, comando_invalido       # Modelo vazio não vale
    lb $t1, 0($a3)                   # Olha o primeiro caractere da placa
    beqz $t1, comando_invalido       # Placa vazia não vale
    jal comando_addAuto              # Chama a rotina que cadastra o veículo
    j parser_fim                     # addAuto concluído: vamos para o encerramento

executa_rmvAuto:                     # Desvio do comando rmvAuto
    li $t0, 2                        # O rmvAuto precisa de exatamente 2 opções (AP e placa)
    bne $s1, $t0, comando_invalido   # Se veio outra quantidade de opções, é inválido
    la $t0, opcoes                   # Vetor com os endereços das opções do rmvAuto
    lw $a0, 0($t0)                   # 1ª opção: o número do AP
    lw $a1, 4($t0)                   # 2ª opção: a placa a remover
    lb $t1, 0($a1)                   # Olha o primeiro caractere da placa
    beqz $t1, comando_invalido       # Placa vazia não vale
    jal comando_rmvAuto              # Chama a rotina que remove o veículo
    j parser_fim                     # rmvAuto concluído: vamos para o encerramento

executa_salvar:                      # Desvio do comando salvar
    bnez $s1, comando_invalido       # O salvar não tem opções
    jal comando_salvar               # Chama a rotina que grava o arquivo
    j parser_fim                     # salvar concluído: vamos para o encerramento

executa_recarregar:                  # Desvio do comando recarregar
    bnez $s1, comando_invalido       # O recarregar não tem opções
    jal rotina_recarregar            # Mesma rotina da carga automática do main
    j parser_fim                     # recarregar concluído: vamos para o encerramento

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
comando_infoAp:                      # Mostra um AP ou todos | $a0 = opção digitada (número do AP ou "all")
    addi $sp, $sp, -12               # Abre um espaço de 12 bytes na pilha
    sw $ra, 0($sp)                   # Salva nosso $ra, pois vamos chamar outras funções
    sw $s0, 4($sp)                   # Salva o $s0, que vai contar os APs no --all
    sw $s1, 8($sp)                   # Salva o $s1, onde vamos guardar a opção digitada
    move $s1, $a0                    # Guardamos a opção, já que o strcmp mexe no $a0
    la $a1, str_all                  # 2º argumento: a palavra "all"
    move $a0, $s1                    # 1º argumento: a opção que o usuário digitou
    jal strcmp                       # Confere se o usuário pediu todos os APs
    bnez $v0, info_ap_unico          # Se não for "all", mostramos só um AP
info_ap_all:                         # Caso "infoAp --all"
    li $s0, 0                        # Começamos pelo índice 0 (AP 101)
info_all_loop:                       # Laço que passa pelos 24 APs em ordem crescente
    li $t0, 24                       # Total de APs do condomínio
    beq $s0, $t0, info_fim           # Se já mostramos os 24, terminamos
    move $a0, $s0                    # Passa o índice do AP da vez
    jal imprime_ap                   # Imprime os dados desse AP
    addi $s0, $s0, 1                 # Vamos para o próximo AP
    j info_all_loop                  # Reinicia o laço
info_ap_unico:                       # Caso "infoAp --<número do AP>"
    move $a0, $s1                    # Passa o texto do AP digitado
    jal converte_ap                  # Transforma o texto do AP no índice
    bltz $v0, info_ap_invalido       # Se veio -1, o AP não existe
    move $a0, $v0                    # Passa o índice encontrado
    jal imprime_ap                   # Imprime os dados do AP pedido
    j info_fim                       # Pronto: vai para o encerramento
info_ap_invalido:                    # Caso o AP digitado não exista
    la $a0, msg_ap_invalido          # Puxa a mensagem "Falha: AP invalido"
    jal print_string_mmio            # Exibe a mensagem no terminal
info_fim:                            # Encerramento do comando
    lw $ra, 0($sp)                   # Recupera nosso $ra original da pilha
    lw $s0, 4($sp)                   # Recupera o $s0 original da pilha
    lw $s1, 8($sp)                   # Recupera o $s1 original da pilha
    addi $sp, $sp, 12                # Desaloca o espaço da pilha
    jr $ra                           # Retorna para o parser

# =========================================================
# FUNÇÃO: imprime_ap
# =========================================================
imprime_ap:                          # Imprime um AP no formato do enunciado | $a0 = índice do AP (0 a 23)
    addi $sp, $sp, -16               # Abre um espaço de 16 bytes na pilha
    sw $ra, 0($sp)                   # Salva nosso $ra, pois vamos chamar várias funções de impressão
    sw $s0, 4($sp)                   # Salva o $s0, que vai guardar o endereço do AP
    sw $s1, 8($sp)                   # Salva o $s1, que vai guardar o índice do AP
    sw $s2, 12($sp)                  # Salva o $s2, que vai contar moradores e motos
    move $s1, $a0                    # Guardamos o índice para calcular o número do AP depois
    jal endereco_ap                  # Descobre onde o AP começa na memória
    move $s0, $v0                    # $s0 = início do AP

    la $a0, msg_ap_label             # Carrega o texto "AP: "
    jal print_string_mmio            # Imprime "AP: "
    srl $t0, $s1, 1                  # índice / 2 (cada andar tem 2 APs)
    addi $t0, $t0, 1                 # + 1 = número do andar
    li $t1, 100                      # O andar ocupa as centenas do número do AP
    mul $t0, $t0, $t1                # andar x 100 (ex: 11 vira 1100)
    andi $t1, $s1, 1                 # índice resto 2 (0 = primeiro AP do andar, 1 = segundo)
    addi $t1, $t1, 1                 # + 1 = final do AP (01 ou 02)
    add $a0, $t0, $t1                # Número completo do AP (ex: 1100 + 2 = 1102)
    jal print_int_mmio               # Imprime o número do AP
    la $a0, msg_newline              # Carrega a quebra de linha
    jal print_string_mmio            # Fecha a linha "AP: número"

    lw $t0, 0($s0)                   # Lê a quantidade de moradores (primeira palavra do AP)
    beqz $t0, imprime_ap_vazio       # Sem moradores: só mostramos "Apartamento vazio"
    la $a0, msg_moradores_label      # Carrega o rótulo "Moradores:"
    jal print_string_mmio            # Imprime o rótulo da lista de moradores
    li $s2, 0                        # Começamos pelo primeiro morador (posição 0)
imprime_moradores_loop:              # Laço que imprime cada morador
    lw $t0, 0($s0)                   # Relemos a quantidade a cada volta (os prints mexem nos $t)
    beq $s2, $t0, imprime_moradores_fim # Se já imprimimos todos, seguimos para os veículos
    la $a0, msg_tab                  # Carrega a tabulação para recuar o nome
    jal print_string_mmio            # Imprime o \t antes do morador
    li $t1, 40                       # Cada nome ocupa 40 bytes
    mul $t1, $s2, $t1                # Posição do morador x 40
    addi $t1, $t1, 4                 # Os nomes começam depois da palavra da quantidade
    add $a0, $s0, $t1                # Endereço do nome desse morador
    jal print_string_mmio            # Imprime o nome
    la $a0, msg_newline              # Carrega a quebra de linha
    jal print_string_mmio            # Fecha a linha do morador
    addi $s2, $s2, 1                 # Vamos para o próximo morador
    j imprime_moradores_loop         # Reinicia o laço dos moradores
imprime_moradores_fim:               # Depois dos moradores, vêm os veículos
    lb $t0, 244($s0)                 # Lê o tipo de veículo do AP
    beqz $t0, imprime_ap_fim         # Tipo 0: o AP não tem veículo, terminamos
    li $t1, 99                       # Código ASCII do 'c' (carro)
    beq $t0, $t1, imprime_carro      # Se for carro, vamos para a impressão do carro
imprime_motos:                       # Se não é carro, são motos
    la $a0, msg_moto_label           # Carrega o rótulo "Moto:"
    jal print_string_mmio            # Imprime o rótulo das motos
    li $s2, 0                        # Começamos pela primeira moto (vaga 0)
imprime_motos_loop:                  # Laço que imprime cada moto
    lb $t2, 245($s0)                 # Relemos a quantidade a cada volta (o print_string_mmio altera o $t2)
    beq $s2, $t2, imprime_ap_fim     # Se já imprimimos todas, terminamos
    la $a0, msg_tab                  # Carrega a tabulação para recuar a moto
    jal print_string_mmio            # Imprime o \t antes da moto
    li $t1, 40                       # Cada vaga de veículo ocupa 40 bytes
    mul $t1, $s2, $t1                # Vaga da moto x 40
    addi $t1, $t1, 248               # Os veículos começam no offset 248
    add $a0, $s0, $t1                # Endereço do modelo da moto
    jal print_string_mmio            # Imprime o modelo
    la $a0, msg_sep_veiculo          # Carrega o separador " / "
    jal print_string_mmio            # Imprime o separador entre modelo e placa
    li $t1, 40                       # Calculamos a vaga de novo (o print mexeu no $t1)
    mul $t1, $s2, $t1                # Vaga da moto x 40, outra vez
    addi $t1, $t1, 278               # A placa fica 30 bytes depois do modelo (248 + 30)
    add $a0, $s0, $t1                # Endereço da placa da moto
    jal print_string_mmio            # Imprime a placa
    la $a0, msg_newline              # Carrega a quebra de linha
    jal print_string_mmio            # Fecha a linha da moto
    addi $s2, $s2, 1                 # Vamos para a próxima moto
    j imprime_motos_loop             # Reinicia o laço das motos
imprime_carro:                       # O AP tem um carro (só cabe 1 por AP)
    la $a0, msg_carro_label          # Carrega o rótulo "Carro:"
    jal print_string_mmio            # Imprime o rótulo do carro
    la $a0, msg_tab                  # Carrega a tabulação para recuar o carro
    jal print_string_mmio            # Imprime o \t antes do carro
    addi $a0, $s0, 248               # Endereço do modelo do carro (vaga 0)
    jal print_string_mmio            # Imprime o modelo do carro
    la $a0, msg_sep_veiculo          # Carrega o separador " / "
    jal print_string_mmio            # Imprime o separador entre o modelo e a placa do carro
    addi $a0, $s0, 278               # Endereço da placa do carro
    jal print_string_mmio            # Imprime a placa do carro
    la $a0, msg_newline              # Carrega a quebra de linha
    jal print_string_mmio            # Fecha a linha do carro
    j imprime_ap_fim                 # Pronto: vai para o encerramento
imprime_ap_vazio:                    # AP sem moradores
    la $a0, msg_ap_vazio             # Carrega "Apartamento vazio"
    jal print_string_mmio            # Imprime a mensagem pedida no enunciado
imprime_ap_fim:                      # Encerramento da impressão
    lw $ra, 0($sp)                   # Recupera nosso $ra original da pilha
    lw $s0, 4($sp)                   # Recupera o $s0 original da pilha
    lw $s1, 8($sp)                   # Recupera o $s1 original da pilha
    lw $s2, 12($sp)                  # Recupera o $s2 original da pilha
    addi $sp, $sp, 16                # Desaloca o espaço da pilha
    jr $ra                           # Retorna para o comando_infoAp

# =========================================================
# FUNÇÃO: comando_rmvMorador
# =========================================================
comando_rmvMorador:                  # Remove um morador | $a0 = string do AP, $a1 = nome do morador
    addi $sp, $sp, -16               # Abre um espaço de 16 bytes na pilha
    sw $ra, 0($sp)                   # Salva nosso $ra, pois vamos chamar outras funções
    sw $s0, 4($sp)                   # Salva o $s0, onde vamos guardar o endereço do AP
    sw $s1, 8($sp)                   # Salva o $s1, onde vamos guardar o nome procurado
    sw $s2, 12($sp)                  # Salva o $s2, que vai ser a posição do morador na lista
    move $s1, $a1                    # Guardamos o nome, já que as próximas chamadas mexem nos $a
    jal converte_ap                  # Transforma o texto do AP no índice
    bltz $v0, rmv_mor_invalido       # Se veio -1, o AP não existe
    move $a0, $v0                    # Passa o índice do AP
    jal endereco_ap                  # Descobre onde o AP começa na memória
    move $s0, $v0                    # $s0 = início do AP
    li $s2, 0                        # Começamos a procurar pelo primeiro morador
rmv_mor_busca:                       # Laço que procura o nome entre os moradores
    lw $t0, 0($s0)                   # Lê a quantidade de moradores
    beq $s2, $t0, rmv_mor_nao_acha   # Se passamos por todos e não achamos, o morador não existe
    li $t1, 40                       # Cada nome ocupa 40 bytes
    mul $t1, $s2, $t1                # Posição atual x 40
    addi $t1, $t1, 4                 # Os nomes começam depois da palavra da quantidade
    add $a0, $s0, $t1                # 1º argumento: nome cadastrado nessa posição
    move $a1, $s1                    # 2º argumento: nome que o usuário quer remover
    jal strcmp                       # Compara os dois nomes
    beqz $v0, rmv_mor_achou          # Se deu 0 (iguais), achamos o morador
    addi $s2, $s2, 1                 # Senão, olhamos o próximo morador
    j rmv_mor_busca                  # Reinicia a busca
rmv_mor_achou:                       # Achamos o morador na posição $s2
    lw $t0, 0($s0)                   # Lê a quantidade de moradores
    addi $t0, $t0, -1                # Um morador a menos
    sw $t0, 0($s0)                   # Grava a nova quantidade
rmv_mor_compacta:                    # Puxa os moradores seguintes uma vaga para cima (sem deixar buraco)
    lw $t0, 0($s0)                   # Lê a nova quantidade
    beq $s2, $t0, rmv_mor_limpa_ult  # Quando chegamos ao fim da lista, paramos de puxar
    addi $t1, $s2, 1                 # Posição do morador seguinte
    li $t2, 40                       # Cada nome ocupa 40 bytes
    mul $t3, $t1, $t2                # Posição seguinte x 40
    addi $t3, $t3, 4                 # Pula a palavra da quantidade (origem)
    add $a1, $s0, $t3                # Origem: nome do morador seguinte
    mul $t3, $s2, $t2                # Posição atual x 40
    addi $t3, $t3, 4                 # Pula a palavra da quantidade (destino)
    add $a0, $s0, $t3                # Destino: vaga atual
    li $a2, 39                       # No máximo 39 caracteres (o 40º byte é do \0)
    jal strcpy                       # Copia o morador seguinte para a vaga atual
    addi $s2, $s2, 1                 # Avança para a próxima vaga
    j rmv_mor_compacta               # Reinicia o laço de compactação
rmv_mor_limpa_ult:                   # Apaga a última vaga, que ficou repetida depois de puxar
    lw $t0, 0($s0)                   # A vaga que sobrou é a de número "quantidade"
    li $t1, 40                       # Cada nome ocupa 40 bytes
    mul $t1, $t0, $t1                # Posição da vaga que sobrou x 40
    addi $t1, $t1, 4                 # Pula a palavra da quantidade
    add $t1, $s0, $t1                # Endereço da vaga que sobrou
    li $t2, 40                       # Vamos zerar os 40 bytes dela
rmv_mor_zera_ult:                    # Laço que zera a vaga byte a byte
    sb $zero, 0($t1)                 # Zera 1 byte do nome
    addi $t1, $t1, 1                 # Avança para o próximo byte
    addi $t2, $t2, -1                # Diminui o contador de bytes que faltam
    bnez $t2, rmv_mor_zera_ult       # Continua até zerar a vaga inteira
    lw $t0, 0($s0)                   # Confere quantos moradores sobraram
    bnez $t0, rmv_mor_fim            # Se ainda tem morador, terminamos
rmv_mor_apaga_veiculos:              # O AP ficou vazio: o enunciado manda apagar os veículos
    addi $t0, $s0, 244               # Início da área de veículos (tipo, quantidade e vagas)
    li $t1, 21                       # Palavras até o fim do AP (84 bytes / 4)
rmv_mor_zera_veic:                   # Laço que zera os veículos
    sw $zero, 0($t0)                 # Zera 4 bytes de uma vez
    addi $t0, $t0, 4                 # Avança para a próxima palavra
    addi $t1, $t1, -1                # Diminui o contador de palavras que faltam
    bnez $t1, rmv_mor_zera_veic      # Continua até zerar a área de veículos
    j rmv_mor_fim                    # Pronto: vai para o encerramento
rmv_mor_nao_acha:                    # Caso o nome não esteja no AP
    la $a0, msg_nao_encontrado       # Puxa a mensagem "Falha: morador nao encontrado"
    jal print_string_mmio            # Exibe a mensagem no terminal
    j rmv_mor_fim                    # Vai para o encerramento
rmv_mor_invalido:                    # Caso o AP digitado não exista
    la $a0, msg_ap_invalido          # Puxa a mensagem "Falha: AP invalido"
    jal print_string_mmio            # Exibe a mensagem no terminal
rmv_mor_fim:                         # Encerramento do comando
    lw $ra, 0($sp)                   # Recupera nosso $ra original da pilha
    lw $s0, 4($sp)                   # Recupera o $s0 original da pilha
    lw $s1, 8($sp)                   # Recupera o $s1 original da pilha
    lw $s2, 12($sp)                  # Recupera o $s2 original da pilha
    addi $sp, $sp, 16                # Desaloca o espaço da pilha
    jr $ra                           # Retorna para o parser

# =========================================================
# FUNÇÃO: comando_addAuto
# =========================================================
comando_addAuto:                     # Cadastra um veículo | $a0 = AP, $a1 = tipo, $a2 = modelo, $a3 = placa
    addi $sp, $sp, -20               # Abre um espaço de 20 bytes na pilha
    sw $ra, 0($sp)                   # Salva nosso $ra, pois vamos chamar outras funções
    sw $s0, 4($sp)                   # Salva o $s0, onde vamos guardar o endereço do AP
    sw $s1, 8($sp)                   # Salva o $s1, onde vamos guardar o tipo
    sw $s2, 12($sp)                  # Salva o $s2, onde vamos guardar o modelo
    sw $s3, 16($sp)                  # Salva o $s3, onde vamos guardar a placa
    move $s1, $a1                    # Guardamos o tipo, já que as próximas chamadas mexem nos $a
    move $s2, $a2                    # Guardamos o modelo
    move $s3, $a3                    # Guardamos a placa
    jal converte_ap                  # Transforma o texto do AP no índice
    bltz $v0, add_auto_invalido      # Se veio -1, o AP não existe
    move $a0, $v0                    # Passa o índice do AP
    jal endereco_ap                  # Descobre onde o AP começa na memória
    move $s0, $v0                    # $s0 = início do AP
    lb $t0, 0($s1)                   # Lê o primeiro caractere do tipo
    lb $t1, 1($s1)                   # Lê o segundo caractere do tipo
    bnez $t1, add_auto_tipo_inv      # O tipo precisa ter 1 caractere só ("c" ou "m")
    li $t2, 99                       # Código ASCII do 'c' (carro)
    beq $t0, $t2, add_auto_tipo_ok   # Se for 'c', o tipo é válido
    li $t2, 109                      # Código ASCII do 'm' (moto)
    beq $t0, $t2, add_auto_tipo_ok   # Se for 'm', o tipo também é válido
    j add_auto_tipo_inv              # Qualquer outra coisa é tipo inválido
add_auto_tipo_ok:                    # Tipo válido: agora conferimos o AP
    lw $t0, 0($s0)                   # Lê a quantidade de moradores
    beqz $t0, add_auto_vazio         # AP sem moradores não pode ter veículo
    lb $t0, 244($s0)                 # Lê o tipo de veículo que o AP já tem
    beqz $t0, add_auto_livre         # Tipo 0: a garagem está livre
    j add_auto_grava_moto_check      # Já tem veículo: conferimos se ainda cabe uma 2ª moto
add_auto_livre:                      # Garagem livre
    lb $t0, 0($s1)                   # Lê o tipo do veículo novo
    li $t1, 99                       # Código ASCII do 'c' para comparar
    beq $t0, $t1, add_auto_grava     # Carro em garagem livre: pode gravar direto
    j add_auto_grava_moto_check      # Moto: passa pela conferência das motos
add_auto_grava_moto_check:           # Regra do condomínio: 1 carro OU até 2 motos
    lb $t0, 244($s0)                 # Lê o tipo que o AP já tem
    beqz $t0, add_auto_grava         # Se a garagem está livre, a moto pode entrar
    li $t1, 109                      # Código ASCII do 'm' para conferir o que já está lá
    bne $t0, $t1, add_auto_cheio     # Se o AP já tem carro, não cabe mais nada
    lb $t0, 0($s1)                   # Lê o tipo do veículo novo
    li $t1, 109                      # Código ASCII do 'm' para conferir o que está chegando
    bne $t0, $t1, add_auto_cheio     # Carro em AP que já tem moto: não pode misturar
    lb $t0, 245($s0)                 # Lê quantas motos o AP já tem
    li $t1, 2                        # Limite de 2 motos por AP
    bge $t0, $t1, add_auto_cheio     # Se já tem 2, a 3ª é recusada
    j add_auto_grava                 # Ainda cabe: pode gravar a 2ª moto
add_auto_cheio:                      # Caso a garagem já esteja no limite
    la $a0, msg_max_autos            # Puxa a mensagem "Falha: AP com numero max de automoveis"
    jal print_string_mmio            # Exibe a mensagem no terminal
    j add_auto_fim                   # Vai para o encerramento
add_auto_vazio:                      # Caso o AP não tenha moradores
    la $a0, msg_ap_vazio_auto        # Puxa a mensagem "Falha: AP vazio"
    jal print_string_mmio            # Exibe a mensagem no terminal
    j add_auto_fim                   # Vai para o encerramento
add_auto_tipo_inv:                   # Caso o tipo não seja 'c' nem 'm'
    la $a0, msg_tipo_invalido        # Puxa a mensagem "Falha: tipo invalido"
    jal print_string_mmio            # Exibe a mensagem no terminal
    j add_auto_fim                   # Vai para o encerramento
add_auto_grava:                      # Grava o veículo na próxima vaga livre
    lb $t0, 245($s0)                 # A quantidade de veículos é o número da vaga livre
    li $t1, 40                       # Cada vaga ocupa 40 bytes
    mul $t1, $t0, $t1                # Vaga x 40
    addi $t1, $t1, 248               # Os veículos começam no offset 248
    add $a0, $s0, $t1                # Destino: campo do modelo na vaga livre
    move $a1, $s2                    # Origem: modelo digitado
    li $a2, 29                       # No máximo 29 caracteres (o 30º byte é do \0)
    jal strcpy                       # Copia o modelo
    lb $t0, 245($s0)                 # Lê de novo a quantidade (o strcpy mexe no $t0)
    li $t1, 40                       # Cada vaga ocupa 40 bytes
    mul $t1, $t0, $t1                # Vaga x 40, para achar a placa
    addi $t1, $t1, 278               # A placa fica 30 bytes depois do modelo (248 + 30)
    add $a0, $s0, $t1                # Destino: campo da placa na vaga livre
    move $a1, $s3                    # Origem: placa digitada
    li $a2, 9                        # No máximo 9 caracteres (o 10º byte é do \0)
    jal strcpy                       # Copia a placa
    lb $t0, 0($s1)                   # Lê o tipo do veículo novo
    sb $t0, 244($s0)                 # Grava o tipo do AP ('c' ou 'm')
    lb $t0, 245($s0)                 # Lê a quantidade de veículos
    addi $t0, $t0, 1                 # Mais um veículo
    sb $t0, 245($s0)                 # Grava a nova quantidade
    j add_auto_fim                   # Cadastro feito: vai para o encerramento
add_auto_invalido:                   # Caso o AP digitado não exista
    la $a0, msg_ap_invalido          # Puxa a mensagem "Falha: AP invalido"
    jal print_string_mmio            # Exibe a mensagem no terminal
add_auto_fim:                        # Encerramento do comando
    lw $ra, 0($sp)                   # Recupera nosso $ra original da pilha
    lw $s0, 4($sp)                   # Recupera o $s0 original da pilha
    lw $s1, 8($sp)                   # Recupera o $s1 original da pilha
    lw $s2, 12($sp)                  # Recupera o $s2 original da pilha
    lw $s3, 16($sp)                  # Recupera o $s3 original da pilha
    addi $sp, $sp, 20                # Desaloca o espaço da pilha
    jr $ra                           # Retorna para o parser

# =========================================================
# FUNÇÃO: comando_rmvAuto
# =========================================================
comando_rmvAuto:                     # Remove um veículo pela placa | $a0 = string do AP, $a1 = placa
    addi $sp, $sp, -12               # Abre um espaço de 12 bytes na pilha
    sw $ra, 0($sp)                   # Salva nosso $ra, pois vamos chamar outras funções
    sw $s0, 4($sp)                   # Salva o $s0, onde vamos guardar o endereço do AP
    sw $s1, 8($sp)                   # Salva o $s1, onde vamos guardar a placa procurada
    move $s1, $a1                    # Guardamos a placa, já que as próximas chamadas mexem nos $a
    jal converte_ap                  # Transforma o texto do AP no índice
    bltz $v0, rmv_auto_invalido      # Se veio -1, o AP não existe
    move $a0, $v0                    # Passa o índice do AP
    jal endereco_ap                  # Descobre onde o AP começa na memória
    move $s0, $v0                    # $s0 = início do AP
    lb $t0, 245($s0)                 # Lê quantos veículos o AP tem
    beqz $t0, rmv_auto_nao_enc       # Sem veículos, a placa com certeza não está aqui
    addi $a0, $s0, 278               # 1º argumento: placa da vaga 0
    move $a1, $s1                    # 2º argumento: placa digitada
    jal strcmp                       # Compara com a placa da vaga 0
    beqz $v0, rmv_auto_achou_0       # Se deu 0 (iguais), é o veículo da vaga 0
    lb $t0, 245($s0)                 # Lê de novo a quantidade de veículos
    li $t1, 2                        # Só existe vaga 1 se o AP tiver 2 motos
    blt $t0, $t1, rmv_auto_nao_enc   # Com 1 veículo só, não há mais onde procurar
    addi $a0, $s0, 318               # 1º argumento: placa da vaga 1 (288 + 30)
    move $a1, $s1                    # 2º argumento: a mesma placa digitada
    jal strcmp                       # Compara com a placa da vaga 1
    beqz $v0, rmv_auto_achou_1       # Se deu 0 (iguais), é o veículo da vaga 1
    j rmv_auto_nao_enc               # Não achamos em nenhuma vaga
rmv_auto_achou_0:                    # O veículo está na vaga 0
    lb $t0, 245($s0)                 # Lê a quantidade de veículos
    li $t1, 2                        # Confere se existe uma 2ª moto
    blt $t0, $t1, rmv_auto_unico     # Se era o único veículo, só apagamos a vaga 0
    addi $a0, $s0, 248               # Destino: modelo da vaga 0
    addi $a1, $s0, 288               # Origem: modelo da vaga 1
    li $a2, 29                       # No máximo 29 caracteres no modelo
    jal strcpy                       # Puxa o modelo da 2ª moto para a vaga 0
    addi $a0, $s0, 278               # Destino: placa da vaga 0
    addi $a1, $s0, 318               # Origem: placa da vaga 1
    li $a2, 9                        # No máximo 9 caracteres na placa
    jal strcpy                       # Puxa a placa da 2ª moto para a vaga 0
    j rmv_auto_dec_qtd               # Agora só falta diminuir a quantidade
rmv_auto_achou_1:                    # O veículo está na vaga 1 (2ª moto)
    addi $t0, $s0, 288               # Início da vaga 1
    li $t1, 40                       # Vamos zerar os 40 bytes da vaga 1
rmv_auto_zera_1:                     # Laço que zera a vaga 1 byte a byte
    sb $zero, 0($t0)                 # Zera 1 byte da vaga 1
    addi $t0, $t0, 1                 # Avança para o próximo byte da vaga 1
    addi $t1, $t1, -1                # Diminui o contador de bytes da vaga 1
    bnez $t1, rmv_auto_zera_1        # Continua até zerar a vaga 1 inteira
    j rmv_auto_dec_qtd               # Agora só falta diminuir a quantidade
rmv_auto_unico:                      # Era o único veículo do AP
    addi $t0, $s0, 248               # Início da vaga 0
    li $t1, 40                       # Vamos zerar os 40 bytes da vaga 0
rmv_auto_zera_0:                     # Laço que zera a vaga 0 byte a byte
    sb $zero, 0($t0)                 # Zera 1 byte da vaga 0
    addi $t0, $t0, 1                 # Avança para o próximo byte da vaga 0
    addi $t1, $t1, -1                # Diminui o contador de bytes da vaga 0
    bnez $t1, rmv_auto_zera_0        # Continua até zerar a vaga 0 inteira
    sb $zero, 244($s0)               # A garagem fica livre: tipo volta para 0
rmv_auto_dec_qtd:                    # Atualiza a quantidade de veículos
    lb $t0, 245($s0)                 # Lê a quantidade de veículos
    addi $t0, $t0, -1                # Um veículo a menos
    sb $t0, 245($s0)                 # Grava a nova quantidade
    beqz $t0, rmv_auto_zera_tipo     # Se não sobrou nenhum, liberamos a garagem
    j rmv_auto_fim                   # Ainda sobrou uma moto: terminamos
rmv_auto_zera_tipo:                  # Garagem vazia
    sb $zero, 244($s0)               # Tipo volta para 0 (assim o AP aceita carro de novo)
    j rmv_auto_fim                   # Vai para o encerramento
rmv_auto_nao_enc:                    # Caso a placa não esteja no AP
    la $a0, msg_auto_nao_enc         # Puxa a mensagem "Falha: automovel nao encontrado"
    jal print_string_mmio            # Exibe a mensagem no terminal
    j rmv_auto_fim                   # Vai para o encerramento
rmv_auto_invalido:                   # Caso o AP digitado não exista
    la $a0, msg_ap_invalido          # Puxa a mensagem "Falha: AP invalido"
    jal print_string_mmio            # Exibe a mensagem no terminal
rmv_auto_fim:                        # Encerramento do comando
    lw $ra, 0($sp)                   # Recupera nosso $ra original da pilha
    lw $s0, 4($sp)                   # Recupera o $s0 original da pilha
    lw $s1, 8($sp)                   # Recupera o $s1 original da pilha
    addi $sp, $sp, 12                # Desaloca o espaço da pilha
    jr $ra                           # Retorna para o parser

# =========================================================
# FUNÇÃO: comando_salvar
# =========================================================
comando_salvar:                      # Grava os 7872 bytes do condomínio em condominio.dat (syscalls 13, 15 e 16)
    addi $sp, $sp, -8                # Abre um espaço de 8 bytes na pilha
    sw $ra, 0($sp)                   # Salva nosso $ra, pois podemos chamar o print
    sw $s0, 4($sp)                   # Salva o $s0, que vai guardar o descritor do arquivo

    la $a0, nome_arquivo             # Nome do arquivo que vamos abrir (ou criar)
    li $a1, 1                        # Flag 1 = escrita (cria ou sobrescreve o arquivo)
    li $a2, 0                        # Modo de permissão (o MARS ignora)
    li $v0, 13                       # Syscall 13 = abrir arquivo
    syscall                          # Abre o arquivo; o descritor volta no $v0
    bltz $v0, salvar_erro            # Descritor negativo: não conseguimos abrir

    move $s0, $v0                    # Guardamos o descritor no $s0
    move $a0, $s0                    # 1º argumento: descritor do arquivo
    la $a1, condominio               # 2º argumento: início do nosso banco de dados
    li $a2, 7872                     # 3º argumento: quantidade de bytes (24 APs x 328)
    li $v0, 15                       # Syscall 15 = escrever no arquivo
    syscall                          # Grava o condomínio inteiro de uma vez

    move $a0, $s0                    # Passa o descritor para fechar
    li $v0, 16                       # Syscall 16 = fechar arquivo
    syscall                          # Fecha o arquivo, garantindo que tudo foi gravado
    j salvar_fim                     # Pronto: vai para o encerramento

salvar_erro:                         # Caso não dê para abrir o arquivo para escrita
    la $a0, msg_erro_salvar          # Puxa a mensagem "Falha: erro ao salvar arquivo"
    jal print_string_mmio            # Exibe a mensagem no terminal

salvar_fim:                          # Encerramento do comando
    lw $ra, 0($sp)                   # Recupera nosso $ra original da pilha
    lw $s0, 4($sp)                   # Recupera o $s0 original da pilha
    addi $sp, $sp, 8                 # Desaloca o espaço da pilha
    jr $ra                           # Retorna para o parser

# =========================================================
# FUNÇÃO: rotina_recarregar
# =========================================================
rotina_recarregar:                   # Lê condominio.dat por cima da memória (usada no main e no comando recarregar)
    addi $sp, $sp, -8                # Abre um espaço de 8 bytes na pilha
    sw $ra, 0($sp)                   # Salva nosso $ra
    sw $s0, 4($sp)                   # Salva o $s0, que vai guardar o descritor do arquivo

    la $a0, nome_arquivo             # Nome do arquivo que vamos abrir
    li $a1, 0                        # Flag 0 = leitura
    li $a2, 0                        # Modo de permissão (o MARS ignora)
    li $v0, 13                       # Syscall 13 = abrir arquivo
    syscall                          # Abre o arquivo; o descritor volta no $v0
    bltz $v0, rec_nao_enc            # Descritor negativo: o arquivo ainda não existe (1ª execução)

    move $s0, $v0                    # Guardamos o descritor no $s0
    move $a0, $s0                    # 1º argumento: descritor do arquivo
    la $a1, condominio               # 2º argumento: onde os dados vão ser colocados na memória
    li $a2, 7872                     # 3º argumento: quantidade de bytes a ler
    li $v0, 14                       # Syscall 14 = ler do arquivo
    syscall                          # Carrega os dados salvos por cima do condomínio atual

    move $a0, $s0                    # Passa o descritor para fechar
    li $v0, 16                       # Syscall 16 = fechar arquivo
    syscall                          # Fecha o arquivo
    j rec_fim                        # Pronto: vai para o encerramento

rec_nao_enc:                         # Sem arquivo: o condomínio continua como está, sem mensagem
rec_fim:                             # Encerramento da rotina
    lw $ra, 0($sp)                   # Recupera nosso $ra original da pilha
    lw $s0, 4($sp)                   # Recupera o $s0 original da pilha
    addi $sp, $sp, 8                 # Desaloca o espaço da pilha
    jr $ra                           # Retorna para quem chamou (main ou parser)
