create or replace PROCEDURE "SP_CRM_CARDBETWEEN" (
	P_EID		IN	VARCHAR2,	--企业ID
	P_CardTypeID	IN	VARCHAR2,	--卡类型
	P_BillType	IN	VARCHAR2,	--单据类型
	P_BeginNo	IN	VARCHAR2,	--开始号码
	P_EndNo		IN	VARCHAR2,	--截止号码（可空）
	P_Quantity	IN	INTEGER,	--张数（可为0）
	P_BeginNo_out	OUT	VARCHAR2,	--开始号码
	P_EndNo_out	OUT	VARCHAR2,	--截止号码
	P_Quantity_out	OUT	INTEGER,	--张数
	P_Amount	OUT	NUMBER,		--总金额
	P_Amount1	OUT	NUMBER,		--总金额（本金）
	P_Amount2	OUT	NUMBER,		--总金额（赠送)
	P_Allpoint	OUT	NUMBER,		--总积分
	P_Validpoint	OUT	NUMBER,		--总有效积分
	P_Usedpoint	OUT	NUMBER,		--总已用积分
	P_InValidpoint	OUT	NUMBER,		--总失效积分
	P_Bean		OUT	NUMBER,		--总福豆
	P_TotalFaceAmount OUT   NUMBER		--总面额
) 
AS
-------------------------------------------------------------------
--名称：卡张数计算:开始号码截止号码
--说明：根据开始号码截止号码计算张数，或根据开始号码和张数计算截止号码
--参数：单据类型
--备注：
--创建者   : JW
--创建时间 : 2017-07-25
--修改记录：
-------------------------------------------------------------------
V_BreakPoint			VARCHAR2(255);
V_Err				INTEGER;
V_Msg				VARCHAR2(255);

V_CardNo			VARCHAR2(50);	

V_Count_ALL			INTEGER;
V_Count				INTEGER;
V_BeginCardNo			VARCHAR2(50);
V_EndCardNo			VARCHAR2(50);
V_Amount			NUMBER(18,4);		--总金额
V_Amount1			NUMBER(18,4);		--总金额（本金）
V_Amount2			NUMBER(18,4);		--总金额（赠送)
V_Allpoint			NUMBER(18,4);		--总积分
V_Validpoint			NUMBER(18,4);		--总有效积分
V_Usedpoint			NUMBER(18,4);		--总已用积分
V_InValidpoint			NUMBER(18,4);		--总失效积分
V_Bean				NUMBER(18,4);		--总福豆
V_TotalFaceAmount		NUMBER(18,4);		--总面额

V_BILLTYPENAME			VARCHAR2(64);

V_STATUS			INTEGER;
V_BRANCHID			VARCHAR2(32);

V_CardTypeId			VARCHAR2(32);--CRM_Card中卡类型ID

BEGIN  
	V_BreakPoint:= 'SP_CRM_CardBetween_010';
	V_Err := -20001;
	
	
	IF P_Quantity <= 0 AND P_EndNo is null THEN
		V_Msg := '截止卡号或张数至少填写一个';
		Raise_Application_Error(V_Err, V_Msg);
	END IF;			

	
	P_BeginNo_out := P_BeginNo;	

	V_BreakPoint:= 'SP_CRM_CardBetween_020';
	BEGIN
		SELECT CardNo,STATUS,BRANCHID,CARDTYPEID
		INTO V_CardNo,V_STATUS,V_BRANCHID,V_CardTypeId
		FROM CRM_Card
		WHERE EID=P_EID
		  AND CardNo = P_BeginNo;
	EXCEPTION WHEN NO_DATA_FOUND THEN
		--自动添加
		V_Msg := '开始卡号不存在,请确认卡信息是否已经生成过';
		Raise_Application_Error(V_Err, V_Msg);		
	END;	
	

	IF(V_CardTypeId <> P_CardTypeID)THEN
		V_Msg := '卡号['||P_BeginNo||']不是当前卡类型';
		Raise_Application_Error(V_Err, V_Msg);
	END IF;

	--SELECT COUNT(*)
	--INTO V_Count
	--FROM CRM_CARD
	--WHERE EID = P_EID
	--  AND CARDTYPEID = P_CardTypeID
	--  AND CARDNO = P_BeginNo
	--  AND (STATUS IN (SELECT * FROM TABLE(F_CRM_GetBillCardStatus(P_BillType)))
	--  	OR (P_BillType = 'CRM050' AND BranchID is null)
	--  	)
	--  ;
	  
	IF not (P_BillType = 'CRM050' AND V_BRANCHID is null) THEN
		  	  	
		SELECT count(*) into V_Count FROM TABLE(F_CRM_GetBillCardStatus(P_BillType)) where COLUMN_VALUE = V_STATUS;	  
		IF V_Count <= 0 THEN
			
			BEGIN
				SELECT BILLTYPENAME INTO V_BILLTYPENAME
				FROM CRM_BILLTYPE
				WHERE BILLTYPE = P_BillType;
			EXCEPTION WHEN OTHERS THEN
				V_BILLTYPENAME := '此业务';
			END;		
			V_Msg := '起始卡号'||P_BeginNo||'不允许再做'||V_BILLTYPENAME||',请重新输入';
			Raise_Application_Error(V_Err, V_Msg);
		END IF;		
	END IF;
	
	IF P_EndNo is not null THEN
		
		
		--0.检查
		IF length(P_BeginNo) <> length(P_EndNo) THEN
			V_Msg := '开始卡号截止卡号长度不一致';
			Raise_Application_Error(V_Err, V_Msg);
		END IF;
	   	
		IF F_CRM_StringHead(P_BeginNo) <> F_CRM_StringHead(P_EndNo) THEN
			V_Msg := '开始卡号截止卡号前缀不一致';
			Raise_Application_Error(V_Err, V_Msg);
		END IF;
	   	
	   		
		V_BreakPoint:= 'SP_CRM_CardBetween_030';
		
		IF P_BillType = 'CRM050' THEN	--入库单		
			SELECT COUNT(*),NVL(SUM(Amount),0),NVL(SUM(Amount1),0),NVL(SUM(Amount2),0),
				NVL(SUM(ALLPOINT),0),NVL(SUM(VALIDPOINT),0),NVL(SUM(INVALIDPOINT),0),NVL(SUM(USEDPOINT),0),
				NVL(SUM(BEAN),0),NVL(SUM(FaceAmount),0) 
			INTO V_Count,V_Amount,V_Amount1,V_Amount2,
				V_Allpoint,V_Validpoint,V_Invalidpoint,V_Usedpoint,
				V_Bean,V_TotalFaceAmount
			FROM CRM_CARD a join (SELECT COLUMN_VALUE FROM TABLE(F_CRM_GetBillCardStatus(P_BillType))) b
			on a.STATUS = b.COLUMN_VALUE
			WHERE EID = P_EID
			  AND CARDTYPEID = P_CardTypeID
			  AND CARDNO >= P_BeginNo
			  AND CARDNO <= P_EndNo
			  AND LENGTH(CARDNO) = LENGTH(P_BeginNo)
			  AND BranchID is null;
		ELSE
			SELECT COUNT(*),NVL(SUM(Amount),0),NVL(SUM(Amount1),0),NVL(SUM(Amount2),0),
				NVL(SUM(ALLPOINT),0),NVL(SUM(VALIDPOINT),0),NVL(SUM(INVALIDPOINT),0),NVL(SUM(USEDPOINT),0),
				NVL(SUM(BEAN),0),NVL(SUM(FaceAmount),0) 
			INTO V_Count,V_Amount,V_Amount1,V_Amount2,
				V_Allpoint,V_Validpoint,V_Invalidpoint,V_Usedpoint,
				V_Bean,V_TotalFaceAmount
			FROM CRM_CARD a join (SELECT COLUMN_VALUE FROM TABLE(F_CRM_GetBillCardStatus(P_BillType))) b
			on a.STATUS = b.COLUMN_VALUE
			WHERE EID = P_EID
			  AND CARDTYPEID = P_CardTypeID
			  AND CARDNO >= P_BeginNo
			  AND CARDNO <= P_EndNo
			  AND LENGTH(CARDNO) = LENGTH(P_BeginNo)
			  ;
		END IF;

		--两个卡号段之间如果有状态异常的卡，则报错（山山家）
	   	SELECT COUNT(*) INTO V_Count_ALL
	   	  FROM CRM_CARD
		WHERE EID = P_EID
		  AND CARDTYPEID = P_CardTypeID
		  AND CARDNO >= P_BeginNo
		  AND CARDNO <= P_EndNo
		  AND LENGTH(CARDNO) = LENGTH(P_BeginNo)
		  ;

		IF V_Count_ALL <> V_Count THEN
			BEGIN
				SELECT BILLTYPENAME INTO V_BILLTYPENAME
				FROM CRM_BILLTYPE
				WHERE BILLTYPE = P_BillType;
			EXCEPTION WHEN OTHERS THEN
				V_BILLTYPENAME := '此业务';
			END;		
			V_Msg := '开始卡号截止卡号之间存在不能做'||V_BILLTYPENAME||'的卡号，请重新输入';
			Raise_Application_Error(V_Err, V_Msg);			
		END IF;			
					
		P_EndNo_out := P_EndNo;
		P_Quantity_out := V_Count;
	ELSE
	
		V_BreakPoint:= 'SP_CRM_CardBetween_030';
		
		IF P_BillType = 'CRM050' THEN
		
			SELECT COUNT(*),NVL(SUM(Amount),0),NVL(SUM(Amount1),0),NVL(SUM(Amount2),0),
				NVL(SUM(ALLPOINT),0),NVL(SUM(VALIDPOINT),0),NVL(SUM(INVALIDPOINT),0),NVL(SUM(USEDPOINT),0),
				NVL(SUM(BEAN),0),MAX(CARDNO),NVL(SUM(FaceAmount),0) 
			INTO V_Count,V_Amount,V_Amount1,V_Amount2,
				V_Allpoint,V_Validpoint,V_Invalidpoint,V_Usedpoint,
				V_Bean,V_EndCardNo,V_TotalFaceAmount
			FROM (				
				SELECT T.* FROM (
					SELECT * FROM CRM_CARD a join (SELECT COLUMN_VALUE FROM TABLE(F_CRM_GetBillCardStatus(P_BillType))) b
					on a.STATUS = b.COLUMN_VALUE
					WHERE EID = P_EID
					  AND CARDTYPEID = P_CardTypeID
					  AND CARDNO >= P_BeginNo
					  AND LENGTH(CARDNO) = LENGTH(P_BeginNo)
					  AND (F_CRM_StringHead(P_BeginNo) is null or CARDNO like F_CRM_StringHead(P_BeginNo)||'%')	
					  AND BranchID is null
					ORDER BY CARDNO			
					) T
				WHERE ROWNUM <= P_Quantity
				);
		ELSE
			SELECT COUNT(*),NVL(SUM(Amount),0),NVL(SUM(Amount1),0),NVL(SUM(Amount2),0),
				NVL(SUM(ALLPOINT),0),NVL(SUM(VALIDPOINT),0),NVL(SUM(INVALIDPOINT),0),NVL(SUM(USEDPOINT),0),
				NVL(SUM(BEAN),0),MAX(CARDNO),NVL(SUM(FaceAmount),0) 
			INTO V_Count,V_Amount,V_Amount1,V_Amount2,
				V_Allpoint,V_Validpoint,V_Invalidpoint,V_Usedpoint,
				V_Bean,V_EndCardNo,V_TotalFaceAmount
			FROM (				
				SELECT T.* FROM (
					SELECT * FROM CRM_CARD a join (SELECT COLUMN_VALUE FROM TABLE(F_CRM_GetBillCardStatus(P_BillType))) b
					on a.STATUS = b.COLUMN_VALUE
					WHERE EID = P_EID
					  AND CARDTYPEID = P_CardTypeID
					  AND CARDNO >= P_BeginNo
					  AND LENGTH(CARDNO) = LENGTH(P_BeginNo)
					  AND (F_CRM_StringHead(P_BeginNo) is null or CARDNO like F_CRM_StringHead(P_BeginNo)||'%')	
					ORDER BY CARDNO			
					) T
				WHERE ROWNUM <= P_Quantity
				);		
		END IF;
		
		IF V_Count < P_Quantity THEN
			V_Msg := '从该卡号起可用作此业务'||P_BillType||'的卡有'||to_char(V_Count)||'张，不足'||to_char(P_Quantity)||'张';
			Raise_Application_Error(-20001, v_BreakPoint || '-'|| V_Msg);  
		END IF;			
		
		
		--两个卡号段之间如果有状态异常的卡，则报错（山山家）
		SELECT COUNT(*) INTO V_Count_ALL
	   	  FROM CRM_CARD
		WHERE EID = P_EID
		  AND CARDTYPEID = P_CardTypeID
		  AND CARDNO >= P_BeginNo
		  AND CARDNO <= V_EndCardNo
		  AND LENGTH(CARDNO) = LENGTH(P_BeginNo)
		  AND (F_CRM_StringHead(P_BeginNo) is null or CARDNO like F_CRM_StringHead(P_BeginNo)||'%');

		IF V_Count_ALL <> V_Count THEN
			BEGIN
				SELECT BILLTYPENAME INTO V_BILLTYPENAME
				FROM CRM_BILLTYPE
				WHERE BILLTYPE = P_BillType;
			EXCEPTION WHEN OTHERS THEN
				V_BILLTYPENAME := '此业务';
			END;		
			V_Msg := '开始卡号截止卡号之间存在不能做'||V_BILLTYPENAME||'的卡号，请重新输入';
			Raise_Application_Error(V_Err, V_Msg);			
		END IF;			

		
		
		P_EndNo_out := V_EndCardNo;	
		P_Quantity_out := V_Count;			
	END IF;			
		
	P_Amount 	:=	V_Amount;
	P_Amount1	:=	V_Amount1;
	P_Amount2	:=	V_Amount2;
	P_Allpoint	:=	V_Allpoint;
	P_Validpoint	:=	V_Validpoint;
	P_Usedpoint	:=   	V_Usedpoint;
	P_InValidpoint	:=	V_InValidpoint;
	P_Bean		:=	V_Bean;
	P_TotalFaceAmount := V_TotalFaceAmount;
		
EXCEPTION WHEN OTHERS THEN
	Raise_Application_Error(-20001, v_BreakPoint || '-'|| SQLERRM);  
END;
