create or replace FUNCTION "F_DCP_GET_SALEQTY" (
P_EID IN VARCHAR2,		--企业
P_PluNo	IN VARCHAR2,		--品号
P_FeatureNo IN VARCHAR2,	--特征码 空格或空表示不区分特征码
P_OrgID	IN VARCHAR2,		--组织	空则表示不区分机构，取总量
P_ChannelID IN VARCHAR2,	--渠道	
P_WAREHOUSE	IN VARCHAR2,	--仓库	空则表示不区分仓库，取机构的总量。
P_SUnit IN VARCHAR2		--交易单位
) 
RETURN NUMBER 
IS
--------------------------------------------------------------------------------
--说明　　 : 获取可售量
--数据流说明:
--创建者   : JW
--创建时间 : 2020-06-10
--修改记录流水:
--修改人        
--返回：换算率
--调用：select F_DCP_GET_SALEQTY('99','001','00101','01','01','01','KG') from dual
--P_WAREHOUSE 支持不传 取机构的总库存
--P_OrgID 支持不传 取渠道的总库存
--------------------------------------------------------------------------------
V_BreakPoint			VARCHAR2(255);
V_Err				INTEGER;
V_Msg				VARCHAR2(255);


V_Qty		NUMBER(18,4);

PRAGMA AUTONOMOUS_TRANSACTION;	
BEGIN
	
	
	V_Qty := F_DCP_GET_SALEQTY_SQL(P_EID,P_PLUNO,P_FeatureNo,P_OrgID,P_ChannelID,P_WAREHOUSE,P_SUnit);	
	commit;
	return V_Qty;
	
EXCEPTION WHEN OTHERS THEN
	rollback;
	Raise_Application_Error(-20001, v_BreakPoint || '-'|| SQLERRM);  	
END;
