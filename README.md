# 📦 Documentação de Processo: Automação de Emissão de Etiqueta de Volume e NFe

## 1. Visão Geral e Escopo

### 1.1 Objetivo

Detalhar o processo de automação da emissão da etiqueta de volume e da geração/impressão da Nota Fiscal Eletrônica (NFe), disparado após a separação física de pedidos de E-commerce (WC). O objetivo é reduzir intervenção manual, acelerar o faturamento e liberar o pedido para expedição.

### 1.2 Escopo

Cobre desde a informação da quantidade de volumes no aplicativo de separação até a impressão física da Etiqueta de Volume e da DANFE (Documento Auxiliar da NFe).

### 1.3 Pré-Condições Técnicas (APK)

- **Componente:** APK Separação  
- **Requisito Mínimo:** Versão 2.7.2 ou superior

A exibição do popup de volumes no APK Separação (v2.7.2+) e o disparo da automação da etiqueta só ocorrem se a chave `ETQ_AUT_VOLUME` estiver definida como 'S' na tabela `INTEGRA.UNIDADE_NFE_AUT_ECOM`.

### 1.4 Gatilho Inicial
> ![Volume APK Sepração](img/VolumeSeparacao.png)


A automação inicia com a conclusão da separação física do pedido no APK 'SEPARAÇÃO', seguida da informação da quantidade de volumes. Este evento insere um novo registro na tabela de controle:

| Tabela de Controle                       | Campos Principais           | Valor Padrão | Descrição                                               |
|------------------------------------------|-----------------------------|--------------|---------------------------------------------------------|
| EPORTAL.VOLUME_PEDIDOS_ECOM_PAINEL (VPEP)| UNIDADE, PEDIDO, VOLUMES, IMPRESSO | IMPRESSO = 'N' | Dados para geração da etiqueta e controle da impressão. |

---

## 2. Caminho da Automação da NFe (ERP e Faturamento)

Garante que o pedido, após separado, seja faturado automaticamente no ERP e tenha sua NFe autorizada pela SEFAZ.

### 2.1 Preparação da Pré-Nota (Procedimento de Internalização)

Quando o pedido é integrado ao ERP, um procedimento aplica regra específica para pedidos de E-commerce.

- **Procedimento:** `INTEGRA.PI_INTERNALIZA_PRE_NOTA`
- **Regra de Automação:** Consulta tabela de parâmetro para forçar status inicial da pré-nota no ERP para '3' - CONFERENCIA CONCLUIDA.

```sql
INTEGRA.PI_INTERNALIZA_PRE_NOTA

IF vc_pre_notas_sobe.TI009_SISTEMA_ORIGEM_E in (5,6) AND vT909_STATUS_PRENOTA_E_COM IS NOT NULL THEN
    vSituacaoPreNota := vT909_STATUS_PRENOTA_E_COM; -- Força para '3' - CONFERENCIA CONCLUIDA
END IF;
```

### 2.2 Habilitação da Unidade (Tabela de Parâmetros)

A emissão automática da NFe só ocorre se a unidade estiver configurada na tabela `INTEGRA.UNIDADE_NFE_AUT_ECOM`.

| Tabela de Parâmetros      | Campo Chave      | Requisito                        |
|--------------------------|------------------|----------------------------------|
| UNIDADE_NFE_AUT_ECOM     | NFE_AUT_ECOM     | 'S' (Habilita NFe Automática)    |
|                          | NFE_AUT_RETIRA   | 'S' (Habilita para Retira)       |
|                          | NFE_AUT_ENTREGA  | 'S' (Habilita para Entrega)      |

### 2.3 Motor da Automação (Trigger SQL)

A trigger centraliza a inclusão da pré-nota na fila de emissão automática (`TPRE_EMISSAO_NFE_AUTO`), após alteração de status para '3'.

- **Trigger:** `TR_T119_EMISSAO_AUTO_ECOM`
- **Tabela Alvo:** `T119_PRENOTA` (Dispara em UPDATE ou INSERT no campo `T119_SITUACAO_PRENOTA`)
- **Ação:** Insere registro na fila monitorada pelo serviço de faturamento para geração da NFe.
- **Requisito:** Apenas origem 4 - Ecommerce e tipo venda 'A' - Venda.

> **IMPORTANTE:**  
> A trigger `TR_T119_EMISSAO_AUTO_ECOM` só funciona se o parâmetro no MDLog estiver desabilitado. Caso habilitado, a automatização é controlada pela trigger da Informata.  
> ![Parêmetros MDLog](img/ParamMDLog.png)

---

## 3. Configuração da Impressão da NFe (DANFE)

A impressão da DANFE é controlada pelo ERP, que repassa a informação da impressora ao sistema OOBJ, responsável pelo processamento do XML de autorização.

### 3.1 Mapeamento da Impressora no ERP

O nome da impressora é configurado nos parâmetros globais do `T908_PARAM_EMPRESA` e inserido na tabela de integração `TI119_NFE_NF` (`TI119_TEXTO_NFE_IMPRESSORA`) durante o cálculo da NFe.

| Tipo de Pedido   | Parâmetro no T908_PARAM_EMPRESA |
|------------------|---------------------------------|
| Cliente Retira   | T908_TEXTO_CLIENTE_RETIRA       |
| Entrega          | T908_TEXTO_ENTREGA              |

O nome configurado é salvo no campo `TI119_TEXTO_NFE_IMPRESSORA` da tabela de integração `TI119_NFE_NF`.

### 3.2 Transmissão da Impressora para o OOBJ (View de Customização)

A `OOBJ_NFE_CAMPOSCUSTOM` insere o nome da impressora no XML de envio para o OOBJ, usando o campo customizado `IMPRESSORA`.

- **Tabela de Integração:** `TI119_NFE_NF`
- **Destino:** OOBJ

### 3.3 Configuração Física e Lógica no OOBJ

O serviço (Oobj DF-e - Motor de Serviços - Impressão) gerencia a impressão da DANFE.

![Servico Oobj](img/ServicesOobj.png)

1. **Instalação da Impressora:**  
     Deve ser instalada no servidor OOBJ via rede (não USB compartilhada) e com o MESMO NOME enviado pelo ERP (ex: TZ_204).  
     ![Impressoras Oobj](img/DevicePrintersOobj.png)

2. **Mapeamento XML:**  
     Feito no arquivo de configuração do OOBJ, usando o CNPJ e o nome da impressora para criar uma fila.

3. **Diretório XML:**  
     `C:\Oobj\Aplicativos\Oobj\oobj-motor-impressao\config\config-motor-impressao.xml`

**Exemplo de Mapeamento:**

```xml
<impressora>
        <imp tipo="normal" nome="TZ_204" copias="1"/>
        <imp tipo="contingencia" nome="TZ_204" copias="1"/>
        <dame dame="C:\Oobj\Aplicativos\Oobj\oobj-motor\artefatos\danfe_padrao.jasper" .../>
        <filas>
                <fila selector="cnpjEmit = '06256879000628' AND IMPRESSORA = 'TZ_204'"/>
        </filas>
</impressora>
```

---

## 4. Automação da Geração e Impressão da Etiqueta de Volume

Focada na impressão da etiqueta, dependente do faturamento (Status 'FATURADO') e controlada por serviço de monitoramento.

### 4.1 Serviço de Busca (Cron)

- **Serviço:** Customizado, roda no Cron a cada 30 segundos.
- **Ação:** Monitora `VOLUME_PEDIDOS_ECOM_PAINEL` (`IMPRESSO = 'N'`) e consulta `PEDIDOS_ECOM_PAINEL` para confirmar status 'FATURADO' da NFe.

### 4.2 Configuração do Servidor de Impressão (CUPS)

Etiquetas impressas via CUPS (Common Unix Printing System) `192.168.1.97:631`.

| Configuração         | Detalhes                                              |
|---------------------|-------------------------------------------------------|
| Nome da Impressora  | DEVE ser a numeração da UNIDADE (ex: 209)             |
| Tipo de Conexão     | Rede (cabo) ou Compartilhada via USB/SMB (CUPS)       |
| Dimensões           | Formato Customizado de 100mm x 100mm                  |
| Endereço de Envio   | `192.168.1.97:631/printers/[NOME DA UNIDADE]`         |

**Exemplo de Instalação CUPS (Compartilhada USB):**  
`smb://terrazoo\tzcomercial:comercial@192.168.26.55/209` (Nome no CUPS: 209)  
![Impressoras Cups](img/PrintersCups.png)

### 4.3 Finalização da Automação de Etiqueta

Após impressão de todas as etiquetas do pedido, o serviço atualiza:

- `VOLUME_PEDIDOS_ECOM_PAINEL.IMPRESSO` → 'S'

---

## 5. Fluxograma (Resumo da Orquestração)

| Passo           | Caminho ERP/NFe                                                                 | Caminho Etiqueta/Impressão                                      |
|-----------------|---------------------------------------------------------------------------------|-----------------------------------------------------------------|
| 1. Início/Gatilho | APK SEPARAÇÃO → Inserção na VPEP (IMPRESSO='N')                               |                                                                 |
| 2. Preparação   | Pedido no ERP → PI_INTERNALIZA_PRE_NOTA (Status '3')                            | Serviço de Busca (Cron 30s): Inicia monitoramento da VPEP       |
| 3. Emissão NFe  | Trigger SQL (TR_T119) → Insere na fila (TPRE_EMISSAO_NFE_AUTO)                  |                                                                 |
| 4. Faturamento  | Serviço Faturador → OOBJ → Autorização SEFAZ (STATUS FATURADO)                  |                                                                 |
| 5. Impressão    | OOBJ MOTOR IMPRESSAO → Imprime DANFE (via Mapeamento XML/Impressora de Rede)    | Serviço de Busca detecta STATUS FATURADO                        |
| 6. Finalização  |                                                                                 | Gera Etiqueta 100x100mm → Envia para CUPS → Atualiza VPEP.IMPRESSO = 'S' |
| FIM             | Processo de Emissão e Impressão Concluído                                       |                                                                 |

---

## Fluxograma do processo

Veja o código [Fluxograma Detalhado](Fluxograma/fluxograma.mmd) para mais informações.

```mermaid
---
config:
    theme: default
    layout: dagre
---
flowchart TD
 subgraph s1["WOOCOMMERCE"]
                Y["INÍCIO: Pedido WC REALIZADO"]
    end
 subgraph s2["APK SEPARAÇÃO"]
                A["Pedido WC Separado no APK"]
                B["Informar Qtd. Volumes"]
                C@{ label: "IMPRESSO = 'N'" }
    end
 subgraph s3["INTEGRACAO"]
                D["Integração:<br>Pedido Status 3-Conferência Concluída"]
                E["Trigger SQL: Insere na Fila Automação"]
    end
 subgraph s4["MDLOG"]
                F["Emissão NFe: Emite a NFe Automática com Nome Impressora"]
                G["Internalização:<br>NFe Internalizada no MDLog"]
    end
 subgraph s5["OOBJ"]
                H["Serviço Oobj:<br>Motor Faturador NFe Oobj XML"]
                I{"SEFAZ:<br>NFe AUTORIZADA?"}
                J["Serviço Oobj:<br> Motor de Impressão"]
                K["Spool:<br>Danfe NFe Impressa Automática"]
                X["FIM: Nota Fiscal Faturada e Impresssa"]
    end
 subgraph s6["NOTA FISCAL"]
                s3
                s4
                s5
    end
 subgraph s7["EPORTAL"]
                L@{ label: "Serviço de Busca Cron 30s monitora IMPRESSO = 'N'" }
                M{"NFe Status FATURADO?"}
                N["Serviço de Busca: Gera Etiqueta 100x100mm"]
    end
 subgraph s8["IMPRESSORAS CUPS"]
                O["Envio para Impressora CUPS printers/UNIDADE"]
                P@{ label: "Atualiza IMPRESSO = 'S'" }
                Q["FIM: Pedido Pronto p/ Expedição"]
    end
 subgraph s9["ETIQUETA VOLUME"]
                s7
                s8
    end
        Y --> A
        A --> B
        B --> C
        C --> D
        D --> E
        E --> F
        F --> H
        H --> I
        I -- NÃO --> H
        I -- SIM --> J & G
        J --> K
        K --> X
        L --> C & M
        G --> L
        M -- NÃO --> L
        M -- SIM --> N
        N --> O
        O --> P
        P --> Q
        s6 --> s4
        C@{ shape: rect}
        L@{ shape: rect}
        P@{ shape: rect}
```

## Unidades habilitadas no processo Automatizado

| Unidade         | Versão(coletor) | Etiqueta Volume (Retira/Entrega) | Emissão/Impressão NFe(Retira) | Emissão/Impressão NFe(Entrega) | Emissão NFe(Entrega) |
|-----------------|-----------------|----------------------------------|-------------------------------|--------------------------------|----------------------|
| 204 Forquilha   | v2.7.2 | X | X |  | X |
| 202 Cohama      | v2.7.2 | X | X |  | X |
| 209 Calhau      | v2.7.2 | X | X |  | X |
| 207 Imperatriz  | v2.7.2 | Unidade não utiliza etiqueta de volume, não possui impressora | X | X |  |
| 220 Castanheira | v2.7.2 | Unidade possui impressora de etiqueta de volume, não possui bobina | X | X |  |
| 218 Araguaína   | v2.7.2 | Unidade não utiliza etiqueta de volume, não possui impressora | X | X |  |
| 216 Teresina    | v2.7.2 | Unidade não utiliza etiqueta de volume, não possui impressora | Impressora é USB, incompatível com OOBJ | Impressora é USB, incompatível com OOBJ | Impressora é USB, incompatível com OOBJ |
| 222 Umarizal    | v2.7.2 | Unidade possui impressora de etiqueta de volume, não possui bobina | Impressora é USB, incompatível com OOBJ | Impressora é USB, incompatível com OOBJ | Impressora é USB, incompatível com OOBJ |
| 221 Marabá      | v2.7.2 | Unidade não utiliza etiqueta de volume, não possui impressora | X | X |  |
| 206 Rio Anil    | v2.7.2 | Unidade não utiliza etiqueta de volume, não possui impressora | X | X |  |
| 213 Maiobão     | v2.7.2 | Unidade não utiliza etiqueta de volume, não possui impressora | X | X |  |
