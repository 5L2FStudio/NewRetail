create or replace PROCEDURE "SP_CRM_CARDSTATUS" (
	P_EID		IN	VARCHAR2,	--企业ID
	P_CompanyID	IN	VARCHAR2,	--公司
	P_ShopID	IN	VARCHAR2,	--门店
	P_ChannelID	IN	VARCHAR2,	--渠道
	P_EmployeeID	IN	VARCHAR2,	--员工
	P_DepartID	IN	VARCHAR2,	--部门
	P_TerminalID	IN	VARCHAR2,	--终端
	P_CardID	IN	VARCHAR2,	--卡ID
	P_OprType	IN	INTEGER,	--1. 生成  2.发行 3.领出 4.激活 5.挂失  6.解挂  7.冻结  8.解冻  9.被换卡 10.注销 11.回收 12.调整有效期 98.写卡 99.其他 >100变更卡信息
	P_BillType	IN	VARCHAR2,	--单据类型
	P_BillNo	IN	VARCHAR2,	--单据号
	P_BillDate	IN	DATE,		--单据日期
	P_Description	IN 	VARCHAR2,	--异动描述
	P_UserID	IN	VARCHAR2	--操作员
)
AS
-------------------------------------------------------------------
--名称：卡信息或状态异动
--操作：  1.生成 2.发行 3.领出 4.激活 5.挂失 6.解挂 7.冻结 8.解冻   9.被换卡 10.注销 11.回收 12.调整有效期 14.重置密码 98.写卡 99.其他
--卡状态：1.生成 2.发行 3.领出 4.激活 5.挂失 6.冻结 7.注销 8.被换卡 9.回收 
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

V_Status_Begin		INTEGER;
V_Status_END		INTEGER;
V_Status_OLD		INTEGER;

V_CardNo		VARCHAR2(32);
V_MemberID		VARCHAR2(64);
V_MAINCARD		INTEGER;

V_Signature		VARCHAR2(64);

V_ID VARCHAR2(64);

BEGIN
	V_BreakPoint:= 'SP_CRM_CardAccount_010';
	V_Err := -20001;
	
	IF P_OprType = 99 THEN		
		--不涉及到状态变更的别写记录，否则消费后挂失的卡，因为卡状态已经变更撤销不了消费
		--消费后挂失的卡也要能撤销交易
		return;
		
	END IF;
	
	BEGIN
		SELECT Signature,CardNo, Status,MemberID,OLDSTATUS,MAINCARD
		INTO V_Signature,V_CardNo,V_Status_Begin,V_MemberID,V_Status_OLD,V_MAINCARD
		FROM CRM_Card
		WHERE EID = P_EID and CardID = P_CardID;
	EXCEPTION WHEN NO_DATA_FOUND THEN		
		V_Msg := '卡ID不存在';
		Raise_Application_Error(V_Err, V_Msg);
	END;
	
	
	--1.更新卡余额
	IF P_OprType = 1 THEN		
		V_Status_END := P_OprType;	
	END IF;	
	IF P_OprType = 2 THEN		
		V_Status_END := P_OprType;	
	END IF;	
	IF P_OprType = 3 THEN		
		V_Status_END := P_OprType;	
	END IF;	
	IF P_OprType = 4 THEN		
		V_Status_END := P_OprType;	
	END IF;	
	IF P_OprType = 5 THEN		
		V_Status_END := P_OprType;	
	END IF;	
	IF P_OprType = 6 THEN		
		V_Status_END := V_Status_OLD;	
	END IF;	
	IF P_OprType = 7 THEN		
		V_Status_END := 6;	
	END IF;	
	IF P_OprType = 8 THEN		
		V_Status_END := V_Status_OLD;	
	END IF;	
	IF P_OprType = 9 THEN		
		V_Status_END := 8;	
	END IF;	
	IF P_OprType = 10 THEN		
		V_Status_END := 7;	
	END IF;	
	IF P_OprType = 11 THEN		
		V_Status_END := 9;	
	END IF;	
	IF P_OprType >= 12 THEN		
		IF P_OprType = 20 THEN	--绑卡后也激活，因为有的场景是允许绑卡方式添加会员卡的（新美心汉得）
			V_Status_END := 4;
		ELSE	
			V_Status_END := V_Status_BEGIN;
		END IF;
	END IF;
	
	IF V_Status_Begin = 5 or V_Status_Begin = 6 or 	V_Status_Begin = 7 or V_Status_Begin = 8 or V_Status_Begin = 9 THEN
		IF V_Status_END = 5 THEN
			V_Msg := '该状态下的卡不允许挂失';
			Raise_Application_Error(V_Err, V_Msg);
		END IF;			
	END IF;		

	IF P_OprType = 6 THEN
		IF V_Status_Begin <> 5 THEN
			V_Msg := '非挂失状态下的卡不需要解挂';
			Raise_Application_Error(V_Err, V_Msg);
		END IF;			
	END IF;		


	IF V_Status_Begin = 5 or V_Status_Begin = 6 or 	V_Status_Begin = 7 or V_Status_Begin = 8 or V_Status_Begin = 9 THEN
		IF V_Status_END = 6 THEN
			V_Msg := '该状态下的卡不允许冻结';
			Raise_Application_Error(V_Err, V_Msg);
		END IF;			
	END IF;		
	
	IF P_OprType = 8 THEN
		IF V_Status_Begin <> 6 THEN
			V_Msg := '非冻结状态下的卡不需要解冻';
			Raise_Application_Error(V_Err, V_Msg);
		END IF;			
	END IF;		

	
	
	IF P_OprType = 5 OR P_OprType = 7 THEN
		UPDATE CRM_Card SET Status = V_Status_END,OLDSTATUS = V_Status_Begin
		WHERE EID=P_EID and CardID = P_CardID;								
		
	ELSE	
		IF V_Status_END <> V_Status_Begin THEN
			UPDATE CRM_Card SET Status = V_Status_END
			WHERE EID=P_EID and CardID = P_CardID;		
		END IF;
	END IF;	
	
	IF P_OprType = 2 THEN
		UPDATE CRM_Card SET ISSUEDATE = TRUNC(SYSDATE)
		WHERE EID=P_EID and CardID = P_CardID;								
	END IF;			

	IF P_OprType = 4 THEN
		UPDATE CRM_Card SET ACTIVEDATE = TRUNC(SYSDATE)
		WHERE EID=P_EID and CardID = P_CardID;								
	END IF;			
	
	IF V_Status_END = 7 AND V_MAINCARD = 1 THEN
		V_Msg := '会员的主卡不允许注销';
		Raise_Application_Error(V_Err, V_Msg);
	END IF;		

	--ID1015134 卡注销时手机号和所属会员别清 状态为7的，别清手机号和会员号
	--IF V_Status_END = 7 or V_Status_END = 9 THEN
	IF V_Status_END = 9 THEN	
		UPDATE CRM_Card SET MEMBERID = '',MOBILE = ''
		WHERE EID=P_EID and CardID = P_CardID;								
	END IF;		

	IF V_Status_END = 8 THEN
		UPDATE CRM_Card SET MEMBERID = ''
		WHERE EID=P_EID and CardID = P_CardID;								
	END IF;		

	IF P_OprType = 98 THEN
		UPDATE CRM_Card SET CARDMADED = 1,LASTMODITIME = SYSDATE,LASTMODIOPID = P_UserID
		WHERE EID=P_EID and CardID = P_CardID;								
	END IF;			


	--2.生成异动
	V_ID := sys_guid();
	INSERT INTO CRM_CardStatusChange(
		ID,		EID,		BILLNO,		BILLTYPE,	BILLDATE,
		CompanyID,	ShopID,		ChannelID,	EmployeeID,	DepartID,
		MEMBERID,	CardID,		CardNo,		OprType,
		InfoBef,	InfoAft,	Description,	Status,
		CREATEOPID,	CREATETIME,	LastModiOpid,	LastModiTime
	)
	VALUES
	(
		V_ID,		P_EID,		P_BILLNO,	P_BILLTYPE,	P_BILLDATE,
		P_CompanyID,	P_ShopID,	P_ChannelID,	P_EmployeeID,	P_DepartID,
		V_MemberID,	P_CardID,	V_CardNo,	P_OprType,
		V_Status_Begin, V_Status_End,	P_Description,	100,
		P_UserID,	SYSDATE,	P_UserID,	SYSDATE		
	);				
	

		
	
EXCEPTION WHEN OTHERS THEN	
	Raise_Application_Error(-20001, v_BreakPoint || '-' || SQLERRM);    
END;
