create or replace PROCEDURE "SP_CRM_CARDCONSUME_CHECK" (
	P_EID		IN	VARCHAR2,	--企业ID
	P_BillNo	IN	VARCHAR2,	--单据号
	P_Checker	IN	VARCHAR2	--审核人
)
AS
-------------------------------------------------------------------
--名称：卡消费过程
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
--//20220609-002-[1026497]-01134Grace：累計消費金額改統計AddConsumAmt
--//20220609-003-[1026497]-01134Grace：統計累計消費金額時排除BusinessType<>4(非POS訂轉銷)
--//20230308-001-[1030790]-01134Grace：訂轉銷也要算累計消費金額(因支付多少可開發票金額則累計多少消費金額)
--//20230410-001-[1032384]-01134Grace：銷退要收回獎勵(含下單禮/升等禮..)呼叫SP_CRM_DOAWARD_CANCEL應傳入CRM_CARDCONSUME.BILLNO
--//20230410-002-[1032384]-01134Grace：銷退找舊單來源改抓CRM_CARDCONSUME(原為CRM_CONSUME)
-------------------------------------------------------------------
V_BreakPoint			VARCHAR2(255);
V_Err				INTEGER;
V_Msg				VARCHAR2(255);


V_BillType			VARCHAR2(32);

V_CompanyID			VARCHAR2(50);
V_ShopID			VARCHAR2(50);
V_ChannelID			VARCHAR2(50);
V_DepartID			VARCHAR2(50);
V_EmployeeID			VARCHAR2(50);
V_TerminalID			VARCHAR2(50);


V_Amount			NUMBER(18,4);

V_UsePoint			NUMBER(18,4);
V_GetPoint			NUMBER(18,4);


V_UseBean			NUMBER(18,4);
V_GetBean			NUMBER(18,4);

V_CardAmount			NUMBER(18,4);
V_CardAmount1			NUMBER(18,4);
V_CardAmount2			NUMBER(18,4);

V_CardAmount_end		NUMBER(18,4);
V_CardAmount1_end		NUMBER(18,4);
V_CardAmount2_end		NUMBER(18,4);


V_CardPoint			NUMBER(18,4);

V_CardPoint_End			NUMBER(18,4);


V_CardBean			NUMBER(18,4);
V_CardBean_END			NUMBER(18,4);

V_CardID			INTEGER;
V_CARDNO			VARCHAR2(50);
V_Status			INTEGER;



V_Refund			INTEGER;

V_BusinessType			VARCHAR2(32);
V_BusinessTypeCount			INTEGER;

V_SourceBillNo			VARCHAR2(50);
V_RefundAmount			NUMBER(18,4);

V_SourceAmount			NUMBER(18,4);
V_SourceAmount1			NUMBER(18,4);
V_SourceAmount2			NUMBER(18,4);

V_DealType			VARCHAR2(32);
V_DealAmount1			NUMBER(18,4);
V_DealAmount2			NUMBER(18,4);


V_Direct			INTEGER;
V_Discription			VARCHAR2(50);

V_OrderAmount			NUMBER(18,4);
V_PointAmount			NUMBER(18,4);

V_Company_pay			VARCHAR2(32);

V_MemberID			VARCHAR2(32);
V_ActionKey			VARCHAR2(32);
V_ACTIONMSG			VARCHAR2(1000);

V_POINTCALCULATE		INTEGER;
V_POINTEXPECTDATE		DATE;


V_BRANCHTYPE 			INTEGER;
V_BRANCHID 			VARCHAR2(50);   
V_CARDTYPEID			VARCHAR2(50);	


V_BillNO_TEMP			VARCHAR2(50);
V_THIRDBILLTYPE		VARCHAR2(50);
V_THIRDBILLNO			VARCHAR2(50);


V_ADDCONSUMAMT NUMBER(18,4); --//20220609-002-[1026497]-01134Grace：累計消費金額改統計AddConsumAmt

BEGIN
	V_BreakPoint:= 'SP_CRM_CardConsume_Check_010';
	V_Err := -20001;
		
	V_BusinessType :='1';
	V_BusinessTypeCount :=0;

	BEGIN
		SELECT BillType,CardID,CardNo,Amount,UsePoint,GetPoint,UseBean,GetBean,Refund,RefundAmount,nvl(SourceBillNo,''),
			CompanyID,ShopID,ChannelID,DepartID,EmployeeID,TerminalID,OrderAmount,PointAmount,
			NVL(POINTCALCULATE,1),NVL(POINTEXPECTDATE,TRUNC(SYSDATE)), AddConsumAmt --//20220609-001-[1026497]-01134Grace：增加AddConsumAmt(可累計消費金額)欄位
		INTO V_BillType,V_CardID,V_CardNo,V_Amount,V_UsePoint,V_GetPoint,V_UseBean,V_GetBean,V_Refund,V_RefundAmount,V_SourceBillNo,
			V_CompanyID,V_ShopID,V_ChannelID,V_DepartID,V_EmployeeID,V_TerminalID,V_OrderAmount,V_PointAmount,
			V_POINTCALCULATE,V_POINTEXPECTDATE, V_ADDCONSUMAMT --//20220609-001-[1026497]-01134Grace：增加AddConsumAmt(可累計消費金額)欄位
		FROM CRM_CardConsume
		WHERE EID=P_EID
		AND BillNo = P_BillNo;
	EXCEPTION WHEN NO_DATA_FOUND THEN	
		V_Msg := '单据[' || P_BillNo || ']不存在';
		Raise_Application_Error(V_Err, V_BreakPoint|| '-' || V_Msg);
	END;
	
	SELECT Amount,Amount1,Amount2,ValidPoint,Bean,Status,CompanyID,MemberID,CardTypeID
	INTO V_CardAmount,V_CardAmount1,V_CardAmount2,V_CardPoint,V_CardBean,V_Status,V_Company_pay,V_MemberID,V_CARDTYPEID
	FROM CRM_Card
	WHERE EID = P_EID and CardID = V_CardID;
	
	IF V_Status <> 4 AND V_Amount > 0 AND V_Refund = 0 THEN
		V_Msg := '卡非激活状态，不可消费';
		Raise_Application_Error(V_Err, V_Msg);				
	END IF;

	UPDATE CRM_CardConsume SET Status = 100, CHECKOPID = P_Checker,CHECKTIME = SYSDATE,CompanyID2 = V_Company_pay
	WHERE EID=P_EID
	AND BillNo = P_BillNo 
	AND Status<=0;
	IF (SQL%ROWCOUNT = 0) OR (SQL%ROWCOUNT IS NULL) THEN
		V_Msg := '单据[' || P_BillNo || ']非可生效状态';
		Raise_Application_Error(V_Err, V_BreakPoint|| '-' || V_Msg);
	END IF;


	--卡状态异动			
	IF V_Refund = 1 THEN
		IF V_Status <> 4 THEN			
			IF V_CardAmount > 0 THEN
				V_Msg := '警告：卡内有余额['||V_CardNo||']，不能用做退款卡发放给顾客';
				Raise_Application_Error(V_Err, V_BreakPoint|| '-' || V_Msg);
			END IF;				
			
			SP_CRM_CardStatus(
				P_EID,		--IN	VARCHAR2,	--企业ID
				V_CompanyID,	--IN	VARCHAR2,	--公司
				V_ShopID,	--IN	VARCHAR2,	--门店
				V_ChannelID,	--IN	VARCHAR2,	--渠道
				V_EmployeeID,	--IN	VARCHAR2,	--员工
				V_DepartID,	--IN	VARCHAR2,	--部门
				'',		--IN	VARCHAR2,	--终端
				V_CardID,	--IN	VARCHAR2,	--卡ID
				4,		--IN	INTEGER,	--1. 生成  2.发行 3.领出 4.激活 5.挂失  6.解挂  7.冻结  8.解冻  9.被换卡 10.注销 11.回收 12.调整有效期 99.其他
				V_BillType,	--IN	VARCHAR2,	--单据类型
				P_BillNo,	--IN	VARCHAR2,	--单据号
				TRUNC(SYSDATE),	--IN	DATE,		--单据日期
				'退款发卡激活',	--IN 	VARCHAR2,	--异动描述
				P_Checker	--IN	VARCHAR2	--操作员
			);
						
			
   			--减少卡库存
   			IF V_ShopID is null THEN
   				V_BRANCHTYPE := 1;
   				V_BRANCHID := V_CompanyID;   				
   			ELSE	
   				V_BRANCHTYPE := 2;
   				V_BRANCHID := V_ShopID;   				
			END IF;   	
			
			IF F_CRM_Stock_Check(P_EID,V_BillType,V_BranchType,V_BranchID,1,V_CardNo) = 0 THEN
				V_Msg := '卡号'|| V_CardNo || '，库存不在本机构，请先入库';
				Raise_Application_Error(V_Err, V_Msg);
			END IF;				
						
			SP_CRM_STOCK(
				P_EID,			--IN	VARCHAR2,	--企业ID
				V_BRANCHTYPE,		--IN	INTEGER,	--机构类型 1=公司 2=门店
				V_BRANCHID,		--IN	VARCHAR2,	--机构编号
				V_BillType,		--IN	VARCHAR2,	--单据类型
				P_BillNo,		--IN	VARCHAR2,	--单据号
				1,			--IN	INTEGER,	--单内行号
				TRUNC(SYSDATE),		--IN	DATE,		--单据日期
				1,			--IN	INTEGER,	--类型 1=卡 2=券
				V_CardTypeID,		--IN	VARCHAR2,	--卡券类型编号
				-1,			--IN	INTEGER,	--异动方向 -1=减少 1=增加
				V_Amount,		--IN	NUMBER,		--面额
				1,			--IN	NUMBER,		--数量
				'退款到卡上',		--IN 	VARCHAR2,	--异动原因
				'退款到卡上',		--IN 	VARCHAR2,	--异动描述
				P_Checker		--IN	VARCHAR2	--操作员
			);
			
			UPDATE CRM_CARD SET 
					BRANCHTYPE = 3,
					BRANCHID = ''
			WHERE EID = P_EID
			  AND CARDID = V_CardID;							

			
		ELSE
			--卡状态异动		
			SP_CRM_CardStatus(
				P_EID,		--IN	VARCHAR2,	--企业ID
				V_CompanyID,	--IN	VARCHAR2,	--公司
				V_ShopID,	--IN	VARCHAR2,	--门店
				V_ChannelID,	--IN	VARCHAR2,	--渠道
				V_EmployeeID,	--IN	VARCHAR2,	--员工
				V_DepartID,	--IN	VARCHAR2,	--部门
				'',		--IN	VARCHAR2,	--终端
				V_CardID,	--IN	VARCHAR2,	--卡ID
				99,		--IN	INTEGER,	--1. 生成  2.发行 3.领出 4.激活 5.挂失  6.解挂  7.冻结  8.解冻  9.被换卡 10.注销 11.回收 12.调整有效期 99.其他
				V_BillType,	--IN	VARCHAR2,	--单据类型
				P_BillNo,	--IN	VARCHAR2,	--单据号
				TRUNC(SYSDATE),	--IN	DATE,		--单据日期
				'退款到卡上',	--IN 	VARCHAR2,	--异动描述
				P_Checker	--IN	VARCHAR2	--操作员
			);
	
		END IF;	
	ELSE
		--卡状态异动		
		SP_CRM_CardStatus(
			P_EID,		--IN	VARCHAR2,	--企业ID
			V_CompanyID,	--IN	VARCHAR2,	--公司
			V_ShopID,	--IN	VARCHAR2,	--门店
			V_ChannelID,	--IN	VARCHAR2,	--渠道
			V_EmployeeID,	--IN	VARCHAR2,	--员工
			V_DepartID,	--IN	VARCHAR2,	--部门
			'',		--IN	VARCHAR2,	--终端
			V_CardID,	--IN	VARCHAR2,	--卡ID
			99,		--IN	INTEGER,	--1. 生成  2.发行 3.领出 4.激活 5.挂失  6.解挂  7.冻结  8.解冻  9.被换卡 10.注销 11.回收 12.调整有效期 99.其他
			V_BillType,	--IN	VARCHAR2,	--单据类型
			P_BillNo,	--IN	VARCHAR2,	--单据号
			TRUNC(SYSDATE),	--IN	DATE,		--单据日期
			'退款到卡上',	--IN 	VARCHAR2,	--异动描述
			P_Checker	--IN	VARCHAR2	--操作员
		);
				
	END IF;

	select count(BILLNO) into V_BusinessTypeCount
	from CRM_CONSUME where eid=P_EID and BILLNO=(select BILLNO from CRM_CONSUME_CARD where eid=P_EID and CARDBILLNO=P_BillNo);
	
	if V_BusinessTypeCount=1 then
		select BUSINESSTYPE into V_BusinessType
		from CRM_CONSUME where eid=P_EID and BILLNO=(select BILLNO from CRM_CONSUME_CARD where eid=P_EID and CARDBILLNO=P_BillNo);
	end if;
	



	--更新卡累计消费金额
	IF V_Refund = 1 THEN
		V_Direct := -1;
	ELSE
		V_Direct := 1;
	END IF;
	
	IF V_ADDCONSUMAMT <> 0 THEN --20230410改：原為V_OrderAmount <> 0 --//20230308-001-[1030790]-01134Grace：訂轉銷也要算累計消費金額(因支付多少可開發票金額則累計多少消費金額)，原有 and V_BusinessType<>'2' and V_BusinessType<>'4' THEN --//20220609-003-[1026497]-01134Grace：統計累計消費金額時排除BusinessType<>4(非POS訂轉銷)
		--//20220609-001-[1026497]-01134Grace：累計消費金額改統計AddConsumAmt──────────────────────────────────┐
		UPDATE CRM_Card SET CONAMOUNT = CONAMOUNT + V_ADDCONSUMAMT, --原V_ADDCONSUMAMT為V_Direct * V_OrderAmount
		--//20220609-001-[1026497]-01134Grace：累計消費金額改統計AddConsumAmt──────────────────────────────────┘
					CONTIMES = CONTIMES + V_Direct,
					LASTCONTIME = SYSDATE
		WHERE EID = P_EID and CardID = V_CardID;
	END IF;		



	IF V_Amount <> 0 THEN
		IF V_Refund = 0 THEN
			IF V_CardAmount < V_Amount THEN
				V_Msg := '卡内余额不足';
				Raise_Application_Error(V_Err, V_Msg);				
			END IF;
			
		END IF;
	
		IF V_Refund = 1 THEN
			IF V_SourceBillNo is not null  THEN				
				BEGIN
					SELECT Amount,Amount1,Amount2,NVL(RefundAmount,0)
					INTO V_SourceAmount,V_SourceAmount1,V_SourceAmount2,V_RefundAmount
					FROM CRM_CardConsume
					WHERE EID = P_EID and BillNo = V_SourceBillNo;
				EXCEPTION 
				WHEN NO_DATA_FOUND THEN		
					V_Msg := '原交易单号'||V_SourceBillNo||'不存在';
					Raise_Application_Error(V_Err, V_Msg);					
				END;
				
				--去掉，券退卡上的情况就超过原交易金额了
				--IF V_SourceAmount-V_RefundAmount < V_Amount THEN
				--	V_Msg := '退款金额不能超过原交易金额';
				--	Raise_Application_Error(V_Err, V_Msg);					
				--END IF;	
				
				UPDATE CRM_CardConsume SET RefundAmount = nvl(V_RefundAmount,0) + V_Amount
				WHERE EID = P_EID and BillNo = V_SourceBillNo;
				
			ELSE
				V_SourceAmount := V_Amount;
				V_SourceAmount1 := V_Amount;
				V_SourceAmount2 := 0;
				V_RefundAmount := 0;				
			END IF;			
		END IF;
		
		
		
		--消费 根据参数判断 1-先扣本金 2-先扣赠送 3-等比例扣减
		--V_DealType := F_CRM_GetParam(P_EID,'PAYSORT');		
		BEGIN
			SELECT TO_CHAR(NVL(PAYSORT,0)) INTO V_DealType FROM CRM_CARDTYPE WHERE EID = P_EID AND CARDTYPEID = V_CARDTYPEID; 
		EXCEPTION WHEN NO_DATA_FOUND THEN
			V_DealType := '1';
		END;
		
		IF V_DealType is null THEN
			V_DealType := '1';
		END IF;					
		IF V_Refund = 1 THEN
			IF V_Amount = V_SourceAmount THEN
				V_DealAmount1 := V_SourceAmount1;
				V_DealAmount2 := V_SourceAmount2;
			ELSE
				IF V_DealType = '1' THEN
					IF V_SourceAmount1 >= V_Amount THEN
						V_DealAmount1 := V_Amount;
						V_DealAmount2 := 0;
					ELSE
						V_DealAmount1 := V_SourceAmount1;
						V_DealAmount2 := V_Amount - V_DealAmount1;								
					END IF;			
				END IF;		
				IF V_DealType = '2' THEN
					IF V_SourceAmount2 >= V_Amount THEN
						V_DealAmount1 := 0;
						V_DealAmount2 := V_Amount;
					ELSE
						V_DealAmount1 := V_Amount - V_SourceAmount2;
						V_DealAmount2 := V_SourceAmount2;
					END IF;			
				END IF;
				IF V_DealType = '3' THEN
					
					IF V_SourceAmount = 0 THEN												
						V_DealAmount1 := V_Amount;
						V_DealAmount2 := V_Amount - V_DealAmount1;										
					ELSE										
						V_DealAmount1 := round(V_Amount * V_SourceAmount1 / V_SourceAmount,2);
						IF V_DealAmount1 > V_Amount THEN
							V_DealAmount1 := V_Amount;
						END IF;	
						V_DealAmount2 := V_Amount - V_DealAmount1;				
					END IF;	
				END IF;							
			END IF;				
		ELSE			
			IF V_DealType = '1' THEN
				IF V_CardAmount1 >= V_Amount THEN
					V_DealAmount1 := V_Amount;
					V_DealAmount2 := 0;
				ELSE
					V_DealAmount1 := V_CardAmount1;
					V_DealAmount2 := V_Amount - V_DealAmount1;								
				END IF;			
			END IF;		
			IF V_DealType = '2' THEN
				IF V_CardAmount2 >= V_Amount AND V_Amount > 0 THEN
					V_DealAmount1 := 0;
					V_DealAmount2 := V_Amount;
				ELSE
					V_DealAmount1 := V_Amount - V_CardAmount2;
					V_DealAmount2 := V_CardAmount2;
				END IF;			
			END IF;
			IF V_DealType = '3' THEN
				
				V_DealAmount1 := round(V_Amount * V_CardAmount1 / V_CardAmount,2);
				V_DealAmount2 := V_Amount - V_DealAmount1;				
			END IF;
		END IF;		
		
		UPDATE CRM_CardConsume SET Amount1 = V_DealAmount1,
					Amount2 = V_DealAmount2	
		WHERE EID=P_EID
		AND BillNo = P_BillNo;
		
	
		
		V_Direct := -1;
		V_Discription := '消费';
		IF V_Refund = 1 THEN
			V_Direct := 1;
			V_Discription := '消费退款';
		END IF;

		
		IF V_DealAmount1 <> 0 OR V_DealAmount2 <> 0 THEN
			SP_CRM_CardAccount(
				P_EID,		--IN	VARCHAR2,	--企业ID
				V_CompanyID,	--IN	VARCHAR2,	--公司
				V_ShopID,	--IN	VARCHAR2,	--门店
				V_ChannelID,	--IN	VARCHAR2,	--渠道
				V_EmployeeID,	--IN	VARCHAR2,	--员工
				V_DepartID,	--IN	VARCHAR2,	--部门
				V_TerminalID,	--IN	VARCHAR2,	--终端
				V_CardID,	--IN	VARCHAR2,	--卡ID
				1,		--IN	INTEGER,	--1.金额异动 3.积分异动 4.福豆异动
				V_Direct,	--IN	INTEGER,	--1 增加加   -1 减少
				V_DealAmount1+V_DealAmount2,	--IN	NUMBER,		--异动值	
				V_DealAmount1,	--IN	NUMBER,		--本金异动
				V_DealAmount2,	--IN	NUMBER,		--赠送异动					
				V_BillType,	--IN	VARCHAR2,	--单据类型
				P_BillNo,	--IN	VARCHAR2,	--单据号
				TRUNC(SYSDATE),	--IN	DATE,		--单据日期
				'',		--IN 	VARCHAR2,	--异动原因
				V_Discription,	--IN 	VARCHAR2	--异动描述
				P_Checker	--IN	VARCHAR2	--操作员
			);			
		END IF;

	END IF;		
	
	IF V_UsePoint <> 0 THEN
		V_Direct := -1;
		V_Discription := '消费';
		IF V_Refund = 1 THEN
			V_Direct := 1;
			V_Discription := '消费退款';
		END IF;
		
			SP_CRM_CardAccount(
				P_EID,		--IN	VARCHAR2,	--企业ID
				V_CompanyID,	--IN	VARCHAR2,	--公司
				V_ShopID,	--IN	VARCHAR2,	--门店
				V_ChannelID,	--IN	VARCHAR2,	--渠道
				V_EmployeeID,	--IN	VARCHAR2,	--员工
				V_DepartID,	--IN	VARCHAR2,	--部门
				V_TerminalID,	--IN	VARCHAR2,	--终端
				V_CardID,	--IN	VARCHAR2,	--卡ID
				3,		--IN	INTEGER,	--1.金额异动 3.积分异动 4.福豆异动
				V_Direct,	--IN	INTEGER,	--1 增加加   -1 减少
				V_UsePoint,	--IN	NUMBER,		--异动值	
				0,		--IN	NUMBER,		--本金异动
				0,		--IN	NUMBER,		--赠送异动					
				V_BillType,	--IN	VARCHAR2,	--单据类型
				P_BillNo,	--IN	VARCHAR2,	--单据号
				TRUNC(SYSDATE),	--IN	DATE,		--单据日期
				'',		--IN 	VARCHAR2,	--异动原因
				V_Discription,	--IN 	VARCHAR2	--异动描述
				P_Checker	--IN	VARCHAR2	--操作员
			);				
	END IF;

	
	IF V_GetPoint <> 0 and V_POINTCALCULATE = 1 and TRUNC(V_POINTEXPECTDATE) <= TRUNC(SYSDATE) THEN
		V_Direct := 1;
		V_Discription := '消费';
		IF V_Refund = 1 THEN
			V_Direct := -1;
			V_Discription := '消费退款';
		END IF;
		
			SP_CRM_CardAccount(
				P_EID,		--IN	VARCHAR2,	--企业ID
				V_CompanyID,	--IN	VARCHAR2,	--公司
				V_ShopID,	--IN	VARCHAR2,	--门店
				V_ChannelID,	--IN	VARCHAR2,	--渠道
				V_EmployeeID,	--IN	VARCHAR2,	--员工
				V_DepartID,	--IN	VARCHAR2,	--部门
				V_TerminalID,	--IN	VARCHAR2,	--终端
				V_CardID,	--IN	VARCHAR2,	--卡ID
				3,		--IN	INTEGER,	--1.本金异动  2.增值异动 3.积分异动 4.福豆异动
				V_Direct,	--IN	INTEGER,	--1 增加加   -1 减少
				V_GetPoint,	--IN	NUMBER,		--异动值	
				0,		--IN	NUMBER,		--本金异动
				0,		--IN	NUMBER,		--赠送异动					
				V_BillType,	--IN	VARCHAR2,	--单据类型
				P_BillNo,	--IN	VARCHAR2,	--单据号
				TRUNC(SYSDATE),	--IN	DATE,		--单据日期
				'',		--IN 	VARCHAR2,	--异动原因
				V_Discription,	--IN 	VARCHAR2	--异动描述
				P_Checker	--IN	VARCHAR2	--操作员
			);				
	END IF;
	
	IF V_UseBean <> 0 THEN
		V_Direct := -1;
		V_Discription := '消费';
		IF V_Refund = 1 THEN
			V_Direct := 1;
			V_Discription := '消费退款';
		END IF;
		
			SP_CRM_CardAccount(
				P_EID,		--IN	VARCHAR2,	--企业ID
				V_CompanyID,	--IN	VARCHAR2,	--公司
				V_ShopID,	--IN	VARCHAR2,	--门店
				V_ChannelID,	--IN	VARCHAR2,	--渠道
				V_EmployeeID,	--IN	VARCHAR2,	--员工
				V_DepartID,	--IN	VARCHAR2,	--部门
				V_TerminalID,	--IN	VARCHAR2,	--终端
				V_CardID,	--IN	VARCHAR2,	--卡ID
				4,		--IN	INTEGER,	--1.本金异动  2.增值异动 3.积分异动 4.福豆异动
				V_Direct,	--IN	INTEGER,	--1 增加加   -1 减少
				V_UseBean,		--IN	NUMBER,		--异动值	
				0,		--IN	NUMBER,		--本金异动
				0,		--IN	NUMBER,		--赠送异动					
				V_BillType,	--IN	VARCHAR2,	--单据类型
				P_BillNo,	--IN	VARCHAR2,	--单据号
				TRUNC(SYSDATE),	--IN	DATE,		--单据日期
				'',		--IN 	VARCHAR2,	--异动原因
				V_Discription,	--IN 	VARCHAR2	--异动描述
				P_Checker	--IN	VARCHAR2	--操作员
			);				
	END IF;
	
	IF V_GetBean <> 0 THEN
		V_Direct := 1;
		V_Discription := '消费';
		IF V_Refund = 1 THEN
			V_Direct := -1;
			V_Discription := '消费退款';
		END IF;
		
			SP_CRM_CardAccount(
				P_EID,		--IN	VARCHAR2,	--企业ID
				V_CompanyID,	--IN	VARCHAR2,	--公司
				V_ShopID,	--IN	VARCHAR2,	--门店
				V_ChannelID,	--IN	VARCHAR2,	--渠道
				V_EmployeeID,	--IN	VARCHAR2,	--员工
				V_DepartID,	--IN	VARCHAR2,	--部门
				V_TerminalID,	--IN	VARCHAR2,	--终端
				V_CardID,	--IN	VARCHAR2,	--卡ID
				4,		--IN	INTEGER,	--1.本金异动  2.增值异动 3.积分异动 4.福豆异动
				V_Direct,	--IN	INTEGER,	--1 增加加   -1 减少
				V_GetBean,	--IN	NUMBER,		--异动值	
				0,		--IN	NUMBER,		--本金异动
				0,		--IN	NUMBER,		--赠送异动					
				V_BillType,	--IN	VARCHAR2,	--单据类型
				P_BillNo,	--IN	VARCHAR2,	--单据号
				TRUNC(SYSDATE),	--IN	DATE,		--单据日期
				'',		--IN 	VARCHAR2,	--异动原因
				V_Discription,	--IN 	VARCHAR2	--异动描述
				P_Checker	--IN	VARCHAR2	--操作员
			);				
	END IF;
	




	SELECT Amount,Amount1,Amount2,ValidPoint,Bean
	INTO V_CardAmount_end,V_CardAmount1_end,V_CardAmount2_end,V_CardPoint_End,V_CardBean_END
	FROM CRM_Card
	WHERE EID = P_EID and CardID = V_CardID;
	
	UPDATE CRM_CARDCONSUME SET BEFAMOUNT1 = V_CardAmount1,
				BEFAMOUNT2 = 	V_CardAmount2,
				AFTAMOUNT1 = V_CardAmount1_end,
				AFTAMOUNT2 = V_CardAmount2_end,
				BEFPOINT = V_CardPoint,
				AFTPOINT = V_CardPoint_End,
				BEFBEAN = V_CardBean,
				AFTBEAN = V_CardBean_End
				
	WHERE EID = P_EID AND BILLNO = P_BILLNO;				


	--SP_CRM_CardConsume_ToConsume(P_EID,P_BILLNO,P_Checker);

	--没有任何资产变动的情况下，也要计算晋级
	IF V_Amount =0 AND V_UsePoint = 0 AND V_GetPoint = 0 AND V_UseBean = 0 AND V_GetBean = 0 THEN
		
		IF V_Refund = 0 THEN
			SP_CRM_UpdateCardLevel(
				P_EID,		--IN	VARCHAR2,	--企业ID
				V_CardID,	--IN	VARCHAR2	--卡ID
				V_BillType,
				P_BillNo
			);
		END IF;
	END IF;
	IF V_Refund = 1 THEN
		--找到原单，还原原单的会员等级
		BEGIN
/*--//20230410-002-[1032384]-01134Grace：銷退找舊單來源改抓CRM_CARDCONSUME(原為CRM_CONSUME)
			--1.找到这张退货单
			SELECT BILLNO INTO V_BillNO_TEMP FROM CRM_CONSUME_CARD WHERE EID = P_EID AND CARDBILLNO = P_BillNo;						
			SELECT  THIRDBILLTYPE,THIRDORDERNO INTO V_THIRDBILLTYPE,V_THIRDBILLNO
			  FROM CRM_CONSUME
			 WHERE EID = P_EID
			   AND BILLNO = V_BillNO_TEMP
			   ;
			
			--2.找到这张退货单的原单
			SELECT BILLNO INTO V_BillNO_TEMP
			  FROM CRM_CONSUME
			 WHERE EID = P_EID
			   AND THIRDBILLTYPE = V_THIRDBILLTYPE
			   AND THIRDORDERNO = V_THIRDBILLNO
			   AND REFUND = 0 AND ROWNUM = 1;	
			SELECT CARDBILLNO INTO V_BillNO_TEMP FROM CRM_CONSUME_CARD WHERE EID = P_EID AND BILLNO = V_BillNO_TEMP AND CARDID = V_CardID AND ROWNUM = 1;
*/
			--//20230410-002-[1032384]-01134Grace：銷退找舊單來源改抓CRM_CARDCONSUME(原為CRM_CONSUME)
			SELECT SOURCEBILLNO INTO V_BillNO_TEMP FROM CRM_CARDCONSUME WHERE EID = P_EID AND BILLNO = P_BillNo;
		EXCEPTION WHEN NO_DATA_FOUND THEN
			V_BillNO_TEMP := '';
		END;	
		
		IF V_BillNO_TEMP is not null THEN
			SP_CRM_ReverseCardLevel(
				P_EID,		--IN	VARCHAR2,	--企业ID
				V_BillType,
				V_BillNO_TEMP
			);
		END IF;
	END IF;




EXCEPTION WHEN OTHERS THEN	
	Raise_Application_Error(-20001, v_BreakPoint || '-' || SQLERRM);    
END;
