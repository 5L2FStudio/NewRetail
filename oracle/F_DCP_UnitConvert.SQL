create or replace FUNCTION "F_DCP_UNITCONVERT" (
P_EID IN VARCHAR2,
P_PluNo	IN VARCHAR2,
P_FromUnit IN VARCHAR2,
P_ToUnit IN VARCHAR2,
P_Qty	IN NUMBER
) 
RETURN NUMBER 
IS
--------------------------------------------------------------------------------
--说明　　 : 获取单位换算量
--数据流说明:
--创建者   : JW
--创建时间 : 2020-06-10
--修改记录流水:
--修改人        
--返回：换算率
--调用：select F_DCP_UnitConvert('99','001020001','KG','G',2) from dual
--------------------------------------------------------------------------------

V_BreakPoint			VARCHAR2(255);
V_Err				INTEGER;
V_Msg				VARCHAR2(255);


V_RATE NUMBER(18,4);

V_Qty	NUMBER(23,8);
	
BEGIN
	V_BreakPoint := 'F_DCP_UnitConvert_010';

	V_Rate := F_DCP_UnitConvert_Rate(P_EID,P_PluNo,P_FromUnit,P_ToUnit);	
	
	V_Qty := V_Rate * P_Qty;
	
	return V_Qty;
	
EXCEPTION WHEN OTHERS THEN
	Raise_Application_Error(-20001, v_BreakPoint || '-'|| SQLERRM);  
END;
