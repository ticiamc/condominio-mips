# Condomínio MIPS — Projeto 01 AOC 2026.2

**Disciplina:** Arquitetura e Organização de Computadores — UFRPE 2026.2  
**Integrantes:** Letícia Medeiros Cavalcante · Sarah Pereira de Araújo Lima  
**Professor:** Vítor A Coutinho

---

## Como rodar

1. Abra o MARS (versão 4.5+).  
2. File → Open → selecione `projeto1.asm`.  
3. Pressione **F3** para montar (deve compilar sem erros ou avisos).  
4. Tools → Keyboard and Display MMIO Simulator → **Connect to MIPS**.  
5. Pressione **F5** (Run). O prompt `LS-shell>> ` aparece no Display.  
6. Clique na área do teclado do simulador para começar a digitar.

> **Atenção:** o arquivo `condominio.dat` é procurado e criado na pasta de onde o MARS foi iniciado, não na do `.asm`. Para o `salvar`/`recarregar` funcionarem, abra o MARS a partir dessa pasta (ou ajuste o caminho no `nome_arquivo` no `.data`).

---

## Comandos disponíveis

| Comando | Descrição | Exemplo |
|---|---|---|
| `addMorador --AP --Nome` | Cadastra um morador no AP | `addMorador --101 --Ana Silva` |
| `rmvMorador --AP --Nome` | Remove um morador do AP | `rmvMorador --101 --Ana Silva` |
| `addAuto --AP --tipo --modelo --placa` | Cadastra veículo (`c`=carro, `m`=moto) | `addAuto --302 --c --Fiat Uno --ABC1234` |
| `rmvAuto --AP --placa` | Remove veículo pela placa | `rmvAuto --302 --ABC1234` |
| `limparAp --AP` | Esvazia completamente um AP | `limparAp --1001` |
| `infoAp --AP` | Exibe moradores e veículos de um AP | `infoAp --1102` |
| `infoAp --all` | Exibe todos os 24 APs em ordem | `infoAp --all` |
| `infoGeral` | Panorama de APs vazios e não vazios | `infoGeral` |
| `salvar` | Grava todos os dados em `condominio.dat` | `salvar` |
| `recarregar` | Restaura os dados do arquivo (descarta alterações não salvas) | `recarregar` |
| `formatar` | Apaga tudo da sessão atual (não grava no arquivo) | `formatar` |

As opções seguem o formato ` --` (espaço + dois hífens) definido no enunciado escrito. Os APs vão de 101 a 1202 e terminam sempre em 01 ou 02 (12 andares × 2 APs).

---

## Estrutura de memória — 328 bytes por AP

| Offset | Tamanho | Conteúdo |
|---|---|---|
| 0 | 4 bytes (palavra) | Quantidade de moradores (0 = AP vazio) |
| 4 | 6 × 40 bytes | Nomes dos moradores (até 39 chars + `\0`) |
| 244 | 1 byte | Tipo de veículo: `0`=nenhum, `'c'`=carro, `'m'`=moto |
| 245 | 1 byte | Quantidade de veículos (0, 1 ou 2) |
| 246 | 2 bytes | Alinhamento |
| 248 | 2 × 40 bytes | Veículos: modelo (30 B) + placa (10 B) cada |

Fórmula do índice: `(andar - 1) × 2 + (final - 1)` → AP 101 = índice 0, AP 1202 = índice 23.

---

## Arquivo salvo

- **Nome:** `condominio.dat`  
- **Formato:** dump binário dos 7872 bytes (`24 × 328`) do array `condominio`.  
- **Local:** mesma pasta de onde o MARS é aberto.  
- **Gravação:** syscall 15 (write) após syscall 13 (open, flag=1).  
- **Leitura:** syscall 14 (read) após syscall 13 (open, flag=0); na inicialização, se o arquivo não existir, o programa começa com todos os APs vazios, sem mensagem de erro.

---

## Decisões de projeto

| Situação | Decisão | Motivo |
|---|---|---|
| Numeração dos APs | De 101 a 1202, final 01 ou 02; outros números dão `Falha: AP invalido` | O prédio tem 2 APs por andar; os exemplos do enunciado com o AP 303 (e o 300/100 do `infoGeral`) parecem vir de outra configuração de prédio |
| Veículo em AP vazio | Recusar com `Falha: AP vazio` | O `infoAp` de AP sem moradores mostra só "Apartamento vazio"; carro ficaria oculto |
| `AddAuto` vs `addAuto` | Aceitar os dois | O exemplo do enunciado usa minúsculo; o título pode ser correção automática do editor |
| Placa repetida | Não verificar; `rmvAuto` remove o primeiro com a placa | Enunciado só prevê falhas de limite, AP e tipo |
| Nome repetido | Permitir; `rmvMorador` remove o primeiro com o nome | O único limite do enunciado é 6 moradores |
| Máximo de motos | 2 | A regra aparece nos requisitos e no `addAuto`; a 3ª moto do modelo do `infoAp` é inconsistência do texto |
| Arquivo inexistente ao iniciar | Começar vazio, sem mensagem | Primeira execução; o enunciado só pede resgate automático dos dados |
| Falha no `salvar` | `Falha: erro ao salvar arquivo` | Mesmo padrão das outras mensagens de falha |
| `recarregar` sem arquivo | Sem mensagem (comportamento idêntico à inicialização) | Consistência com a carga automática |
| Acentos nas mensagens | Sem acento (ex: `automoveis`, `automovel`) | Sugestão do professor para evitar problemas com o MMIO |
| Mensagem de sucesso | Nenhuma | Igual aos comandos já existentes |
| Ordem das checagens | AP sempre primeiro | Igual aos comandos já existentes |
| Nome/opção vazia | Cortar em 39 chars / `Comando invalido` | Definido no `addMorador` dos commits anteriores |
| Backspace | Aparece como □ no display, mas funciona | Limitação do display do MARS |
