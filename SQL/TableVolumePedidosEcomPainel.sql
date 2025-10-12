--------------------------------------------------------
--  DDL for Table VOLUME_PEDIDOS_ECOM_PAINEL
--------------------------------------------------------
  CREATE TABLE "EPORTAL"."VOLUME_PEDIDOS_ECOM_PAINEL" (
  "DATALOG" DATE, 
	"UNIDADE" NUMBER(4,0), 
	"PEDIDO" VARCHAR2(13 BYTE), 
	"VOLUMES" NUMBER(7,0), 
	"IMPRESSO" CHAR(1 BYTE) DEFAULT 'N'
   );
--------------------------------------------------------
--  DDL for Index IDX_UND_PED_VPEP
--------------------------------------------------------
  CREATE INDEX "EPORTAL"."IDX_UND_PED_VPEP" ON "EPORTAL"."VOLUME_PEDIDOS_ECOM_PAINEL" ("UNIDADE", "PEDIDO") 

