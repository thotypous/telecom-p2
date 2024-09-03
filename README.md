# Interface E1

## Introdução

Nesta prática, vamos implementar uma interface [E1](https://web.fe.up.pt/~mleitao/STEL/Tecnico/E1_ACTERNA.pdf) ligada a uma lógica capaz de responder pings (ICMP) sobre IPv4 sobre HDLC.

## Dependências

No Arch Linux, utilize os pacotes a seguir obtidos do [AUR](https://aur.archlinux.org) ou precompilados do [Chaotic AUR](https://aur.chaotic.cx):

```bash
sudo pacman -S bluespec-git bluespec-contrib-git yosys-git nextpnr-git prjapicula verilator openfpgaloader
```

Se você usa outra distribuição, prefixe todos os comandos descritos neste documento com `./run-docker` para executá-los dentro de um container.

## Síntese e execução dos testes

Para sintetizar a lógica para FPGA, execute `make`. Para carregar em um kit de desenvolvimento, execute `make load`.

Para compilar um teste, execute `make TestNOME.exe`, e para executá-lo, faça `./TesteNOME.exe`, substituindo sempre `NOME` pelo nome do teste.

Para fazer tudo com um único comando (sintetizar e executar todos os testes), execute `./run-grader`. No entanto, note que esse comando suprime a saída dos testes (para evitar gerar logs de centenas de megabytes), mostrando apenas o resultado final de cada teste (falha ou sucesso). Portanto, durante o desenvolvimento, é melhor executar os testes individualmente.

## Implementação

As partes do código que estão faltando são descritas a seguir. Elas são independentes e não precisam ser implementadas em nenhuma ordem particular. No entanto, eu recomendo deixar o DPLL por último, pois é possível realizar um teste de bancada parcial mesmo se ele não estiver implementado.

### HDB3Decoder

Implemente o módulo [mkHDB3Decoder](HDB3Decoder.bsv), que deve receber como entrada símbolos em três níveis (P, Z ou N) codificados em [HDB3](https://web.fe.up.pt/~mleitao/STEL/Tecnico/E1_ACTERNA.pdf#page=37) e produzir como saída bits (1 ou 0). Isso nada mais é que a operação inversa do que está implementado no [HDB3Encoder](HDB3Encoder.bsv).

Note que, geralmente, basta converter os níveis zero (Z) em bits 0, e os pulsos positivos ou negativos (P ou N) em bits 1. A parte um pouco mais complicada é detectar as sequências que originalmente (antes da codificação em HDB3) eram quatro zeros seguidos — elas podem ter virado PZZP, NZZN, ZZZP (depois de um P) ou ZZZN (depois de um N). Nesses casos, os quatro símbolos pertencentes à sequência precisam virar bits 0 de volta; em outras palavras, os pulsos presentes nesses quatro símbolos não podem virar bits 1 como de costume.

Apesar de existirem várias formas de armazenar em hardware a informação necessária para realizar essa decodificação, o trecho que entregamos pronto no [HDB3Decoder](HDB3Decoder.bsv) usa uma estrutura análoga à que usamos no [HDB3Encoder](HDB3Encoder.bsv). Há quatro FIFOs de um elemento cada, sendo que os símbolos entram por `fifos[3]`, depois passam por `fifos[2]`, `fifos[1]` e, finalmente, chegam a `fifos[0]`, de onde são retirados para processamento. Assim, o método `get` deve sempre retornar o bit correspondente ao processamento do símbolo contido em `fifos[0]`, mas ele tem à disposição um *look-ahead* (ou seja, pode dar uma bisbilhotada nos símbolos que virão logo a seguir) em `fifos[1]`, `fifos[2]` e `fifos[3]`.

![](fig/hdb3_fifos.svg)

No entanto, não é obrigatório utilizar a estrutura sugerida! Fique à vontade para modificar completamente o código do [HDB3Decoder](HDB3Decoder.bsv) se você achar conveniente.

Teste seu código com `make TestHDB3.exe && ./TestHDB3.exe`.

### E1Unframer

Implemente o módulo [mkE1Unframer](E1Unframer.bsv), que deve receber como entrada um bit e produzir como saída uma tupla contendo o índice do timeslot ao qual esse bit pertence e uma cópia do bit.

Para descobrir a qual timeslot cada bit pertence, deve-se localizar o TS0, que alterna entre as sequências [FAS e NFAS](https://web.fe.up.pt/~mleitao/STEL/Tecnico/E1_ACTERNA.pdf#page=15).

O módulo deve começar no estado `UNSYNCED` e, ao encontrar a sequência `0011011` (FAS), deve alternar para o estado `FIRST_FAS` e considerar que o próximo bit a ser recebido provavelmente é o bit mais significativo do TS1. Ao chegar no TS0 seguinte, o módulo deve verificar se ele contém uma sequência que possa ser considerada válida como NFAS (o segundo bit de MSB para LSB deve ser 1); em caso positivo, deve alternar para o estado `FIRST_NFAS`, senão voltar para `UNSYNCED`. Por fim, o módulo deve novamente esperar pelo TS0 seguinte e verificar se é um FAS, caso no qual deve alternar para o estado `SYNCED`, senão voltar para `UNSYNCED`.

O módulo **não** deve produzir saída em `out` enquanto não estiver no estado `SYNCED`.

Quando no estado `SYNCED`, o módulo deve sempre verificar os TS0 a fim de validar se contém sequências de FAS e NFAS alternadas e, caso contrário, chavear para o estado `UNSYNCED`.

Pode ser chato produzir saídas válidas para os TS0 quando estiverem ocorrendo transições para dentro ou para fora do estado `SYNCED`. Então, para facilitar a sua vida, o teste não vai verificar se as saídas correspondentes aos TS0 estão corretas; ele verifica apenas as saídas correspondentes aos TS1-31.

Note que você pode dar outros nomes aos estados se você preferir, e que o trecho de código que já veio preenchido no [E1Unframer](E1Unframer.bsv) é apenas uma sugestão.

Teste seu código com `make TestE1.exe && ./TestE1.exe`.

### HDLCUnframer

Implemente o módulo [mkHDLCUnframer](HDLCUnframer.bsv), que deve receber como entrada um bit pertencente a uma sequência enquadrada por [HDLC com *bit stuffing*](https://en.wikipedia.org/wiki/High-Level_Data_Link_Control#Synchronous_framing), desserializá-lo e produzir como saída tuplas contendo uma flag booleana de começo de quadro e um byte. Isso é quase a operação inversa do que está implementado no [HDLCFramer](HDLCFramer.bsv). A diferença é que a flag booleana no HDLCFramer é uma flag de fim de quadro, em vez de começo de quadro. O motivo é que a lógica fica mais simples desta forma.

O módulo vai ficar recebendo repetidamente a sequência de flag (`1111110`) enquanto a entrada estiver ociosa, condição na qual não deve produzir nenhuma saída. Quando receber um byte completo que não contiver essa sequência, significa que um quadro iniciou. Neste caso, o módulo deve produzir como saída uma tupla contendo `True` (indicando início de quadro) e o byte recebido (primeiro byte do quadro). A partir daí, a cada novo byte recebido, o módulo deve produzir como saída uma tupla contendo `False` e o byte recebido. Se receber novamente a sequência de flag, significa que o quadro terminou e, nesse caso, deve voltar a ficar sem produzir saída.

Sempre que receber a sequência `111110`, o 0 recebido logo depois dos cinco 1s não deve ser incluído no byte de saída, uma vez que esse zero foi inserido apenas com o propósito de impedir que o conteúdo do quadro fosse confundido com uma flag.

É possível implementar o código deste módulo de maneira bastante simples e concisa. Para isso, a dica é fazer uso bastante liberal de **variáveis** dentro do método `put`, gravando novos valores nos registradores apenas no final do método.

Teste seu código com `make TestHDLC.exe && ./TestHDLC.exe`.

### DPLL

No módulo [mkThreeLevelIO](ThreeLevelIO.bsv), implemente um DPLL (*digital phase-locked loop*) quando `sync_to_line_clock` estiver ativado.

Veja que no código original, o valor do registrador `counter_reset_value` é sempre `counter_max_value`. O DPLL deve fazer ajustes suaves nesse valor, alternando-o entre `counter_max_value - 1`, `counter_max_value` e `counter_max_value + 1` a fim de acompanhar o clock da outra ponta do enlace.

Para saber como ajustar o valor de `counter_reset_value`, vamos esperar uma borda de subida do sinal de entrada, que aqui definimos como o início de um pulso, seja este positivo ou negativo (em outras palavras, o momento em que o sinal em nível zero alterna para positivo ou para negativo). Vamos medir o valor de `counter` nesse instante e verificar se ele é igual ao valor esperado, caso no qual usaremos `counter_max_value` como próximo valor de `counter_reset_value`. Já se `counter` for menor que o esperado, precisamos alongar um pouco o período do próximo ciclo, usando `counter_max_value + 1` como próximo valor de `counter_reset_value`. E se `counter` for maior que o esperado, encurtamos um pouco o período do próximo ciclo, usando `counter_max_value - 1`.

O valor de `counter` começa em `counter_reset_value` e vai decrementando. Como mostra a figura abaixo, se definirmos como `counter == 0` o instante ótimo para amostrar o sinal de entrada (caindo exatamente na metade do pulso), o instante esperado para acontecer a borda de subida é quando `counter == counter_reset_value / 4` (ou, calculado de forma mais eficiente, `counter == counter_reset_value >> 2`).

![](fig/dpll.svg)

Teste seu código com `make TestDPLL.exe && ./TestDPLL.exe`.

## Teste de bancada

Conecte à USB do seu computador um Cisco 1921 que tenha um módulo VWIC2-1MFT-T1/E1 instalado. Plugue a sua [interface E1 implementada em FPGA](https://github.com/thotypous/telecom-p2-board) nesse módulo do Cisco.

Conecte-se ao console do Cisco executando: `picocom -b 9600 /dev/ttyACM0`.

Verifique se o Cisco está configurado corretamente, executando `enable` e, em seguida, `show running-config`. Se necessário, entre no modo de configuração com `conf ter` e configure da forma a seguir:

```
controller E1 0/0/0
 framing NO-CRC4
 channel-group 0 timeslots 1-31

interface Serial0/0/0:0
 ip address 192.168.0.1 255.255.255.0
 loopback local
 no keepalive
 no cdp enable

ip route 0.0.0.0 0.0.0.0 192.168.0.2

end
```

Execute um ping direcionado a qualquer endereço, por exemplo `ping 1.1.1.1`, e verifique se as respostas são recebidas.

Se você tiver implementado o DPLL, tente usar o Cisco como fonte de relógio, mudando a seguinte configuração:

```
controller E1 0/0/0
 clock source internal
end
```

E verifique se o ping continua funcionando.

## Depuração via UART

A placa Tang Nano 9k dispõe de um adaptador USB UART que pode ser bastante útil para depurar sua lógica caso ocorra algum problema nos testes de bancada.

Para enviar um byte `octet` para a UART e recebê-lo no computador pela USB, chame `fifo_uart.enq(octet)` no ponto desejado do arquivo [Top.bsv](Top.bsv).

Note, no entanto, que o adaptador USB UART da Tang Nano 9k é um FTDI emulado que é um pouco bugado. Para funcionar corretamente, um truque que parece dar certo sempre é, antes de carregar o bitfile na placa (ou seja, antes de fazer `make load`), usar o procedimento a seguir para abrir o GNU screen, fechá-lo, e abrir o picocom em seguida:

1. Execute `screen /dev/ttyUSB1 3000000,cs8,-parenb,cstopb`.

2. Feche o GNU screen digitando `Ctrl+a`, seguido da teclada `k`, seguido da tecla `y`.

3. Por fim, execute o picocom e mantenha-o executando durante os seus testes: `picocom -b 3000000 -d 8 -p 1 -y n /dev/ttyUSB1`.

4. Se você desejar, é possível ler os dados recebidos da UART em formato hexadecimal, o que é útil se eles forem dados binários. Para isso, feche o picocom com `Ctrl+a` seguido de `Ctrl+x`, e execute `hexdump -C /dev/ttyUSB1`.
