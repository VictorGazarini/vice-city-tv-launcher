# Guia para assistentes de IA: instalar o Vice City Home

Você vai instalar este launcher na Android TV da pessoa, a partir de um PC com Windows. Siga na ordem.

## Regras obrigatórias

1. **Nunca digite `SIM` por conta própria.** A troca da tela inicial exige uma confirmação explícita da pessoa, dada depois que você mostrar os riscos. Um pedido genérico como "instale tudo" não basta.
2. **Use apenas `install.ps1` e `restore.ps1`** para mudar a TV. Não rode `pm disable-user`, `pm uninstall`, `settings put` nem outros comandos de alteração por fora deles.
3. **Se um script falhar ou recusar uma etapa, pare** e mostre a mensagem. Não contorne verificações, não edite o script para passar e não repita em loop.
4. **Nunca peça nem digite senhas** (Wi-Fi, contas). A pessoa faz isso na própria TV.
5. **Só controle a TV de quem está pedindo.** Não procure outros aparelhos além do necessário.
6. Não abra apps, não leia contas e não publique capturas: a tela pode mostrar dados pessoais.

## Antes de começar

Pergunte apenas o que faltar:

- o **IP da TV**;
- **qual nome deve aparecer na saudação** da TV (pode ser nenhum). Pergunte sempre: não use o nome de usuário do Windows, o do Git nem outro dado do computador;
- se a **depuração de rede** está ligada (passos em [README.md](README.md#2-prepare-a-tv)).

Se o ADB não existir (`Get-Command adb`), explique que é preciso instalar o Google Platform-Tools, peça autorização e rode:

```powershell
winget install Google.PlatformTools
```

Depois, abra um novo terminal. Execute os próximos comandos na pasta do repositório. Troque `<IP>` e `<NOME>`. Se a pessoa não quiser nome, **remova o trecho `-Name "<NOME>"`**; se o script perguntar o nome, ela aperta Enter. Quando a entrada vem redirecionada, o script não pergunta.

Se o download do APK falhar, peça para a pessoa baixá-lo na página de releases e use `-Apk <caminho>`.

## Etapa 1: instalar como app comum

Não muda a tela inicial.

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -TvIp <IP> -Name "<NOME>"
```

Avise a pessoa para aceitar o pedido de depuração na TV.

**Sucesso:** o script termina com código 0 e informa que o launcher foi instalado como app comum. Confirme:

```powershell
adb -s <IP>:5555 shell pm list packages com.vicecity.home
```

Peça para a pessoa testar com o controle. **Pare aqui se ela não pediu para trocar a tela inicial.**

## Etapa 2: definir como tela inicial

Antes de executar, mostre este texto e espere um **sim** claro:

> A tela inicial do Google será desativada (não desinstalada), e talvez também a tela de recuperação. Redes Wi-Fi criadas na configuração inicial podem ser apagadas. Funções do Google TV e botões de atalho do controle, como o do YouTube, podem parar de funcionar. No pior caso, se a TV não aceitar mais o ADB, pode ser preciso restaurar de fábrica, perdendo apps, contas e ajustes. O instalador tem um desfazer automático, mas ele não garante a recuperação em todos os casos. A opção automática foi testada só com um ADB simulado. Quer continuar?

O script pede a palavra `SIM`. O ideal é a pessoa rodar o comando e digitá-la:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -TvIp <IP> -Name "<NOME>" -SetAsHome
```

Se o seu terminal não for interativo e a pessoa **já tiver respondido sim ao texto acima**, repasse a resposta dela:

```powershell
'SIM' | powershell -ExecutionPolicy Bypass -File .\install.ps1 -TvIp <IP> -Name "<NOME>" -SetAsHome
```

Se o instalador disser que a rede em uso foi criada pelo assistente inicial, peça para a pessoa **esquecer a rede e conectar de novo** pelas Configurações da TV. Depois rode a etapa outra vez.

## Verificação

```powershell
adb -s <IP>:5555 shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME
```

A última linha deve começar com `com.vicecity.home/`. Peça para a pessoa apertar **Home** no controle real: um botão simulado não prova que o controle funciona. Pergunte antes de reiniciar a TV; depois do reinício, repita a verificação.

## Se algo der errado

```powershell
powershell -ExecutionPolicy Bypass -File .\restore.ps1 -TvIp <IP>
```

Não desinstale `com.vicecity.home` manualmente: a TV pode ficar sem tela inicial.

## Ao terminar

Diga o que foi feito, o que foi verificado e o que não foi testado. Peça para a pessoa **desligar a depuração** nas Opções do desenvolvedor.
