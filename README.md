# opencode-update

> Instala **Scoop atualizado** + **opencode na última versão** + **26 modelos gratuitos da NVIDIA configurados** — tudo em um único comando no Windows.

![Release](https://img.shields.io/github/v/release/canalqb/opencode-update?style=flat-square)
![CI](https://img.shields.io/github/actions/workflow/status/canalqb/opencode-update/ci.yml?branch=main&style=flat-square)
![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)
![Platform](https://img.shields.io/badge/platform-Windows-blue?style=flat-square)

## Por que este projeto existe

O opencode tem um update nativo dentro do app — mas, quando ele é instalado via **Scoop**, esse update falha: quem gerencia o binário é o Scoop, e o opencode não pode substituir a si mesmo. O caminho correto é atualizar pelo Scoop. E depois de atualizar, ninguém quer perder os **modelos gratuitos** configurados no `opencode.jsonc`.

Este repositório resolve os dois problemas de uma vez:

1. instala/atualiza Scoop e opencode **sempre na versão mais recente**;
2. configura o `opencode.jsonc` com **26 modelos gratuitos** da API integrate da NVIDIA (GLM, Nemotron, Llama, DeepSeek, Kimi, Qwen, Mistral, Seed OSS);
3. mantém seus modelos intactos a cada update — com backup, verificação pós-update e auto-restauração.

**Validado em 12/10/2026:** atualização `1.18.31 -> 1.19.0` em ~16 segundos (download de 59,3 MB), **26/26 modelos preservados**.

## Instalação — um comando

```powershell
irm https://github.com/canalqb/opencode-update/releases/latest/download/install.ps1 | iex
```

O instalador faz tudo sozinho:

1. instala o **Scoop** se faltar e roda `scoop update` (core + buckets sempre atualizados);
2. instala o **opencode** na versão mais recente — ou atualiza o que já existe;
3. instala o `opencode-update` em `%LOCALAPPDATA%\Programs\opencode-update`;
4. configura os **26 modelos recomendados** no `opencode.jsonc`:
   - sem config → cria a partir do template (`models-template.jsonc`);
   - com config → verifica e, com `-ApplyModels`, adiciona só os que faltam (backup automático antes);
5. adiciona a pasta ao **PATH** do usuário — o comando `opencode-update` fica disponível em janelas novas do PowerShell.

O instalador é **não-interativo por padrão** (não trava esperando resposta).

### Sua chave NVIDIA (gratuita)

Os 26 modelos usam a API integrate da NVIDIA. Você precisa de uma chave **gratuita**:

1. Acesse **<https://build.nvidia.com>**;
2. entre com sua conta NVIDIA;
3. clique em **"Get API Key"** e copie a chave `nvapi-...`.

> **Privacidade:** nenhuma chave fica armazenada neste repositório. A chave é fornecida por quem instala e é escrita apenas no `opencode.jsonc` local da sua máquina.

Como entregar a chave ao instalador (escolha uma):

```powershell
# opção 1: parâmetro (salve o install.ps1 e execute com -File)
powershell -ExecutionPolicy Bypass -File .\install.ps1 -NvidiaApiKey "nvapi-..."

# opção 2: variável de ambiente antes do one-liner
$env:NVIDIA_API_KEY = "nvapi-..."
irm https://github.com/canalqb/opencode-update/releases/latest/download/install.ps1 | iex

# opção 3: prompt — em instalação nova sem chave configurada, o instalador pergunta
# (responder em branco mantém o placeholder para preencher depois no opencode.jsonc)
```

Se a chave ficar com o placeholder, o opencode abre os modelos, mas as chamadas só funcionam depois de você editar o `opencode.jsonc` e substituir `PASTE-YOUR-NVIDIA-API-KEY-HERE`.

### Alternativa manual (sem one-liner)

```powershell
iwr https://github.com/canalqb/opencode-update/releases/latest/download/opencode-update.zip -OutFile opencode-update.zip
Expand-Archive opencode-update.zip -DestinationPath opencode-update
Set-Location opencode-update
powershell -ExecutionPolicy Bypass -File .\install.ps1 -NvidiaApiKey "nvapi-..."
```

### Auditoria antes de executar (recomendado)

Nunca execute `| iex` de fontes que você não conhece. Audite primeiro:

```powershell
irm https://github.com/canalqb/opencode-update/releases/latest/download/install.ps1 -OutFile install.ps1
notepad install.ps1   # leia o código, depois execute:
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

## Os 26 modelos recomendados

| # | Model ID | Nome | Contexto | Reasoning |
|---|---|---|---|---|
| 1 | `z-ai/glm-5.3` | GLM-5.3 (Z.ai) | 262k | sim |
| 2 | `z-ai/glm5.1` | GLM-5.1 (Z.ai) | 131k | sim |
| 3 | `nvidia/llama-3.3-nemotron-super-49b-v1.5` | Nemotron Super 49B v1.5 | 262k | sim |
| 4 | `nvidia/llama-3.1-nemotron-ultra-253b-v1` | Nemotron Ultra 253B | 131k | sim |
| 5 | `nvidia/nemotron-3-super-120b-a12b` | Nemotron 3 Super 120B | 262k | não |
| 6 | `meta/llama-3.3-70b-instruct` | Llama 3.3 70B | 131k | não |
| 7 | `meta/llama-3.1-405b-instruct` | Llama 3.1 405B | 131k | não |
| 8 | `meta/llama-3.1-8b-instruct` | Llama 3.1 8B (fast) | 131k | não |
| 9 | `deepseek-ai/deepseek-v4-pro` | DeepSeek V4 Pro | 1M | sim |
| 10 | `deepseek-ai/deepseek-v4-flash` | DeepSeek V4 Flash (fast) | 1M | não |
| 11 | `deepseek-ai/deepseek-r1` | DeepSeek R1 | 131k | sim |
| 12 | `moonshotai/kimi-k2-instruct` | Kimi K2 | 131k | não |
| 13 | `moonshotai/kimi-k2-thinking` | Kimi K2 Thinking | 262k | sim |
| 14 | `moonshotai/kimi-k3` | Kimi K3 | 1M | sim |
| 15 | `qwen/qwen3-coder-480b-a35b-instruct` | Qwen3 Coder 480B (best for code) | 262k | não |
| 16 | `qwen/qwen3-next-80b-a3b-instruct` | Qwen3 Next 80B | 262k | não |
| 17 | `qwen/qwen3-next-80b-a3b-thinking` | Qwen3 Next 80B Thinking | 262k | sim |
| 18 | `qwen/qwen3-32b` | Qwen3 32B (fast) | 131k | não |
| 19 | `qwen/qwq-32b` | QwQ 32B (reasoning) | 131k | sim |
| 20 | `qwen/qwen2.5-coder-32b-instruct` | Qwen2.5 Coder 32B | 131k | não |
| 21 | `mistralai/mistral-large-3-675b-instruct-2512` | Mistral Large 3 675B | 131k | não |
| 22 | `mistralai/codestral-22b-instruct-v0.1` | Codestral 22B (code) | 32k | não |
| 23 | `bytedance/seed-oss-36b-instruct` | Seed OSS 36B | 131k | não |
| 24 | `nvidia/llama-3.1-nemotron-nano-8b-v1` | Nemotron Nano 8B (fast) | 131k | não |
| 25 | `nvidia/nemotron-3-nano-30b-a3b` | Nemotron 3 Nano 30B | 131k | não |
| 26 | `nvidia/nemotron-3.5-lightning-30b-a3b` | Nemotron 3.5 Lightning 30B (fast) | 131k | não |

Modelo principal configurado: `nvidia/z-ai/glm-5.3`. Modelo pequeno (títulos/resumos): `nvidia/nvidia/llama-3.1-nemotron-nano-8b-v1`.

## Como usar depois de instalado

Abra um **novo** PowerShell (para o PATH valer) e:

```powershell
opencode-update
```

### Opções

| Comando | O que faz |
|---|---|
| `opencode-update` | Atualiza o opencode com backup e verificação de modelos. |
| `opencode-update -Check` | Só relata: versão, scoop, modelos configurados, cobertura dos 26 recomendados, processos — **sem mudar nada**. |
| `opencode-update -KillRunning` | Pede confirmação, fecha as sessões do opencode em execução e atualiza. |
| `opencode-update -?` | Mostra a ajuda do PowerShell (parâmetros). |

Opções do `install.ps1` (executando com `-File`):

| Parâmetro | O que faz |
|---|---|
| `-NvidiaApiKey "nvapi-..."` | Escreve sua chave no config novo. |
| `-ApplyModels` | Completa os modelos que faltam em um config existente (com backup antes). |
| `-InstallDir "C:\caminho"` | Pasta de instalação customizada. |
| `-SkipScoop` | Pula a etapa Scoop/opencode (só instala a ferramenta + modelos). |
| `-NoPath` | Não mexe no PATH do usuário. |
| `-Run` | Roda o updater logo após a instalação. |

Se o opencode estiver aberto, o updater **aborta com segurança** em vez de matar suas sessões — essa é uma feature, não um bug. Feche o opencode e rode de novo, ou use `-KillRunning`.

## O que o updater faz, passo a passo

1. **Pré-voo** — confere Scoop no PATH e se o opencode está em execução.
2. **Backup** — copia `opencode.jsonc` (+ `auth.json` e `opencode.json` se existirem) para `opencode_backups\<timestamp>\` com um `backup_info.txt` (versão, hash SHA-256 e contagem de modelos).
3. **Scoop update** — atualiza o próprio Scoop e os buckets (best-effort, falha não bloqueia).
4. **opencode update** — `scoop update opencode` para a versão mais recente.
5. **Verificação de modelos** — compara hash e contagem antes/depois; se qualquer modelo sumir, **restaura o backup automaticamente**. Também relata a cobertura dos 26 recomendados.
6. **Log** — tudo em `opencode_update.log`, com resultado `SUCCESS` ou `FAILED`.

## Requisitos

- Windows 10/11 (x64)
- Windows PowerShell 5.1 (já vem no Windows) ou PowerShell 7+
- Uma chave NVIDIA gratuita — <https://build.nvidia.com>
- Conexão com a internet (GitHub + buckets do Scoop)

## Backup e restauração manual

Cada execução cria `opencode_backups\<timestamp>\`. Para restaurar manualmente:

```powershell
Copy-Item .\opencode_backups\20261012_050757\opencode.jsonc "$env:USERPROFILE\.config\opencode\opencode.jsonc" -Force
```

O `-ApplyModels` também cria um backup timestampado (`opencode.jsonc.bak-...`) antes de qualquer merge.

## Desinstalação

```powershell
powershell -File "$env:LOCALAPPDATA\Programs\opencode-update\uninstall.ps1"
```

Remove a ferramenta e a entrada do PATH. **Não** desinstala o opencode nem o Scoop. Se quiser remover os modelos, edite ou apague o `opencode.jsonc`.

## Nota importante: opencode v2

O Scoop também oferece o **opencode v2** (`versions/opencode2`). A configuração do v2 **é incompatível** com a do v1 — este projeto atualiza o pacote `opencode` (v1), instalado na maioria das máquinas. Migração para v2 é manual: veja <https://opencode.ai/v2/docs/migrate-v1/>.

## FAQ

**O update nativo do opencode dá erro. É isso que resolve?**
Sim. Instalações via Scoop não conseguem se auto-atualizar (o binário é gerenciado pelo Scoop). Este script usa o caminho correto: `scoop update opencode`.

**Preciso pagar algo pelos 26 modelos?**
Não. Eles rodam na API integrate da NVIDIA, que oferece chave gratuita com créditos em <https://build.nvidia.com>. A chave é sua — este repositório não contém nenhuma chave.

**Meus modelos/chaves do `opencode.jsonc` podem ser perdidos?**
O update via Scoop não toca no seu config — mas o script faz backup e verifica assim mesmo. Se a contagem de modelos cair, ele restaura o backup sozinho.

**Já tenho um `opencode.jsonc` com meus modelos. O instalador mexe nele?**
Sem `-ApplyModels`, não: ele apenas verifica e relata quantos dos 26 recomendados você já tem. Com `-ApplyModels`, ele adiciona **apenas os que faltam** (backup antes, comentários preservados).

**Funciona no PowerShell 7?**
Sim, testado nas duas engines (CI valida sintaxe no Windows PowerShell 5.1 e no PowerShell 7, além da consistência dos 26 modelos entre template e scripts).

**Preciso rodar como Administrador?**
Não. Scoop, opencode e esta ferramenta são 100% por usuário, sem elevação.

## Estrutura das releases

- **Repositório** — código-fonte, README, template de modelos, installer e updater.
- **Release** — bundle `opencode-update.zip` (scripts + template + README + LICENSE) e o `install.ps1` usado pelo one-liner. A URL `releases/latest/download/...` aponta sempre para a release mais nova.

## Licença

[MIT](LICENSE) — CanalQb. Use, modifique e compartilhe.

- Blog: <https://canalqb.com.br/>
- YouTube: <https://www.youtube.com/channel/UCdOA_1KzXHIp3gmVyyYv2sg>
- Repositório: <https://github.com/canalqb/opencode-update>
