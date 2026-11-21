# Classic Aim Controls

[![Version](https://img.shields.io/badge/version-4.13.1-blue.svg)](#)
[![Game](https://img.shields.io/badge/game-Dragon's%20Dogma%202-red.svg)](#requirements)
[![REFramework](https://img.shields.io/badge/tool-REFramework-orange.svg)](https://github.com/praydog/REFramework)
[![Nexus Mods](https://camo.githubusercontent.com/1b13470b273fd814146a809ba9e00a631ba31d8a1d3ff94ec60f2e553f36e2ec/68747470733a2f2f696d672e736869656c64732e696f2f656e64706f696e743f75726c3d6874747073253341253246253246676973742e67697468756275736572636f6e74656e742e636f6d2532467261646a333037253246653961383037333165653233366363363766623030623639386537353230316525324672617725324635323330303734646662316136306662613931376131323332663933383266613563666563356462253246656e64706f696e742e6a736f6e)](https://www.nexusmods.com/dragonsdogma2/mods/2553?tab=description)

[Português (Brasil)](#português-brasil)

![Classic Aim Controls cover](cover.jpg)

Recreates the classic aiming scheme for bows: hold LT to aim, press RT to shoot while continuing to aim, and release LT to cancel aiming without firing an arrow.

## Table of contents

- [What it does](#what-it-does)
- [Controls](#controls)
- [Requirements](#requirements)
- [Installation](#installation)
- [Recommended game controls](#recommended-game-controls)
- [Warfarer](#warfarer)
- [Cloudburst Shot and Cataract Shot](#cloudburst-shot-and-cataract-shot)
- [Settings](#settings)
- [Uninstallation](#uninstallation)
- [Compatibility](#compatibility)
- [Bug reports](#bug-reports)
- [Português (Brasil)](#português-brasil)

## What it does

Classic Aim Controls is a Lua script for REFramework that restores the classic bow aiming behavior in Dragon's Dogma 2.

Supported vocations and weapon use:

- Archer
- Magick Archer
- Warfarer, only while the equipped weapon is a bow or magick bow; with another weapon, Warfarer keeps the game's original controls

The mod also works with:

- Loaded objects and creatures
- Piercing Dart
- Skill arrows
- Cloudburst Shot
- Cataract Shot

It works in the game's input layer and follows the gamepad buttons configured by the player.

## Controls

| Control | Action |
|---|---|
| Hold LT | Aim |
| Press RT | Shoot and continue aiming while LT remains held |
| Release LT | Cancel aiming without firing an arrow |

For loaded objects and creatures:

| Control | Action |
|---|---|
| LT | Aim the throw |
| RT | Throw |
| Release LT | Cancel the aim |

## Requirements

- Dragon's Dogma 2 (PC)
- REFramework for Dragon's Dogma 2 (`dinput8.dll` in the game folder)

## Installation

### Fluffy Mod Manager

1. Drag the mod `.zip` into Fluffy Mod Manager with Dragon's Dogma 2 selected.
2. Enable the mod.

### Manual installation

Copy `reframework/autorun/ClassicAimControls.lua` to:

```text
<game folder>/reframework/autorun/
```

## Recommended game controls

Open:

```text
REFramework > Script Generated UI > ClassicAimControls > Recommended game controls
```

Click **Apply classic aim controls** to change the gamepad bindings in memory to:

| Game control | Button |
|---|---|
| Vocation Action | LT |
| Cancel | RB |
| Light Attack | RT |
| Grab | X |

Enable **Apply automatically on startup** and click **Save settings** to apply the layout each time the game starts.

If you change the controls in the game's own menu afterward, click **Apply classic aim controls** again.

## Warfarer

Since v4.6, the mod acts only while Warfarer has a bow or magick bow equipped.

It can be disabled with **Also work as Warfarer**.

## Cloudburst Shot and Cataract Shot

In the original game, these skills keep firing while the player moves the aiming control repeatedly (LT down/up).

With the mod:

- Each RT press adds another volley or arrow.
- Releasing LT cancels the skill.

### Cloudburst Shot

Cloudburst Shot has a waiting period:

- The first volley fires 2.6 seconds after activation.
- Each following volley fires 2.5 seconds after the previous one.
- RT presses before the next volley is ready are ignored, preventing an early RT press from ending the skill.

Available sliders:

| Setting | Default |
|---|---:|
| Cloudburst: first volley delay, from activation | 2.6 |
| Cloudburst: delay between volleys | 2.5 |

The delays are independent, and the first delay may be shorter than the second. It cannot be set below the skill's ready time (about 0.3 seconds).

### Cataract Shot

Cataract Shot can fire as soon as it begins preparing, with no minimum time.

## Settings

Open:

```text
REFramework > Script Generated UI > ClassicAimControls > Settings
```

| Setting | Description |
|---|---|
| Fire trigger | Action linked to RT. **Auto** accepts Grab, AttackS and AttackL. |
| Cancel with ActCancel | Cleanly cancels ready aiming. Recommended. |
| Aim again after the shot | Aims again if the game releases aim after the shot. |
| Frames until the bow is ready | Starts at 0. |
| RT buffer | Starts at 0. Remembers an early RT press until the bow can fire. |
| Show debug | Shows debug information. |
| Record trace | Records diagnostics for bug reports. |

For debugging:

1. Enable **Record trace**.
2. Reproduce the problem.
3. Click **Save trace.json**.

The trace is saved in:

```text
reframework/data/ClassicAimControls/
```

Click **Save settings** to store settings in:

```text
reframework/data/ClassicAimControls/config.json
```

Settings are loaded every time the game starts. `Enabled`, `Show debug`, and `Record trace` are never saved.

To restore the default settings, delete `config.json`.

## Uninstallation

- Disable the mod in Fluffy Mod Manager, or
- Delete `reframework/autorun/ClassicAimControls.lua`.

## Compatibility

Do not use this mod together with **Vocational Control Presets** when the **Apply automatically on startup** option is enabled in Classic Aim Controls. Both mods rewrite the same game button table.

To obtain the same layout with Vocational Control Presets, create a preset for Archer and Magick Archer with:

| Control | Button |
|---|---|
| Vocation Action | LT |
| Sheathe/Draw/Cancel | RB |
| Light Attack | RT |
| Grab | X |

## Bug reports

Please include:

- Dragon's Dogma 2 version
- REFramework version
- Mod version
- Vocation and weapon
- Skill used
- Steps to reproduce the problem
- `trace.json`, generated with **Record trace** > **Save trace.json**

## Credits and legal notice

Author: Luiz Gustavo Bringel Lisboa

Mod page: [https://www.nexusmods.com/dragonsdogma2/mods/2553?tab=description](https://www.nexusmods.com/dragonsdogma2/mods/2553?tab=description)

This is an unofficial, fan-made mod and is not affiliated with or endorsed by Capcom. Dragon's Dogma 2 and its trademarks and copyrighted materials are property of Capcom.

- REFramework by praydog is a required tool/framework.
- Fluffy Mod Manager is a recommended mod manager.

This README does not claim a partnership with either project.

---

# Português (Brasil)

[English](#classic-aim-controls)

## Controles clássicos de mira

## Índice

- [O que ele faz](#o-que-ele-faz)
- [Controles](#controles)
- [Requisitos](#requisitos)
- [Instalação](#instalação)
- [Controles recomendados do jogo](#controles-recomendados-do-jogo)
- [Warfarer](#warfarer-1)
- [Habilidades Cloudburst Shot e Cataract Shot](#habilidades-cloudburst-shot-e-cataract-shot)
- [Configurações](#configurações)
- [Desinstalar](#desinstalar)
- [Compatibilidade](#compatibilidade-1)
- [Relatar bugs](#relatar-bugs)

## O que ele faz

O Classic Aim Controls é um script Lua para o REFramework que devolve o esquema clássico de mira com arco no Dragon's Dogma 2.

Vocações e armas suportadas:

- Archer
- Magick Archer
- Warfarer, somente enquanto estiver usando arco ou arco mágico; com qualquer outra arma, o Warfarer mantém os controles originais do jogo

O mod também funciona com:

- Objetos e criaturas carregados
- Piercing Dart
- Flechas de habilidade
- Cloudburst Shot
- Cataract Shot

Ele trabalha na camada de entrada do jogo e segue os botões que o jogador configurou no gamepad.

## Controles

| Controle | Ação |
|---|---|
| Segurar LT | Mirar |
| Apertar RT | Atirar e continuar mirando enquanto LT estiver segurado |
| Soltar LT | Cancelar a mira sem disparar a flecha |

Para objetos e criaturas carregados:

| Controle | Ação |
|---|---|
| LT | Mirar o arremesso |
| RT | Arremessar |
| Soltar LT | Cancelar a mira |

## Requisitos

- Dragon's Dogma 2 (PC)
- REFramework para Dragon's Dogma 2 (`dinput8.dll` na pasta do jogo)

## Instalação

### Fluffy Mod Manager

1. Arraste o `.zip` do mod para o Fluffy Mod Manager com Dragon's Dogma 2 selecionado.
2. Ative o mod.

### Instalação manual

Copie `reframework/autorun/ClassicAimControls.lua` para:

```text
<pasta do jogo>/reframework/autorun/
```

## Controles recomendados do jogo

Abra:

```text
Menu do REFramework > Script Generated UI > ClassicAimControls > Recommended game controls
```

O botão **Apply classic aim controls** altera os botões do gamepad na memória do jogo para:

| Controle do jogo | Botão |
|---|---|
| Vocation Action | LT |
| Cancel | RB |
| Light Attack | RT |
| Grab | X |

Marque **Apply automatically on startup** e clique em **Save settings** para aplicar isso a cada vez que o jogo abrir.

Se o jogador mudar os controles no próprio menu do jogo depois, deve clicar no botão novamente.

## Warfarer

Desde a v4.6, o mod só age quando a arma em mãos é arco ou arco mágico.

Dá para desligar em **Also work as Warfarer**.

## Habilidades Cloudburst Shot e Cataract Shot

No jogo original, essas habilidades continuam atirando enquanto o jogador toca na mira (LT para baixo/para cima, repetidamente).

Com o mod:

- Cada toque em RT gera mais uma saraivada ou flecha.
- Soltar LT cancela a habilidade.

### Cloudburst Shot

Cloudburst Shot tem um tempo de espera:

- A primeira saraivada sai 2,6 s depois da ativação.
- Cada saraivada seguinte sai 2,5 s depois da anterior.
- Toques em RT antes disso são ignorados, permitindo apertar RT repetidamente sem encerrar a habilidade antes da hora.

Controles deslizantes:

| Configuração | Padrão |
|---|---:|
| Cloudburst: first volley delay, from activation | 2,6 |
| Cloudburst: delay between volleys | 2,5 |

Os dois tempos são independentes e o primeiro pode ficar abaixo do segundo. Não dá para ir abaixo do tempo que a habilidade precisa para ficar pronta (cerca de 0,3 s).

### Cataract Shot

Cataract Shot pode atirar assim que começa a preparar, sem tempo mínimo.

## Configurações

Abra:

```text
Menu do REFramework > Script Generated UI > ClassicAimControls > Settings
```

| Configuração | Descrição |
|---|---|
| Fire trigger | Ação à qual o RT está ligado. **Auto** aceita Grab, AttackS e AttackL. |
| Cancel with ActCancel | Cancela a mira pronta de forma limpa. Recomendado. |
| Aim again after the shot | Mira de novo se o jogo deixar a mira depois do tiro. |
| Frames until the bow is ready | Começa em 0. |
| RT buffer | Começa em 0. Faz um RT apertado cedo ser lembrado até o arco poder atirar. |
| Show debug | Mostra informações de depuração. |
| Record trace | Grava dados para relatórios de bugs. |

Para relatar bugs:

1. Ative **Record trace**.
2. Reproduza o problema.
3. Clique em **Save trace.json**.

O trace é salvo em:

```text
reframework/data/ClassicAimControls/
```

Clique em **Save settings** para guardar as configurações em:

```text
reframework/data/ClassicAimControls/config.json
```

As configurações são carregadas toda vez que o jogo abre. `Enabled`, `Show debug` e `Record trace` nunca são salvos.

Para voltar ao padrão, apague o `config.json`.

## Desinstalar

- Desative o mod no Fluffy Mod Manager, ou
- Apague `reframework/autorun/ClassicAimControls.lua`.

## Compatibilidade

Não use junto com o mod Vocational Control Presets quando a opção **Apply automatically on startup** deste mod estiver ligada. Os dois reescrevem a mesma tabela de botões do jogo.

Para ter o mesmo layout com o Vocational Control Presets, crie um preset para Archer e Magick Archer com:

| Controle | Botão |
|---|---|
| Vocation Action | LT |
| Sheathe/Draw/Cancel | RB |
| Light Attack | RT |
| Grab | X |

## Relatar bugs

Informe:

- Versão do jogo
- Versão do REFramework
- Versão do mod
- Vocação e arma
- Habilidade usada
- Passos para reproduzir o problema
- Arquivo `trace.json`, gerado em **Record trace** > **Save trace.json**

## Créditos e aviso legal

Autor: [SEU NOME OU USUÁRIO]

Página do mod: [https://www.nexusmods.com/dragonsdogma2/mods/2553?tab=description](https://www.nexusmods.com/dragonsdogma2/mods/2553?tab=description)

Este é um mod feito por fã, não oficial, sem ligação com a Capcom. Dragon's Dogma 2 é marca da Capcom e seus materiais protegidos por direitos autorais são propriedade da Capcom.

- O REFramework, por praydog, é uma ferramenta/framework necessário.
- O Fluffy Mod Manager é um gerenciador de mods recomendado.

Este README não afirma parceria entre os projetos.
