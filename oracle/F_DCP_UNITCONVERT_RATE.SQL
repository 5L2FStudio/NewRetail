create or replace FUNCTION "F_DCP_UNITCONVERT_RATE" (
P_EID IN VARCHAR2,
P_PluNo	IN VARCHAR2,
P_FromUnit IN VARCHAR2,
P_ToUnit IN VARCHAR2
) 
RETURN NUMBER 
IS
--------------------------------------------------------------------------------
--说明　　 : 获取单位换算率
--数据流说明:
--创建者   : JW
--创建时间 : 2020-06-10
--修改记录流水:
--修改人        
--返回：换算率
--调用：select F_DCP_UnitConvert_Rate('99','001020001','KG','G') from dual
--------------------------------------------------------------------------------

V_BreakPoint			VARCHAR2(255);
V_Err				INTEGER;
V_Msg				VARCHAR2(255);


V_RATE NUMBER(18,4);

V_TempRate	NUMBER(23,8);

V_BASEUNIT	VARCHAR2(32);

V_Success1	INTEGER;	

V_Success2	INTEGER;

V_Rate1		NUMBER(23,8);	--分子
v_div1		NUMBER(23,8);	--分母
V_Rate2		NUMBER(23,8);	--分子
V_div2		NUMBER(23,8);	--分母

V_OQTY		NUMBER(23,8);
V_QTY		NUMBER(23,8);





	
BEGIN
	V_Err := -20001;
	V_BreakPoint := 'F_DCP_UnitConvert_Rate_010';

	IF P_FromUnit = P_ToUnit THEN
		return 1;
	END IF;	
	
	V_BreakPoint := 'F_DCP_UnitConvert_Rate_020';
	--1.先别管基准单位，从通用单位查找有没有直接的换算关系
	BEGIN
		--正向设置的
		SELECT UNIT_RATIO INTO V_TempRate
		FROM DCP_UNITCONVERT
		WHERE EID = P_EID
		  AND OUNIT = P_FromUnit 
		  AND UNIT = P_ToUnit;
		  
		  V_RATE := V_TempRate;
		  
		  return V_Rate;
	EXCEPTION WHEN NO_DATA_FOUND THEN		
		BEGIN
			--反向设置的
			SELECT UNIT_RATIO INTO V_TempRate
			FROM DCP_UNITCONVERT
			WHERE EID = P_EID
			  AND OUNIT = P_ToUnit 
			  AND UNIT = P_FromUnit;
			
			V_Rate := round(1/V_TempRate,8);
			return V_Rate;
		EXCEPTION WHEN NO_DATA_FOUND THEN
			null;
		END;	
	END;		  
	
	
	--2.再取基准单位，尝试通过基准单位来做换算
	V_BreakPoint := 'F_DCP_UnitConvert_Rate_030';
	BEGIN
		SELECT BASEUNIT INTO V_BASEUNIT
		FROM DCP_GOODS
		WHERE EID = P_EID AND PLUNO = P_PLUNO;
	EXCEPTION WHEN NO_DATA_FOUND THEN
		--V_BASEUNIT := 'g';
		
		V_Msg := '品号'||P_PLUNO||'单位换算失败,品号信息不存在';
		Raise_Application_Error(V_Err, V_Msg);								
		
	END;
	
	V_BreakPoint := 'F_DCP_UnitConvert_Rate_040';
	V_Success1 := 0;	
	IF P_FromUnit = V_BASEUNIT THEN
	  V_RATE1 := 1;
	  V_DIV1 := 1;
	  V_Success1 := 1;		
	ELSE
		BEGIN
			--正向设置的
			SELECT UNIT_RATIO INTO V_TempRate
			FROM DCP_UNITCONVERT
			WHERE EID = P_EID
			  AND OUNIT = P_FromUnit 
			  AND UNIT = V_BASEUNIT;
	
			  V_RATE1 := V_TempRate;
			  V_DIV1 := 1;
			  V_Success1 := 1;
		EXCEPTION WHEN NO_DATA_FOUND THEN		
			BEGIN
				--反向设置的
				SELECT UNIT_RATIO INTO V_TempRate
				FROM DCP_UNITCONVERT
				WHERE EID = P_EID
				  AND OUNIT = V_BASEUNIT 
				  AND UNIT = P_FromUnit;
				
				--V_Rate1 := round(1/V_TempRate,8);
				V_Rate1 := 1;
				V_Div1 := V_TempRate;	--为了避免中间过程的精度误差，最后统一算，先这样记下来，这里先不除		
				V_Success1 := 1;
			EXCEPTION WHEN NO_DATA_FOUND THEN
				V_Success1 := 0;
			END;	
		END;		  
	END IF;

	V_BreakPoint := 'F_DCP_UnitConvert_Rate_050';
	V_Success2 := 0;
	IF P_ToUnit = V_BASEUNIT THEN
	  V_RATE2 := 1;
	  V_DIV2 := 1;
	  V_Success2 := 1;		
	ELSE
		BEGIN
			--正向设置的
			SELECT UNIT_RATIO INTO V_TempRate
			FROM DCP_UNITCONVERT
			WHERE EID = P_EID
			  AND OUNIT = V_BASEUNIT 
			  AND UNIT = P_ToUnit;
	
			  V_RATE2 := V_TempRate;
			  V_Div2 := 1;
			  V_Success2 := 1;
			  
			  
		EXCEPTION WHEN NO_DATA_FOUND THEN		
			BEGIN
				--反向设置的
				SELECT UNIT_RATIO INTO V_TempRate
				FROM DCP_UNITCONVERT
				WHERE EID = P_EID
				  AND OUNIT = P_ToUnit 
				  AND UNIT = V_BASEUNIT;
				--V_Rate2 := round(1/V_TempUnit,8);				
				V_Rate2 := 1;		
				V_Div2 := V_TempRate;		--为了避免中间过程的精度误差，最后统一算，先这样记下来，这里先不除
				V_Success2 := 1;
			EXCEPTION WHEN NO_DATA_FOUND THEN
				V_Success2 := 0;
			END;	
		END;	
	END IF;	  

	IF V_Success1 = 1 AND V_Success2 = 1 THEN		
		V_Rate := Round((V_Rate1 * V_Rate2) / (V_Div1 * V_Div2),8);
		return V_Rate;		
	END IF;	
	
	
	V_BreakPoint := 'F_DCP_UnitConvert_Rate_060';
	IF V_Success1 = 0 THEN
		BEGIN
			--正向设置的
			SELECT OQTY,QTY INTO V_OQTY,V_QTY
			FROM DCP_GOODS_UNIT
			WHERE EID = P_EID
			  AND PLUNO = P_PLUNO
			  AND OUNIT = P_FromUnit 
			  AND UNIT = V_BASEUNIT;
	
			  V_RATE1 := V_QTY;
			  V_DIV1 := V_OQTY;
			  V_Success1 := 1;
		EXCEPTION WHEN NO_DATA_FOUND THEN		
			BEGIN
				--反向设置的
				SELECT OQTY,QTY INTO V_OQTY,V_QTY
				FROM DCP_GOODS_UNIT
				WHERE EID = P_EID
				  AND PLUNO = P_PLUNO
				  AND OUNIT = V_BASEUNIT 
				  AND UNIT = P_FromUnit;
				V_Rate1 := V_OQTY;
				V_Div1 := V_QTY;	
				V_Success1 := 1;
			EXCEPTION WHEN NO_DATA_FOUND THEN
				V_Success1 := 0;
			END;	
		END;		  		
	END IF;	
	
	V_BreakPoint := 'F_DCP_UnitConvert_Rate_070';
	IF V_Success2 = 0 THEN
		BEGIN
			--正向设置的
			SELECT OQTY,QTY INTO V_OQTY,V_QTY
			FROM DCP_GOODS_UNIT
			WHERE EID = P_EID
			  AND PLUNO = P_PLUNO
			  AND OUNIT = V_BASEUNIT 
			  AND UNIT = P_ToUnit;
	
			  V_RATE2 := V_QTY;
			  V_DIV2 := V_OQTY;
			  V_Success2 := 1;
			  
			  
		EXCEPTION WHEN NO_DATA_FOUND THEN		
			BEGIN
				--反向设置的
				SELECT OQTY,QTY INTO V_OQTY,V_QTY
				FROM DCP_GOODS_UNIT
				WHERE EID = P_EID
				  AND PLUNO = P_PLUNO
				  AND OUNIT = P_ToUnit 
				  AND UNIT = V_BASEUNIT;

				V_Rate2 := V_OQTY;
				V_Div2 := V_QTY;	
				V_Success2 := 1;
			EXCEPTION WHEN NO_DATA_FOUND THEN
				V_Success2 := 0;
			END;	
		END;		  
	END IF;	


	V_BreakPoint := 'F_DCP_UnitConvert_Rate_080';
	IF V_Success1 = 1 AND V_Success2 = 1 THEN		
		V_Rate := Round((V_Rate1 * V_Rate2) / (V_Div1 * V_Div2),8);
		return V_Rate;		
	ELSE
		V_Msg := '品号'||P_PLUNO||'单位换算失败'|| P_FromUnit ||'=>'||P_ToUnit;
		Raise_Application_Error(V_Err, V_Msg);								
			
	END IF;	

	
	--UNDO
	--return 1;
EXCEPTION WHEN OTHERS THEN
	Raise_Application_Error(-20001, v_BreakPoint || '-'|| SQLERRM);  

	
END;
