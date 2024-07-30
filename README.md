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

Para sintetizar e executar todos os testes, execute `./run-grader`.

## Implementação

As partes do código que estão faltando são descritas a seguir. Elas são independentes e não precisam ser implementadas em nenhuma ordem particular. No entanto, eu recomendo deixar a DPLL por último, pois é possível realizar um teste de bancada parcial mesmo se ela não estiver implementada.

### HDB3Decoder

TODO

### E1Unframer

TODO

### HDLCUnframer

TODO

### DPLL

TODO

## Teste de bacada

Conecte à USB do seu computador um Cisco 1921 que tenha um módulo VWIC2-1MFT-T1/E1 instalado. Plugue a sua interface E1 implementada em FPGA nesse módulo do Cisco.

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

Se você tiver implementado a DPLL, tente usar o Cisco como origem de relógio, mudando a seguinte configuração:

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

3. Por fim, execute o picocom e mantenha-o executando durante os seus testes: `picocom -b 3000000 -d 8 -p 1 -y n /dev/ttyUSB1`

4. Se você desejar, é possível ler os dados recebidos da UART em formato hexadecimal, o que é útil se eles forem dados binários. Para isso, feche o picocom com `Ctrl+a` seguido de `Ctrl+x`, e execute `hexdump -C /dev/ttyUSB1`.
