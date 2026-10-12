# opencode-update

> Atualiza (ou instala) o **opencode** no Windows via **Scoop** em um único comando — com backup automático e preservação dos seus modelos configurados.

![Release](https://img.shields.io/github/v/release/canalqb/opencode-update?style=flat-square)
![CI](https://img.shields.io/github/actions/workflow/status/canalqb/opencode-update/ci.yml?branch=main&style=flat-square)
![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)
![Platform](https://img.shields.io/badge/platform-Windows-blue?style=flat-square)

## Por que este projeto existe

O opencode tem um update nativo dentro do app — mas, quando ele é instalado via **Scoop**, esse update nativo **falha com erro**: quem gerencia o binário é o Scoop, e o opencode não tem permissão para substituir a si mesmo. O caminho correto é atualizar pelo Scoop.

Este repositório automatiza esse caminho completo, e resolve o segundo problema que ninguém comenta: **o medo de perder seus modelos gratuitos configurados** no `opencode.jsonc` (provider custom, baseURL, chaves de API). O updater faz backup antes, verifica depois e restaura sozinho se algo sumir.

**Testado em 12/10/2026:** atualização `1.18.31 -> 1.19.0` em ~16 segundos, download de 59,3 MB, **26/26 modelos preservados**.

## Instalação — um comando

Abra o **PowerShell** e execute:

```powershell
irm https://github.com/canalqb/opencode-update/releases/latest/download/install.ps1 | iex
```

O instalador faz tudo sozinho:

1. instala o **Scoop** (se ainda não existir);
2. instala o **opencode** na versão mais recente (se ainda não existir);
3. instala o `opencode-update` em `%LOCALAPPDATA%\Programs\opencode-update`;
4. adiciona a pasta ao **PATH** do usuário — o comando `opencode-update` fica disponível em janelas novas do PowerShell;
5. mostra o próximo passo: fechar o opencode e rodar `opencode-update`.

O instalador é **não-interativo** (não pergunta nada). Para já atualizar no final da instalação, salve o script e execute com `-Run`.

### Alternativa manual (sem one-liner)

```powershell
iwr https://github.com/canalqb/opencode-update/releases/latest/download/opencode-update.zip -OutFile opencode-update.zip
Expand-Archive opencode-update.zip -DestinationPath opencode-update
Set-Location opencode-update
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

### Auditoria antes de executar (recomendado)

Nunca execute `| iex` de fontes que você não conhece. Audite primeiro:

```powershell
irm https://github.com/canalqb/opencode-update/releases/latest/download/install.ps1 -OutFile install.ps1
notepad install.ps1   # leia o código, depois execute:
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

## Como usar depois de instalado

Abra um **novo** PowerShell (para o PATH valer) e:

```powershell
opencode-update
```

### Opções

| Comando | O que faz |
|---|---|
| `opencode-update` | Atualiza o opencode com backup e verificação de modelos. |
| `opencode-update -Check` | Só relata o estado: versão, scoop, nº de modelos — **sem mudar nada**. |
| `opencode-update -KillRunning` | Pede confirmação, fecha as sessões do opencode em execução e atualiza. |
| `opencode-update -?` | Mostra a ajuda do PowerShell (parâmetros). |

Se o opencode estiver aberto, o updater **aborta com segurança** em vez de matar suas sessões — essa é uma feature, não um bug. Feche o opencode e rode de novo, ou use `-KillRunning`.

## O que o updater faz, passo a passo

1. **Pré-voo** — confere Scoop no PATH e se o opencode está em execução.
2. **Backup** — copia `opencode.jsonc` (+ `auth.json` e `opencode.json` se existirem) para `opencode_backups\<timestamp>\` com um `backup_info.txt` (versão, hash SHA-256 e contagem de modelos).
3. **Scoop update** — atualiza o próprio Scoop e os buckets (best-effort, falha não bloqueia).
4. **opencode update** — `scoop update opencode` para a versão mais recente.
5. **Verificação de modelos** — compara hash e contagem de modelos antes/depois. Se qualquer modelo sumir, **restaura o backup automaticamente**.
6. **Log** — tudo em `opencode_update.log`, com resultado `SUCCESS` ou `FAILED`.

Os modelos novos do catálogo (models.dev) carregam junto com a versão nova — seus modelos custom antigos permanecem no config. Resultado: **antigos + novos unidos**.

## Requisitos

- Windows 10/11 (x64)
- Windows PowerShell 5.1 (já vem no Windows) ou PowerShell 7+
- Conexão com a internet (GitHub + buckets do Scoop)

## Backup e restauração manual

Cada execução cria `opencode_backups\<timestamp>\`. Para restaurar manualmente:

```powershell
Copy-Item "$env:USERPROFILE\.config\opencode" "$env:USERPROFILE\.config\opencode.old" -Recurse -Force
Copy-Item .\opencode_backups\20261012_050757\opencode.jsonc "$env:USERPROFILE\.config\opencode\opencode.jsonc" -Force
```

## Desinstalação

```powershell
powershell -File "$env:LOCALAPPDATA\Programs\opencode-update\uninstall.ps1"
```

Remove a ferramenta e a entrada do PATH. **Não** desinstala o opencode nem o Scoop.

## Nota importante: opencode v2

O Scoop também oferece o **opencode v2** (`versions/opencode2`). A configuração do v2 **é incompatível** com a do v1 — este projeto atualiza o pacote `opencode` (v1), que é o instalado na maioria das máquinas. Migração para v2 é uma decisão manual: veja as instruções oficiais em <https://opencode.ai/v2/docs/migrate-v1/>.

## FAQ

**O update nativo do opencode dá erro. É isso que resolve?**
Sim. Instalações via Scoop não conseguem se auto-atualizar (o binário é gerenciado pelo Scoop). Este script usa o caminho correto: `scoop update opencode`.

**Meus modelos/chaves do `opencode.jsonc` podem ser perdidos?**
O update via Scoop não toca no seu config — mas o script faz backup e verifica assim mesmo. Se a contagem de modelos cair, ele restaura o backup sozinho.

**Funciona no PowerShell 7?**
Sim, testado nas duas engines (CI valida sintaxe no Windows PowerShell 5.1 e no PowerShell 7).

**Preciso rodar como Administrador?**
Não. Scoop, opencode e esta ferramenta são 100% por usuário, sem elevação.

## Estrutura das releases

- **Repositório** — código-fonte, README, installer e updater (arquivos pequenos, legíveis).
- **Release** — bundle `opencode-update.zip` (todos os scripts + README + LICENSE) e o `install.ps1` usado pelo one-liner. A URL `releases/latest/download/...` aponta sempre para a release mais nova.

## Licença

[MIT](LICENSE) — CanalQb. Use, modifique e compartilhe.

- Blog: <https://canalqb.com.br/>
- YouTube: <https://www.youtube.com/channel/UCdOA_1KzXHIp3gmVyyYv2sg>
- Repositório: <https://github.com/canalqb/opencode-update>
