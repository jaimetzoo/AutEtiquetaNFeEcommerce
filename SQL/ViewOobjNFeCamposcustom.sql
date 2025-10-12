--------------------------------------------------------
--  DDL for View OOBJ_NFE_CAMPOSCUSTOM
--------------------------------------------------------
  CREATE OR REPLACE FORCE VIEW "INTEGRA"."OOBJ_NFE_CAMPOSCUSTOM" ("ID_CAMPOCUSTOM", "ID_NFE", "XCAMPO", "XTEXTO", "TIPO") AS 
  select distinct
	 nfe.TI119_NOTA_FISCAL_IE                                                     as id_campocustom, -- Chave prim�ria desta view
	 to_number(nfe.TI119_NOTA_FISCAL_IE || lpad(nfe.TI119_SERIE_IE, 3, 0) ||
	 lpad(nfe.TI119_UNIDADE_IE, 4, 0))                                            as id_nfe,         -- Chave estrangeira da view OOBJ_NFE_ENVIO
    'IMPRESSORA' as xCampo,
--	 nvl(nfe.TI119_TEXTO_NFE_IMPRESSORA,'IMP') as xTexto,
    (case 
        when nfe.TI119_UNIDADE_IE in (203,300) then nvl(nfe.TI119_TEXTO_NFE_IMPRESSORA,'IMP')
        when nfe.TI119_NUMERO_DAV like 'WC%' then nvl(nfe.TI119_TEXTO_NFE_IMPRESSORA,'IMP') -- Apenas pedidos Ecommerce
        else 'IMP'
     end) as xTexto,
     'C' as tipo
from TI119_NFE_NF nfe
-- Condi��o para o extrator Oobj-NFe ler o registro.
where nfe.TI119_STATUS_REGISTRO = 'NP' and nfe.TI119_SISTEMA_DESTINO_IE = 9997
;
