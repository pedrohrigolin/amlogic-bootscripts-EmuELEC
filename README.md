# Scripts de Boot do Amlogic para EmuELEC

**Language / Idioma:** [🟢 Português](README.md) | [English](README.en.md)

## Índice
- [Visão Geral](#visão-geral)
- [Configuração](#configuração)
- [Personalização do `aml_autoscript`](#personalização-do-aml_autoscript)
- [Dispositivos Suportados](#dispositivos-suportados)
- [Solução de Problemas — Executando o `aml_autoscript` Manualmente](#solução-de-problemas--executando-o-aml_autoscript-manualmente)
- [Como Funciona Internamente](#como-funciona-internamente)

---

## Visão Geral

Este projeto é uma **fusão dos scripts do [amlogic-bootscripts-Armbian](https://github.com/projetotvbox/amlogic-bootscripts-Armbian) com o script de boot do EmuELEC**. Ele dá boot em EmuELEC a partir de um pendrive, usando o u-boot de fábrica da box, e traz junto o que os scripts do Armbian oferecem, como o bootlogo do u-boot e o boot de Linux mainline que usa autoscripts. Também deve funcionar com derivados do CoreELEC, mas **só foi testado em EmuELEC**.

O código é derivado do trabalho do devmfc, das alterações deste projeto e do código original do EmuELEC.

**Por que ele existe**

O script de boot original do EmuELEC começa com `defenv`, que reseta todas as variáveis do u-boot para o padrão de fábrica. Isso apaga as variáveis `start_autoscript`, `start_mmc_autoscript`, `start_usb_autoscript` e `start_emmc_autoscript`, justamente as que um Linux mainline instalado (como o Armbian) usa para ser encontrado pelo bootloader.

O resultado: **mesmo sem instalar o EmuELEC, apenas bootando pelo pendrive para testar**, a box perde a capacidade de iniciar o Linux mainline que está na eMMC. Ele continua fisicamente lá, mas o bootloader não sabe mais como encontrá-lo.

Os scripts deste projeto são uma customização do bootscript do EmuELEC que, depois do `defenv`, recria essas variáveis. Assim o EmuELEC inicia normalmente e o mainline continua funcionando.

**Diferenças em relação ao projeto do Armbian**

| | Armbian | EmuELEC |
|---|---|---|
| Sistema que inicializa | Armbian (mainline) | EmuELEC |
| `cvbs_boot` | `0` (desabilitado) | `1` (habilitado) |
| Funcionamento | Escreve a rota de boot e inicia o Armbian | Roda **uma única vez**; os três scripts são **aliases** (veja [Como Funciona Internamente](#como-funciona-internamente)) |

> **Pré-requisito:** o u-boot do fabricante deve estar rodando na eMMC. Se sua box foi reflashada com outro bootloader, restaure a imagem Android original com a ferramenta [Amlogic USB Burning Tool](https://androidmtk.com/download-amlogic-usb-burning-tool) antes de continuar.

> ⚠️ **O Android deixa de iniciar pela eMMC.** Assim como no projeto do Armbian, o script remove as variáveis do Android do u-boot, incluindo `storeboot`. Para voltar ao Android, restaure a imagem original com o Amlogic USB Burning Tool.

---

## Configuração

### Passo 1 — Baixe a imagem do EmuELEC

Baixe a imagem do EmuELEC para a sua box na [página de releases](https://github.com/EmuELEC/EmuELEC/releases). Os scripts foram testados na versão 4.8, mas provavelmente funcionam em qualquer versão.

---

### Passo 2 — Prepare a mídia de instalação

Grave a imagem no pendrive usando o **[balenaEtcher](https://etcher.balena.io/)** — a opção mais simples — ou via linha de comando:

```bash
sudo dd if=EmuELEC_*.img of=/dev/sdX bs=4M status=progress conv=fsync
```

> ⚠️ Substitua `/dev/sdX` pelo seu pendrive. Use `lsblk` ou `fdisk -l` para confirmar o dispositivo correto. Com `dd`, gravar no dispositivo errado apaga os dados sem confirmação.

Monte a partição `EMUELEC` do pendrive (FAT32, geralmente a primeira) e copie os três scripts, sobrescrevendo os existentes:

- **[aml_autoscript](https://github.com/projetotvbox/amlogic-bootscripts-EmuELEC/blob/main/aml_autoscript)**
- **[s905_autoscript](https://github.com/projetotvbox/amlogic-bootscripts-EmuELEC/blob/main/s905_autoscript)**
- **[emmc_autoscript](https://github.com/projetotvbox/amlogic-bootscripts-EmuELEC/blob/main/emmc_autoscript)**

> Os três arquivos são **idênticos**, com nomes diferentes. Você precisa copiar os três: cada nome cobre uma situação diferente do u-boot da box (veja [Como Funciona Internamente](#como-funciona-internamente)).

```bash
git clone https://github.com/projetotvbox/amlogic-bootscripts-EmuELEC.git

# Ajuste /dev/sdX1 conforme necessário (use lsblk para achar a partição EMUELEC)
sudo mount /dev/sdX1 /mnt/emuelec

sudo cp amlogic-bootscripts-EmuELEC/aml_autoscript /mnt/emuelec/
sudo cp amlogic-bootscripts-EmuELEC/s905_autoscript /mnt/emuelec/
sudo cp amlogic-bootscripts-EmuELEC/emmc_autoscript /mnt/emuelec/

sudo umount /mnt/emuelec
```

> **Preparando múltiplos pendrives ou distribuindo imagens próprias?** É possível modificar a imagem `.img` diretamente antes de gravar, com `losetup`:
>
> ```bash
> sudo losetup -fP EmuELEC_*.img
> lsblk | grep loop          # identifique a partição FAT32 (geralmente loop0p1)
> sudo mkdir -p /mnt/emuelec
> sudo mount /dev/loop0p1 /mnt/emuelec
> ```
>
> Copie os três scripts normalmente para `/mnt/emuelec/` e, só ao final, desmonte e grave:
>
> ```bash
> sudo umount /mnt/emuelec
> sudo losetup -d /dev/loop0
> sudo dd if=EmuELEC_*.img of=/dev/sdX bs=4M status=progress conv=fsync
> ```

---

### Passo 3 — Inicialize pelo pendrive

1. Desligue a box.
2. Insira o pendrive USB.
3. Ligue a box. Dependendo do u-boot que ela tem hoje, o script é encontrado de um jeito diferente:
   - **Box com u-boot de fábrica:** pressione e **mantenha pressionado** o botão reset, ligue a box e continue segurando por aproximadamente **7 segundos**. Isso executa o `aml_autoscript`.
   - **Box que já tem Linux mainline com autoscripts:** não precisa do reset. O u-boot já procura o `s905_autoscript` (no pendrive ou SD) e o `emmc_autoscript` (na eMMC), e o script roda sozinho.
4. O script grava as variáveis (`saveenv`) e já inicia o EmuELEC.

> Se a box não iniciar o EmuELEC automaticamente, tente com o botão reset pressionado: alguns firmwares exigem isso para dar boot por USB. Se o reset não surtir efeito, veja [Solução de Problemas](#solução-de-problemas--executando-o-aml_autoscript-manualmente).

---

### Passo 4 — Próximos boots

O script **roda uma única vez**: o EmuELEC não usa autoscripts para iniciar. Depois que as variáveis ficam gravadas, o `bootcmd` salvo no u-boot carrega o EmuELEC antes de qualquer autoscript, sem reset e sem precisar dos scripts:

- **Com o pendrive EmuELEC conectado:** a box inicia o EmuELEC.
- **Sem o pendrive:** a box tenta o EmuELEC no SD e na eMMC e, se não encontrar, segue para o `start_autoscript`, que procura um Linux mainline (como o Armbian) em SD, USB e eMMC. É por isso que o mainline da eMMC volta a iniciar normalmente ao remover o pendrive.

> O Linux mainline continua protegido, desde que nada seja gravado no lugar dele na eMMC.

---

## Personalização do `aml_autoscript`

O `aml_autoscript` deste projeto é derivado do código do devmfc, das alterações deste projeto e do código original do EmuELEC. Assim como o do projeto do Armbian, ele remove dezenas de variáveis que só existem para o Android (recovery, burning, Dolby Vision, A/B slots etc.) e mantém o ambiente do u-boot limpo, facilitando o debug e a compreensão do código. Se quiser continuar usando o Android, use os autoscripts originais do **devmfc**.

O código-fonte editável é o `aml_autoscript.command`. Os arquivos `aml_autoscript`, `s905_autoscript` e `emmc_autoscript` (sem extensão) são a versão compilada, a que vai para a partição `EMUELEC`.

> **Qualquer alteração só tem efeito depois de recompilar o script e executá-lo novamente na box** (segurando o reset, ou manualmente via console serial — veja a seção de solução de problemas). As variáveis só são gravadas pelo `saveenv` durante a execução.

> ⚠️ **Como os três arquivos são aliases, toda alteração precisa ser aplicada nos três.** Compile uma vez e gere os outros dois como cópia (veja abaixo).

### Fluxo para testar suas alterações

1. Edite o `aml_autoscript.command`.
2. [Recompile o script](#recompilando-o-script) e gere os três arquivos.
3. Copie os três para a raiz da partição `EMUELEC` do pendrive.
4. Execute-o na box, de uma das duas formas:
   - **Botão reset**, como no [Passo 3](#passo-3--inicialize-pelo-pendrive). Na primeira vez isso funciona com o u-boot de fábrica; nas seguintes, só funciona se você tiver [reativado o botão](#reutilizando-outro-aml_autoscript).
   - **Manualmente, pelo console serial**, como em [Executando o `aml_autoscript` Manualmente](#solução-de-problemas--executando-o-aml_autoscript-manualmente).

> 💡 **Dica:** enquanto estiver criando ou ajustando um `aml_autoscript` customizado, **mantenha o botão reset habilitado**. Assim você pode testar sem precisar do console serial a cada tentativa. Só quando tiver a versão final, e se quiser, desabilite o botão.

---

### Recompilando o script

```bash
sudo apt install u-boot-tools   # fornece o mkimage (Debian/Ubuntu)
mkimage -C none -A arm -T script -d aml_autoscript.command aml_autoscript

# Os três arquivos são idênticos: gere os aliases como cópia
cp aml_autoscript s905_autoscript
cp aml_autoscript emmc_autoscript
```

Copie os três arquivos gerados para a partição `EMUELEC`, sobrescrevendo os existentes.

---

### Reutilizando outro `aml_autoscript`

Por padrão, essa funcionalidade vem **desabilitada**: o u-boot não procura mais um novo `aml_autoscript` ao ligar, o que mantém o boot mais simples e previsível.

> 💡 **Se você vai customizar o `aml_autoscript`, ative esta opção desde a primeira versão customizada** e só a desabilite quando tiver a versão final. Para desabilitar de volta, recompile com essas linhas comentadas e com a linha `setenv update` ativa (o padrão do repositório).

Para reativá-la, edite o `aml_autoscript.command`: **descomente** as quatro linhas do bloco indicado e **comente** a linha `setenv update` que fica logo abaixo dele.

```bash
# Descomente estas linhas:
setenv check_update_button ${upgrade_key}
setenv update 'run load_aml_autoscript'
setenv load_aml_autoscript 'if mmcinfo; then if fatload mmc 0 1020000 aml_autoscript; then autoscr 1020000; fi; fi; if usb start; then for usbdev in 0 1 2 3; do if fatload usb ${usbdev} 1020000 aml_autoscript; then autoscr 1020000; fi; done; fi'
setenv bootcmd 'run check_update_button; if test ${bootfromnand} = 1; then setenv bootfromnand 0; saveenv; else run bootfromsd; run bootfromusb; run bootfromemmc; fi; run start_autoscript'

# E comente esta (mais abaixo no arquivo):
#setenv update
```

Com isso, o `bootcmd` volta a verificar o botão de reset e o `load_aml_autoscript` procura um `aml_autoscript` no SD e no USB. Recompile e execute o script para aplicar.

---

### Bootlogo do U-Boot no EmuELEC

O `aml_autoscript` injeta uma função de bootlogo no U-Boot, algo que normalmente só o Android oferece. O logo aparece assim que a box liga, antes do kernel carregar.

Tudo que você precisa fazer é colocar um arquivo chamado **`bootlogo.bmp`** na **partição 1 (a partição `EMUELEC`, FAT)** da mídia. O U-Boot procura o arquivo nesta ordem e usa o primeiro que encontrar:

1. Pendrive USB (portas 0 a 3)
2. Cartão SD
3. eMMC

Se nenhum arquivo for encontrado, a box simplesmente inicia sem logo. Para usar outro nome, altere a variável `bootlogo_filename` no `aml_autoscript.command` (sem a extensão `.bmp`) e recompile.

**Formato aceito**

O U-Boot da box só exibe BMPs em um formato específico. Na maioria dos casos é este (RGB565, 16 bits):

```bash
file bootlogo.bmp
# bootlogo.bmp: PC bitmap, Windows 3.x format, 320 x 388 x 16, 3 compression, image size 248320, cbSize 248386, bits offset 66
```

**Convertendo um PNG ou JPEG para o formato correto**

```bash
ffmpeg -i bootlogo.png -pix_fmt rgb565 -compression_level 0 bootlogo.bmp
```

> ⚠️ **Este formato é o mais comum, não um padrão garantido.** Cada U-Boot pode ter suas particularidades (resolução, profundidade de cor etc.). Se o logo não aparecer ou aparecer distorcido, você precisará adaptar a conversão ao seu caso — não há uma solução única que cubra todas as boxes.

---

### Exibindo o bootlogo na saída CVBS

Diferente do projeto do Armbian, aqui a saída CVBS já vem **habilitada** (`cvbs_boot` em `1`). Se a box estiver configurada para saída CVBS e tiver esse hardware, o bootlogo aparece nela. Para desabilitar:

1. No `aml_autoscript.command`, altere:
   ```bash
   setenv cvbs_boot 1
   ```
   para:
   ```bash
   setenv cvbs_boot 0
   ```
2. [Recompile o script](#recompilando-o-script) e gere os três arquivos.
3. Copie os arquivos para a partição `EMUELEC` e execute o script novamente na box.

> ⚠️ **Padrão de vídeo do CVBS.** O `aml_autoscript` vem com o modo definido como `480cvbs` (525 linhas / 60 Hz), o formato aceito no Brasil e nos Estados Unidos:
>
> ```bash
> setenv cvbsmode 480cvbs
> ```
>
> Se a sua TV usar um padrão de 625 linhas / 50 Hz (comum na Europa, por exemplo), altere para `576cvbs`, recompile e execute o script novamente:
>
> ```bash
> setenv cvbsmode 576cvbs
> ```

---

### Cor de fundo antes do bootlogo (tela azul ou verde)

Dependendo do firmware, algumas boxes mostram uma cor de fundo entre a inicialização do vídeo e a exibição do logo, enquanto o U-Boot procura o `bootlogo.bmp`. Nos testes, o padrão (Option A) funcionou bem na **HTV H8** e na **ATV A5**. Já a **BTV B9** mostrou tela **verde** com o padrão e precisou de outra variante. E essa variante da B9, quando usada na A5, fez aparecer uma tela **azul**: o que resolve uma box pode piorar outra.

O `aml_autoscript.command` traz quatro variações do `init_display` (opções **A**, **B**, **C** e **D**). Todas continuam executando `osd open; osd clear` antes de exibir o logo (dentro do `logo_show`). A diferença é abrir e limpar o OSD **também** antes e/ou depois do `vout`:

| Opção | Quando o OSD é aberto e limpo |
|-------|-------------------------------|
| A *(padrão)* | Somente no `logo_show` |
| B | Antes do `vout` |
| C | Depois do `vout` |
| D | Antes e depois do `vout` |

> ⚠️ **Isto foi descoberto por testes empíricos, não pela análise do código dos U-Boots.** O comportamento depende do firmware de cada box: o que resolve em uma pode não mudar nada em outra. Não há uma opção que funcione em todas.

Uma hipótese (não confirmada) é que o `osd clear` apenas zera o framebuffer do OSD, deixando-o transparente em vez de preto, e a cor que você vê é o fundo do pipeline de vídeo, definido pelo U-Boot do fabricante. Por isso nenhum comando de OSD resolve de forma portável.

**Como escolher a opção para a sua box**

1. Comece pela **Option A**, que é a padrão.
2. Se a cor de fundo incomodar, teste **B** e depois **C**.
3. A **D** só vale a pena se nenhuma das duas resolver, ou se o resultado variar entre boots.
4. Se uma opção não melhorar nada, volte para a A.

Para trocar, edite o `aml_autoscript.command`, deixe **somente uma** opção descomentada, [recompile](#recompilando-o-script) e execute o script novamente.

**Testando uma opção antes de adotá-la**

Digitar comandos longos direto no prompt do U-Boot tende a dar erro. Em vez disso, crie um autoscript de teste, por exemplo `test_autoscript.command`, com o `init_display` que você quer experimentar:

```bash
setenv init_display '<conteúdo da opção escolhida>'
run init_display
```

[Compile](#recompilando-o-script) o script (`mkimage -C none -A arm -T script -d test_autoscript.command test_autoscript`), copie o `test_autoscript` para a raiz do pendrive e execute de uma das duas formas:

- **Manualmente, pelo console serial** (veja [Executando o `aml_autoscript` Manualmente](#solução-de-problemas--executando-o-aml_autoscript-manualmente)), trocando o nome do arquivo:
  ```bash
  usb start
  fatload usb 0 $loadaddr test_autoscript
  autoscr $loadaddr
  ```
- **Pelo botão reset:** o botão carrega um arquivo chamado `aml_autoscript`, então nesse caso o arquivo compilado deve ter esse nome, e o botão precisa estar habilitado (veja [Reutilizando outro `aml_autoscript`](#reutilizando-outro-aml_autoscript)).

Esse teste filtra opções ruins, mas não prova que a opção é segura no `preboot`, que pode se comportar de forma diferente de um script executado depois do boot do U-Boot.

---

## Dispositivos Suportados

**✅ Testado e Funcionando:**
- S905X4 (HTV H8), S905X3, com EmuELEC 4.8

**❓ Não Testado:**
- Demais SoCs Amlogic, outras versões do EmuELEC (provavelmente compatíveis) e derivados do CoreELEC

**Linux mainline preservado:** Armbian (qualquer versão com bootscripts compatíveis).

Todos os arquivos e fontes estão disponíveis no [Github](https://github.com/projetotvbox/amlogic-bootscripts-EmuELEC).

---

## Solução de Problemas — Executando o `aml_autoscript` Manualmente

> ⚠️ **Esta seção é para o caso em que segurar o botão reset não executa o `aml_autoscript`.** Se o método principal funcionou, você não precisa disso.
>
> Não é mais necessário digitar variáveis do U-Boot à mão: o `aml_autoscript` já faz toda a configuração. A única coisa que resta é executá-lo manualmente, interrompendo o U-Boot pelo console serial.

### Pré-requisitos

- **Adaptador Serial TTL (3.3V UART):** ⚠️ **Use apenas 3.3V. 5V danificará o dispositivo.** Requer solda nos pads TX/RX/GND da placa.
- **Software de terminal serial:** PuTTY, Minicom ou picocom.
- **Um pendrive formatado em FAT32** com o arquivo `aml_autoscript` na raiz.

### 🔒 Faça Backup da eMMC Antes de Qualquer Coisa

O `aml_autoscript` apaga o ambiente de fábrica do U-Boot (`defenv`) e remove as variáveis do Android. Se houver qualquer chance de você querer voltar atrás, faça o backup antes (com um sistema ARM Linux rodando pelo pendrive):

```bash
# Backup com compressão (um backup de 16GB vira 2-4GB)
sudo dd if=/dev/mmcblkX bs=1M status=progress | gzip -c > backup_emmc_full.img.gz

# Para restaurar:
# gunzip -c backup_emmc_full.img.gz | sudo dd of=/dev/mmcblkX bs=1M status=progress
```

### Passo 1 — Conectar o cabo serial

Solde TX, RX e GND nos pads UART do dispositivo e conecte ao PC.

### Passo 2 — Abrir o console serial

```bash
ls -la /dev/ttyUSB*

picocom -b 115200 /dev/ttyUSB0
# ou:
minicom -D /dev/ttyUSB0 -b 115200
```

### Passo 3 — Interromper o U-Boot

Com o pendrive conectado, ligue o dispositivo e pressione rapidamente `Ctrl+C` ou `Enter` para interromper o U-Boot antes de ele inicializar.

### Passo 4 — Executar o `aml_autoscript`

No console do U-Boot, execute:

```bash
usb start
fatload usb 0 $loadaddr aml_autoscript
autoscr $loadaddr
```

> ⚠️ **Mantenha apenas 1 pendrive conectado** durante este procedimento. O comando acima lê o primeiro dispositivo USB (`0`).

O script reescreve as variáveis, executa o `saveenv` e em seguida tenta iniciar o EmuELEC. Se não encontrar um, segue para o `start_autoscript` (Linux mainline). Nas próximas vezes, não será mais necessário usar o console serial nem o botão reset.

---

## Como Funciona Internamente

Para quem quer entender o que acontece por baixo dos panos.

### Os três arquivos são aliases

No conceito original dos autoscripts, como no projeto do Armbian, esses três arquivos **não** são iguais: o `aml_autoscript` instala a nova rota de boot uma vez, o `s905_autoscript` carrega o sistema do pendrive ou SD e o `emmc_autoscript` carrega o da eMMC.

**No EmuELEC isso muda**, porque ele não usa autoscripts para iniciar o sistema. Por isso `aml_autoscript`, `s905_autoscript` e `emmc_autoscript` são aqui **o mesmo arquivo**, com nomes diferentes: são aliases. Cada nome existe só para que o script seja encontrado, já que um u-boot diferente procura um nome diferente:

- **`aml_autoscript`** — carregado pelo u-boot de fábrica quando você segura o botão reset ao ligar a box.
- **`s905_autoscript`** — procurado no pendrive e no SD por um u-boot que já foi customizado para dar boot em mainline com autoscripts.
- **`emmc_autoscript`** — procurado na eMMC por esse mesmo tipo de u-boot.

Assim o script roda independentemente do u-boot que a box tem hoje. Como o script roda uma única vez e grava as variáveis, depois disso o `bootcmd` carrega o EmuELEC antes de qualquer autoscript. Como são cópias, **qualquer alteração precisa ser feita nos três**.

### O que o script faz

Executado **uma única vez**. Como as variáveis são gravadas com `saveenv`, o resultado persiste nos boots seguintes. Em ordem, ele:

1. **Restaura o ambiente de fábrica** (`defenv`, `env default -a` e `saveenv`), partindo de uma base limpa. É esse o passo que, no script original do EmuELEC, apagava as variáveis do mainline.
2. **Define as variáveis do EmuELEC**: `cfgloadsd`, `cfgloadusb` e `cfgloademmc` procuram o arquivo `cfgload` no SD, no USB e nas partições da eMMC; `bootfromsd`, `bootfromusb` e `bootfromemmc` carregam o `kernel.img` e o `dtb.img` (com fallback para o dtb da própria box via `store dtb read`) e iniciam com `bootm`.
3. **Recria a rota de boot do Linux mainline** (`start_autoscript`): SD card → USB → eMMC, procurando o `s905_autoscript` e o `emmc_autoscript` do Armbian. **Esta é a correção** que impede o EmuELEC de deixar a box sem conseguir iniciar o mainline.
4. **Define o `bootcmd`**: tenta o EmuELEC (SD → USB → eMMC) e, se nenhum iniciar, segue para o `start_autoscript`, ou seja, para o Linux mainline.
5. **Configura o bootlogo e a saída de vídeo** (`init_display`, executado no `preboot`): escolhe o modo de saída (HDMI ou CVBS), procura o `bootlogo.bmp` no USB, SD e eMMC, e o exibe. A posição do `osd open; osd clear` em relação ao `vout` pode ser ajustada em quatro variantes (A a D), explicadas em [Cor de fundo antes do bootlogo](#cor-de-fundo-antes-do-bootlogo-tela-azul-ou-verde).
6. **Remove as variáveis do Android** (recovery, burning, Dolby Vision, rede, A/B slots etc.), mantendo o ambiente enxuto.
7. **Grava tudo** com `saveenv` e já inicia o boot na hora, rodando as mesmas rotinas do `bootcmd`.

---

Feito com 🐧 no IFSP Salto · Tecnologia a serviço da educação pública
