create or replace PROCEDURE "SP_CRM_CARDACCOUNT" (
	P_EID		IN	VARCHAR2,	--企业ID
	P_CompanyID	IN	VARCHAR2,	--业务发生公司	
	P_ShopID	IN	VARCHAR2,	--门店
	P_ChannelID	IN	VARCHAR2,	--渠道
	P_EmployeeID	IN	VARCHAR2,	--员工
	P_DepartID	IN	VARCHAR2,	--部门
	P_TerminalID	IN	VARCHAR2,	--终端
	P_CardID	IN	VARCHAR2,	--卡ID
	P_AccountType	IN	INTEGER,	--1.金额异动 3.积分异动 4.福豆异动
	P_Direct	IN	INTEGER,	--1 增加加   -1 减少
	P_Value		IN	NUMBER,		--异动值
	P_Value1	IN	NUMBER,		--本金异动（当类型是金额异动时有效）
	P_Value2	IN	NUMBER,		--增值异动（当类型是金额异动时有效）		
	P_BillType	IN	VARCHAR2,	--单据类型
	P_BillNo	IN	VARCHAR2,	--单据号
	P_BillDate	IN	DATE,		--单据日期
	P_ReasonID	IN 	VARCHAR2,	--异动原因
	P_Description	IN 	VARCHAR2,	--异动描述
	P_UserID	IN	VARCHAR2	--操作员
)
AS
-------------------------------------------------------------------
--名称：卡账户异动
--说明：
--参数：单据号，审核人
--返回：标志0=成功
--表：
--函数：
--调用存储过程：
--备注：
--创建者   : JW
--创建时间 : 2017-07-25
--修改记录：
-------------------------------------------------------------------
V_BreakPoint		VARCHAR2(255);
V_Err			INTEGER;
V_Msg			VARCHAR2(255);

V_Amount_Begin		NUMBER(18,4);
V_Amount1_Begin		NUMBER(18,4);
V_Amount2_Begin		NUMBER(18,4);
V_Point_Begin		NUMBER(18,4);
V_Bean_Begin		NUMBER(18,4);

V_Amount_End		NUMBER(18,4);
V_Amount1_End		NUMBER(18,4);
V_Amount2_End		NUMBER(18,4);
V_Point_End		NUMBER(18,4);
V_Bean_End		NUMBER(18,4);

V_CardNo		VARCHAR2(32);

V_AllPointChange	NUMBER(18,4);

V_Signature		VARCHAR2(64);

V_CompanyID1		VARCHAR2(32);	--卡所属公司
V_CompanyID2		VARCHAR2(32);	--资金出入公司


V_ID VARCHAR2(64);

V_Status		INTEGER;

V_RECHARGEMAX		NUMBER(18,4);
V_CARDTYPEID		VARCHAR2(32);

BEGIN
	V_BreakPoint:= 'SP_CRM_CardAccount_010';
	V_Err := -20001;
	
	V_Status := 0;
	
	IF P_BillType <> 'INIT' or (P_BillType = 'INIT' and P_Description = '再次导入') THEN
		BEGIN
			SELECT Signature,CardNo, Amount,Amount1,Amount2,ValidPoint,Bean,COMPANYID,STATUS,CARDTYPEID
			INTO V_Signature,V_CardNo,V_Amount_Begin,V_Amount1_Begin,V_Amount2_Begin,V_Point_Begin,V_Bean_Begin,V_CompanyID1,V_Status,V_CARDTYPEID
			FROM CRM_Card
			WHERE EID = P_EID and CardID = P_CardID;
		EXCEPTION WHEN NO_DATA_FOUND THEN		
			V_Msg := '卡ID不存在';
			Raise_Application_Error(V_Err, V_Msg);
		END;
		
		--0.检查签名是否正确
		IF V_Signature != F_CRM_GET_Signature(V_CardNo,V_Amount_Begin) THEN
			V_Msg := '卡异常，数据签名校验不通过，请检查数据是否被篡改';
			Raise_Application_Error(V_Err, V_Msg);		
		END IF;
	ELSE
		V_CardNo := P_BillNo;
		V_CARDTYPEID := P_TerminalID;
		V_Amount_Begin := 0;
		V_Amount1_Begin := 0;
		V_Amount2_Begin := 0;
		V_Point_Begin	:= 0;
		V_Bean_Begin	:= 0;
		
	END IF;
	
	V_CompanyID2 := V_CompanyID1;
	
	--1.更新卡余额
	IF P_AccountType = 1 AND P_BillType <> 'INIT' THEN
		
		IF P_Direct = -1 THEN
			IF V_Amount_Begin < P_Value THEN
				V_Msg := '卡内余额不足,现有'||V_Amount_Begin||',应扣'||P_Value;
				Raise_Application_Error(V_Err, V_Msg);
			END IF;
			IF V_Amount1_Begin < P_Value1 THEN
				V_Msg := '卡内(本金账户)余额不足,现有'||V_Amount1_Begin||',应扣'||P_Value1;
				Raise_Application_Error(V_Err, V_Msg);
			END IF;
			IF V_Amount2_Begin < P_Value2 THEN
				V_Msg := '卡内(赠送账户)余额不足,现有'||V_Amount2_Begin||',应扣'||P_Value2;
				Raise_Application_Error(V_Err, V_Msg);
			END IF;
		END IF;
		
		
		
		UPDATE CRM_Card SET Amount = Amount+P_Direct*P_Value,
				Amount1 = Amount1+P_Direct*P_Value1,
				Amount2 = Amount2+P_Direct*P_Value2,
				Signature = F_CRM_GET_Signature(CardNo,Amount+P_Direct*P_Value)
		WHERE EID=P_EID and CardID = P_CardID;	
		
		--空卡充值、或卡未发行前做余额调整，都要变更卡面额，否则发行的时候会报错（卡面额与本金不一致）
		IF P_BillType = 'CRM003' or V_STATUS < 2 THEN
				UPDATE CRM_Card SET FACEAMOUNT = Amount1
				WHERE EID=P_EID and CardID = P_CardID;
		END IF;	
				

		--卡退款，金额从业务发生的公司出
		IF P_BillType = 'CRM008' and P_Direct = -1 THEN
			V_COMPANYID2 := P_CompanyID;
		END IF;			
		
		--公众号充值，卡的资金是进入到公众号的		
		IF P_BillType = 'CRM008' or P_BillType = 'CRM009' THEN
			IF P_ChannelID is not null THEN
				BEGIN
					select COMPANYID into V_COMPANYID2
					from CRM_WXAPP where EID = P_EID and APPID = P_ChannelID;
				EXCEPTION WHEN NO_DATA_FOUND THEN		
					null;
				END;
			END IF;				
		END IF;			
						
									
	END IF;
	
	
	--消费支付	
	IF P_BillType = 'CRM016' AND P_Direct = -1 THEN
		IF P_AccountType = 1 THEN
			UPDATE CRM_Card SET PAYTIMES = PAYTIMES+1,
					PAYAMOUNT1 = PAYAMOUNT1+P_Direct*P_Value1*-1,
					PAYAMOUNT2 = PAYAMOUNT2+P_Direct*P_Value2*-1,
					LASTPAYTIME = SYSDATE					
			WHERE EID=P_EID and CardID = P_CardID;	
		END IF;
	END IF;							
	--充值	
	IF P_BillType = 'CRM009' AND P_Direct = 1 THEN
		IF P_AccountType = 1 THEN
			
			IF V_Status <> 4 THEN
				V_Msg := '卡非激活状态，不允许充值';
				Raise_Application_Error(V_Err, V_Msg);
			END IF;						
			
			UPDATE CRM_Card SET RECHTIMES = RECHTIMES+1,
					RECHAMOUNT1 = RECHAMOUNT1+P_Direct*P_Value1,
					RECHAMOUNT2 = RECHAMOUNT2+P_Direct*P_Value2,
					LASTRECHTIME = SYSDATE
			WHERE EID=P_EID and CardID = P_CardID;	
		END IF;
	END IF;							
	
	
	--去掉这个限制，导致的问题太多了。只有味多美要用
	--卡内金额不能超过限额
	--IF (P_BillType = 'CRM002' or P_BillType = 'CRM003' or P_BillType = 'CRM009') AND P_Direct = 1 AND P_AccountType = 1 THEN
	--	
	--	--RECHARGEMAX 当做卡内总余额来用
	--	BEGIN
	--		SELECT RECHARGEMAX INTO V_RECHARGEMAX
	--		  FROM CRM_CARDTYPE
	--		 WHERE EID = P_EID
	--		   AND CARDTYPEID = V_CARDTYPEID;
	--	EXCEPTION WHEN NO_DATA_FOUND THEN
	--		V_RECHARGEMAX := 0;
	--	END;					
	--	IF V_RECHARGEMAX > 0 THEN
	--		IF V_Amount_Begin + P_Direct*P_Value > V_RECHARGEMAX THEN
	--			V_Msg := '卡内余额将超出最大限额'||V_RECHARGEMAX;
	--			Raise_Application_Error(V_Err, V_Msg);				
	--		END IF;				
	--	END IF;					
	--END IF;			
	
	IF P_AccountType = 3 AND P_BillType <> 'INIT' THEN
		IF P_Direct = -1 THEN
			IF V_Point_Begin < P_Value THEN
				V_Msg := '卡内积分不足,现有'||V_Point_Begin||',应扣'||P_Value;
				Raise_Application_Error(V_Err, V_Msg);
			END IF;
		END IF;
		
		IF P_BillType = 'INIT' THEN	--初始导入，不异动累计积分
			V_AllPointChange := 0;
		ELSE			
			IF P_Direct = -1 THEN
				V_AllPointChange := 0;
			ELSE							
				V_AllPointChange := P_Direct*P_Value;
			END IF;
		END IF;
		IF P_Direct = 1 THEN
			UPDATE CRM_Card SET ValidPoint = ValidPoint+P_Direct*P_Value,
					ALLPOINT = ALLPOINT + V_AllPointChange,
					INTEGRATETIMES = INTEGRATETIMES + 1
			WHERE EID=P_EID and CardID = P_CardID;				
		ELSE	
			UPDATE CRM_Card SET ValidPoint = ValidPoint+P_Direct*P_Value,
					ALLPOINT = ALLPOINT + V_AllPointChange
			WHERE EID=P_EID and CardID = P_CardID
			  AND ValidPoint >= -1*P_Direct*P_Value;	 --有并发问题会到只积分扣成负数,所以加这个条件
			IF (SQL%ROWCOUNT = 0) OR (SQL%ROWCOUNT IS NULL) THEN
				V_Msg := '卡内积分不足';
				Raise_Application_Error(V_Err, V_BreakPoint|| '-' || V_Msg);
			END IF;

		END IF;
						
	END IF;
	
	IF P_AccountType = 4 AND P_BillType <> 'INIT' THEN
		IF P_Direct = -1 THEN
			IF V_Bean_Begin < P_Value THEN
				V_Msg := '卡内福豆不足,现有'||V_Bean_Begin||',应扣'||P_Value;
				Raise_Application_Error(V_Err, V_Msg);
			END IF;
		END IF;
		UPDATE CRM_Card SET Bean = Bean+P_Direct*P_Value
		WHERE EID=P_EID and CardID = P_CardID;								
	END IF;
	
	IF P_BillType <> 'INIT' THEN
		SP_CRM_UpdateCardLevel(
			P_EID,		--IN	VARCHAR2,	--企业ID
			P_CardID,	--IN	VARCHAR2	--卡ID
			P_BillType,
			P_BillNo
		);
	END IF;
		
		
	IF P_BillType <> 'INIT' THEN
		SELECT CardNo, Amount,Amount1,Amount2,ValidPoint,Bean
		INTO V_CardNo,V_Amount_End,V_Amount1_End,V_Amount2_End,V_Point_End,V_Bean_End
		FROM CRM_Card
		WHERE EID = P_EID and CardID = P_CardID;
	ELSE
		IF P_AccountType = 1 THEN
			V_Amount_End := P_Direct*P_Value;
			V_Amount1_End := P_Direct*P_Value1;
			V_Amount2_End := P_Direct*P_Value2;			
		END IF;			
		
		IF P_AccountType = 3 THEN
			V_Amount_End := 0;
			V_Amount1_End := 0;
			V_Amount2_End := 0;	
			
			V_Point_End := 	V_Point_Begin + P_Direct*P_Value;	
				
		END IF;			
		
		IF P_AccountType = 4 THEN
			V_Amount_End := 0;
			V_Amount1_End := 0;
			V_Amount2_End := 0;				
			V_Bean_End := 	P_Direct*P_Value;	
		END IF;			
		
	END IF;
	
	--2.生成异动
	V_ID := sys_guid();
	IF P_AccountType = 1 THEN
		INSERT INTO CRM_CardAccountChange(
			ID,		EID,		BILLNO,		BILLTYPE,	BILLDATE,
			CompanyID,	ShopID,		ChannelID,	EmployeeID,	DepartID,
			TerminalID,	AccountType,	CardID,		CardNo,		Direct,
			PreValue,	ChangeValue,	AftValue,	
			PreValue1,	ChangeValue1,	AftValue1,	
			PreValue2,	ChangeValue2,	AftValue2,				
			ReasonID,	Description,	Status,
			CREATEOPID,	CREATETIME,	LASTMODIOPID,	LastModiTime,	COMPANYID1,
			COMPANYID2,	CARDTYPEID
		)
		VALUES
		(
			V_ID,		P_EID,		P_BILLNO,	P_BILLTYPE,	P_BILLDATE,
			P_CompanyID,	P_ShopID,	P_ChannelID,	P_EmployeeID,	P_DepartID,
			P_TerminalID,	P_AccountType,	P_CardID,	V_CardNo,	P_Direct,
			V_Amount_Begin,	P_Value,	V_Amount_End,				
			V_Amount1_Begin,P_Value1,	V_Amount1_End,	
			V_Amount2_Begin,P_Value2,	V_Amount2_End,	
			P_ReasonID,	P_Description,	100,
			P_UserID,	SYSDATE,	P_UserID,	SYSDATE,	V_CompanyID1,
			V_COMPANYID2,	V_CARDTYPEID		
		);				
	END IF;

	
	IF P_AccountType = 3 THEN
		INSERT INTO CRM_CardAccountChange(
			ID,		EID,		BILLNO,		BILLTYPE,	BILLDATE,
			CompanyID,	ShopID,		ChannelID,	EmployeeID,	DepartID,
			TerminalID,	AccountType,	CardID,		CardNo,		Direct,
			PreValue,	ChangeValue,	AftValue,	
			PreValue1,	ChangeValue1,	AftValue1,	
			PreValue2,	ChangeValue2,	AftValue2,				
			ReasonID,	Description,	Status,
			CREATEOPID,	CREATETIME,	LASTMODIOPID,	LastModiTime,	COMPANYID1,
			COMPANYID2,	CARDTYPEID
		)
		VALUES
		(
			V_ID,		P_EID,		P_BILLNO,	P_BILLTYPE,	P_BILLDATE,
			P_CompanyID,	P_ShopID,	P_ChannelID,	P_EmployeeID,	P_DepartID,
			P_TerminalID,	P_AccountType,	P_CardID,	V_CardNo,	P_Direct,
			V_Point_Begin,	P_Value,	V_Point_End,	
			V_Amount1_Begin,P_Value1,	V_Amount1_End,	
			V_Amount2_Begin,P_Value2,	V_Amount2_End,	
			P_ReasonID,	P_Description,	100,
			P_UserID,	SYSDATE,	P_UserID,	SYSDATE,	V_CompanyID1,
			V_COMPANYID2,	V_CARDTYPEID		
		);				
	END IF;
	
		
	IF P_AccountType = 4 THEN
		INSERT INTO CRM_CardAccountChange(
			ID,		EID,		BILLNO,		BILLTYPE,	BILLDATE,
			CompanyID,	ShopID,		ChannelID,	EmployeeID,	DepartID,
			TerminalID,	AccountType,	CardID,		CardNo,		Direct,
			PreValue,	ChangeValue,	AftValue,	
			PreValue1,	ChangeValue1,	AftValue1,	
			PreValue2,	ChangeValue2,	AftValue2,				
			ReasonID,	Description,	Status,
			CREATEOPID,	CREATETIME,	LASTMODIOPID,	LastModiTime,	COMPANYID1,
			COMPANYID2,	CARDTYPEID
		)
		VALUES
		(
			V_ID,		P_EID,		P_BILLNO,	P_BILLTYPE,	P_BILLDATE,
			P_CompanyID,	P_ShopID,	P_ChannelID,	P_EmployeeID,	P_DepartID,
			P_TerminalID,	P_AccountType,	P_CardID,	V_CardNo,	P_Direct,
			V_Bean_Begin,	P_Value,	V_Bean_End,	
			V_Amount1_Begin,P_Value1,	V_Amount1_End,	
			V_Amount2_Begin,P_Value2,	V_Amount2_End,	
			P_ReasonID,	P_Description,	100,
			P_UserID,	SYSDATE,	P_UserID,	SYSDATE,	V_CompanyID1,
			V_COMPANYID2,	V_CARDTYPEID		
		);				
	END IF;
		
	
EXCEPTION WHEN OTHERS THEN	
	Raise_Application_Error(-20001, v_BreakPoint || '-' || SQLERRM);    
END;
