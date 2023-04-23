create or replace PROCEDURE "SP_CRM_DOAWARD" (
	P_EID		IN	VARCHAR2,	--企业ID
	P_MemberID	IN 	VARCHAR2,	--会员
	P_AppID		IN	VARCHAR2,	--APPID		
	P_OpenID	IN	VARCHAR2,	--OPENID 没有注册成会员的时候粉丝行为用到
	P_CardNo	IN	VARCHAR2,	--卡号,空则认为是会员主卡
	P_AWARDID	IN	VARCHAR2,	--奖励方案ID
	P_Count		IN	INTEGER,	--奖励次数
	P_CompanyID	IN	VARCHAR2,	--公司ID
	P_ShopID	IN	VARCHAR2,	--门店ID		
	P_ChannelID	IN	VARCHAR2,	--渠道ID
	P_IncentiveBillType	IN	VARCHAR2,	--营销方案单据类型
	P_IncentiveBillno	IN 	VARCHAR2,	--营销方案单据号
	P_BillType		IN	VARCHAR2,	--来源单据类型
	P_Billno		IN 	VARCHAR2,	--来源单据号	
	P_ActionID	IN	VARCHAR2,	--行为
	P_ACTIONKEY	IN	VARCHAR2,	--行为的KEY 
	P_ACTIONNO	IN	INTEGER		--行为奖励的行号	
) 
AS
-------------------------------------------------------------------
--名称：会员行为检查并触发满足条件的奖励规则
--说明：
--参数：单据类型
--备注：
--创建者   : JW
--创建时间 : 2017-07-25
--修改记录：
-------------------------------------------------------------------
V_BreakPoint			VARCHAR2(255);
V_Err				INTEGER;
V_Msg				VARCHAR2(255);

R1				CRM_AWARD%ROWTYPE;

V_CARDNO			VARCHAR2(50);
V_CARDID			INTEGER;
V_CompanyID			VARCHAR2(50);
V_Count				INTEGER;

V_CouponNo			VARCHAR2(50);

V_Key 				VARCHAR2(32);

V_SENDMATERIAL			INTEGER;
V_Done				Boolean;

RC				CRM_COUPON%ROWTYPE;

V_BRANCHTYPE 			INTEGER;
V_BRANCHID 			VARCHAR2(50);   				

V_BillType			VARCHAR2(64);	--来源单据类型
V_Billno			VARCHAR2(64);	--来源单据号	

V_AwardPoint			NUMBER(18,4);
V_AwardAmount			NUMBER(18,4);
V_AwardCoupon			NUMBER(18,4);
V_AwardBean			NUMBER(18,4);

BEGIN  

	V_BreakPoint:= 'SP_CRM_DOAWARD_010';
	BEGIN
		SELECT * INTO R1 FROM CRM_AWARD where EID = P_EID AND AWARDID = P_AWARDID;
	EXCEPTION WHEN NO_DATA_FOUND THEN
		return;
	END;	


	V_AwardPoint :=0;
	V_AwardAmount := 0;
	V_AwardCoupon := 0;
	V_AwardBean := 0;


	V_BillType := P_BillType;
	V_BillNo := P_Billno;
	--空则取营销单据号
	IF V_BillType is null THEN
		V_BillType := P_IncentiveBillType;
	END IF;		
	IF V_Billno is null THEN
		V_Billno := P_IncentiveBillNo;
	END IF;		
	--还空则造一个
	IF V_BillType is null THEN
		V_BillType := 'CRM000';
	END IF;		
	IF V_Billno is null THEN
		V_Billno := sys_guid();
	END IF;		

	IF P_CardNo is not null THEN
		V_CARDNO := P_CardNo;
		BEGIN
			SELECT CARDID INTO V_CARDID FROM CRM_CARD
			WHERE EID = P_EID 
			  AND CARDNO = P_CardNo
			  AND STATUS <> 8;
		EXCEPTION WHEN NO_DATA_FOUND THEN
			null;
		END;
	ELSE
		IF P_MemberID is not null THEN
			BEGIN
				SELECT B.CARDNO,B.CARDID INTO V_CARDNO,V_CARDID FROM CRM_MEMBER A 
				JOIN CRM_CARD B ON A.EID = B.EID AND B.CARDNO = A.MAINCARDNO AND A.MEMBERID = B.MEMBERID AND B.STATUS <> 8  
				WHERE A.EID = P_EID AND A.MEMBERID=P_MEMBERID;
			EXCEPTION WHEN NO_DATA_FOUND THEN
				null;
			END;
		END IF;		
	END IF;

	V_BreakPoint:= 'SP_CRM_DOAWARD_020';

	IF R1.AWARDPOINT = 1 AND R1.POINT > 0 AND V_CARDID is not null THEN
		
		V_AwardPoint := R1.POINT*P_Count;
		
		SP_CRM_CardAccount(
			P_EID,		--IN	VARCHAR2,	--企业ID
			P_CompanyID,	--IN	VARCHAR2,	--公司
			P_ShopID,	--IN	VARCHAR2,	--门店
			P_ChannelID,	--IN	VARCHAR2,	--渠道
			'',		--IN	VARCHAR2,	--员工
			'',		--IN	VARCHAR2,	--部门
			'',		--IN	VARCHAR2,	--终端
			V_CARDID,	--IN	VARCHAR2,	--卡ID
			3,		--IN	INTEGER,	--1.金额异动 3.积分异动 4.福豆异动
			1,		--IN	INTEGER,	--1 增加   -1 减少
			R1.POINT*P_Count,--IN	NUMBER,		--异动值
			0,		--IN	NUMBER,		--本金异动
			0,		--IN	NUMBER,		--赠送异动					
			V_BillType,	--IN	VARCHAR2,	--单据类型
			V_BillNo,	--IN	VARCHAR2,	--单据号
			TRUNC(SYSDATE),	--IN	DATE,		--单据日期
			'奖励',		--IN 	VARCHAR2,	--异动原因
			R1.AWARDNAME,	--IN 	VARCHAR2	--异动描述
			''		--IN	VARCHAR2	--操作员
		);
		
		
		UPDATE CRM_AWARDRESULT
		SET MEMBERID = P_MEMBERID,
		POINT = POINT + R1.POINT*P_Count,
		LASTMODITIME = SYSDATE
		WHERE EID = P_EID
		  AND AWARDID = R1.AWARDID
		  AND ACTIONKEY = P_ACTIONKEY;
		IF (SQL%ROWCOUNT = 0) OR (SQL%ROWCOUNT IS NULL) THEN
			INSERT INTO CRM_AWARDRESULT
			(
			EID,AWARDID,ACTIONKEY,MEMBERID,
			POINT,AMOUNT,BEAN,COUPON,AWARDGOODS,GOODS,
			CREATEOPID,CREATETIME,LASTMODIOPID,LASTMODITIME,
			BILLTYPE,BILLNO,INCENTIVEBILLTYPE,INCENTIVEBILLNO
			,COMPANYID,CHANNELID,SHOPID,STATUS,
			CARDNO,CARDID
			)
			VALUES
			(
			P_EID,R1.AWARDID,P_ACTIONKEY,P_MEMBERID,
			R1.POINT*P_Count,0,0,0,0,0,
			'',SYSDATE,'',SYSDATE,
			V_BillType,V_BillNo,P_IncentiveBillType,P_IncentiveBillNo
			,P_CompanyID,P_ChannelID,P_ShopID,100,
			V_CARDNO,V_CARDID
			);
			
		END IF;
		  
		
		
	END IF;		
	
	
	V_BreakPoint:= 'SP_CRM_DOAWARD_030';
	IF R1.AWARDSAVING = 1 AND R1.SAVING > 0 AND V_CARDID is not null THEN
		
		V_AwardAmount := R1.SAVING*P_Count;
		
		SP_CRM_CardAccount(
			P_EID,		--IN	VARCHAR2,	--企业ID
			P_CompanyID,	--IN	VARCHAR2,	--公司
			P_ShopID,	--IN	VARCHAR2,	--门店
			P_ChannelID,	--IN	VARCHAR2,	--渠道
			'',		--IN	VARCHAR2,	--员工
			'',		--IN	VARCHAR2,	--部门
			'',		--IN	VARCHAR2,	--终端
			V_CARDID,	--IN	VARCHAR2,	--卡ID
			1,		--IN	INTEGER,	--1.金额异动 3.积分异动 4.福豆异动
			1,		--IN	INTEGER,	--1 增加   -1 减少
			R1.SAVING*P_Count,--IN	NUMBER,		--异动值
			0,		--IN	NUMBER,		--本金异动
			R1.SAVING*P_Count,--IN	NUMBER,		--赠送异动					
			V_BillType,	--IN	VARCHAR2,	--单据类型
			V_BillNo,	--IN	VARCHAR2,	--单据号
			TRUNC(SYSDATE),	--IN	DATE,		--单据日期
			'奖励',		--IN 	VARCHAR2,	--异动原因
			R1.AWARDNAME,	--IN 	VARCHAR2	--异动描述
			''		--IN	VARCHAR2	--操作员
		);

		UPDATE CRM_AWARDRESULT
		SET MEMBERID = P_MEMBERID,
		AMOUNT = AMOUNT + R1.SAVING*P_Count,
		LASTMODITIME = SYSDATE
		WHERE EID = P_EID
		  AND AWARDID = R1.AWARDID
		  AND ACTIONKEY = P_ACTIONKEY;
		IF (SQL%ROWCOUNT = 0) OR (SQL%ROWCOUNT IS NULL) THEN
			INSERT INTO CRM_AWARDRESULT
			(
			EID,AWARDID,ACTIONKEY,MEMBERID,
			POINT,AMOUNT,BEAN,COUPON,AWARDGOODS,GOODS,
			CREATEOPID,CREATETIME,LASTMODIOPID,LASTMODITIME,
			BILLTYPE,BILLNO,INCENTIVEBILLTYPE,INCENTIVEBILLNO
			,COMPANYID,CHANNELID,SHOPID,STATUS,
			CARDNO,CARDID
			)
			VALUES
			(
			P_EID,R1.AWARDID,P_ACTIONKEY,P_MEMBERID,
			0,	R1.SAVING*P_Count,0,0,0,0,
			'',SYSDATE,'',SYSDATE,
			V_BillType,V_BillNo,P_IncentiveBillType,P_IncentiveBillNo
			,P_CompanyID,P_ChannelID,P_ShopID,100,
			V_CARDNO,V_CARDID			
			);			
		END IF;
		
		--0819 HUANGLX ADD
		IF V_BillType = 'CRM009' THEN
		
		UPDATE CRM_CARDRECHARGEITEM SET AMOUNT2_ACTION=R1.SAVING*P_Count
		WHERE BILLNO=V_BillNo AND CARDID=V_CARDID;
		
		END IF;
		
		
	END IF;		

	V_BreakPoint:= 'SP_CRM_DOAWARD_040';
	IF R1.AWARDBEAN = 1 AND R1.BEAN > 0 AND V_CARDID is not null THEN
		
		V_AwardBean := R1.SAVING*P_Count;
		
		SP_CRM_CardAccount(
			P_EID,		--IN	VARCHAR2,	--企业ID
			P_CompanyID,	--IN	VARCHAR2,	--公司
			P_ShopID,	--IN	VARCHAR2,	--门店
			P_ChannelID,	--IN	VARCHAR2,	--渠道
			'',		--IN	VARCHAR2,	--员工
			'',		--IN	VARCHAR2,	--部门
			'',		--IN	VARCHAR2,	--终端
			V_CARDID,	--IN	VARCHAR2,	--卡ID
			4,		--IN	INTEGER,	--1.金额异动 3.积分异动 4.福豆异动
			1,		--IN	INTEGER,	--1 增加   -1 减少
			R1.BEAN*P_Count,--IN	NUMBER,		--异动值
			0,		--IN	NUMBER,		--本金异动
			0,		--IN	NUMBER,		--赠送异动					
			V_BillType,	--IN	VARCHAR2,	--单据类型
			V_BillNo,	--IN	VARCHAR2,	--单据号
			TRUNC(SYSDATE),	--IN	DATE,		--单据日期
			'奖励',		--IN 	VARCHAR2,	--异动原因
			R1.AWARDNAME,	--IN 	VARCHAR2	--异动描述
			''		--IN	VARCHAR2	--操作员
		);
		
		UPDATE CRM_AWARDRESULT
		SET MEMBERID = P_MEMBERID,
		BEAN = BEAN + R1.BEAN*P_Count,
		LASTMODITIME = SYSDATE
		WHERE EID = P_EID
		  AND AWARDID = R1.AWARDID
		  AND ACTIONKEY = P_ACTIONKEY;
		IF (SQL%ROWCOUNT = 0) OR (SQL%ROWCOUNT IS NULL) THEN
			INSERT INTO CRM_AWARDRESULT
			(
			EID,AWARDID,ACTIONKEY,MEMBERID,
			POINT,AMOUNT,BEAN,COUPON,AWARDGOODS,GOODS,
			CREATEOPID,CREATETIME,LASTMODIOPID,LASTMODITIME,
			BILLTYPE,BILLNO,INCENTIVEBILLTYPE,INCENTIVEBILLNO
			,COMPANYID,CHANNELID,SHOPID,STATUS,
			CARDNO,CARDID
			)
			VALUES
			(
			P_EID,R1.AWARDID,P_ACTIONKEY,P_MEMBERID,
			0,	0,	R1.BEAN*P_Count,0,0,0,
			'',SYSDATE,'',SYSDATE,
			V_BillType,V_BillNo,P_IncentiveBillType,P_IncentiveBillNo
			,P_CompanyID,P_ChannelID,P_ShopID,100,
			V_CARDNO,V_CARDID
			);			
		END IF;

	END IF;		
	
	
	
	V_BreakPoint:= 'SP_CRM_DOAWARD_050';
	IF R1.AWARDCOUPON = 1 THEN
		
		V_AwardCoupon := P_Count;
		
		V_Done := false;
		V_SENDMATERIAL := 0;
		
		--如果是送实物券，则不需要生成电子券
		IF V_BillType = 'CRM009' THEN
			BEGIN
				SELECT SENDMATERIAL 
				  INTO V_SENDMATERIAL
				  FROM CRM_CARDRECHARGE_PREAWARD
				WHERE EID = P_EID
				  AND BILLNO = V_BillNo
				  AND INCENTIVEBILLNO = P_IncentiveBillNo
				  AND AWARDID = R1.AWARDID;		  			
			EXCEPTION WHEN NO_DATA_FOUND THEN
				V_SENDMATERIAL := 0;
			END;				
			
			IF V_SENDMATERIAL = 1 THEN
				
				FOR CC IN (
					SELECT * FROM CRM_CARDRECHARGE_PRECOUPON
					WHERE EID = P_EID AND BILLNO = V_BillNo
					  AND INCENTIVEBILLNO = P_IncentiveBillNo
					  AND AWARDID = R1.AWARDID
					) 
				LOOP
				
					--有号券
					BEGIN
						SELECT * INTO RC FROM CRM_COUPON
						WHERE EID = P_EID
						  AND SERIALCODE = CC.COUPONSERIALNO;
					EXCEPTION WHEN NO_DATA_FOUND THEN
						V_Msg := '券序号'||CC.COUPONSERIALNO||'不存在,请确认券信息是否已经生成过';
						Raise_Application_Error(V_Err, V_Msg);								
					END;						
					IF RC.STATUS <> 2 THEN
						V_Msg := '券序号'||CC.COUPONSERIALNO||'不是发行状态,请确认券信息是否是发行状态';
						Raise_Application_Error(V_Err, V_Msg);								
					END IF;						

		   			IF P_ShopID is null THEN
		   				V_BRANCHTYPE := 1;
		   				V_BRANCHID := P_CompanyID;   				
		   			ELSE	
		   				V_BRANCHTYPE := 2;
		   				V_BRANCHID := P_ShopID;   				
					END IF;   				

					SP_CRM_STOCK(
						P_EID,			--IN	VARCHAR2,	--企业ID
						V_BRANCHTYPE,		--IN	INTEGER,	--机构类型 1=公司 2=门店
						V_BRANCHID,		--IN	VARCHAR2,	--机构编号
						V_BillType,		--IN	VARCHAR2,	--单据类型
						V_BillNo,		--IN	VARCHAR2,	--单据号
						CC.SerialNo,		--IN	INTEGER,	--单内行号
						TRUNC(SYSDATE),		--IN	DATE,		--单据日期
						2,			--IN	INTEGER,	--类型 1=卡 2=券
						RC.COUPONTYPEID,	--IN	VARCHAR2,	--卡券类型编号
						-1,			--IN	INTEGER,	--异动方向 -1=减少 1=增加
						RC.FACEAMOUNT,		--IN	NUMBER,		--面额
						1,			--IN	NUMBER,		--数量
						'活动赠送',		--IN 	VARCHAR2,	--异动原因
						'活动赠送',		--IN 	VARCHAR2,	--异动描述
						''			--IN	VARCHAR2	--操作员
					);
											
					SP_CRM_CouponStatus(
						P_EID,		--IN	VARCHAR2,	--企业ID	
						P_CompanyID,	--IN	VARCHAR2,	--公司
						P_ShopID,	--IN	VARCHAR2,	--门店
						P_ChannelID,	--IN	VARCHAR2,	--渠道
						'',		--IN	VARCHAR2,	--员工
						'',		--IN	VARCHAR2,	--部门
						'',		--IN	VARCHAR2,	--终端
						RC.CouponCode,	--IN	VARCHAR2,	--券号
						4,		--IN	INTEGER,	--1. 状态 1生成 2发行 4激活 6冻结 9已核销
						'',		--IN	VARCHAR2,	--会员
						V_BillType,	--IN	VARCHAR2,	--单据类型
						V_BillNo,	--IN	VARCHAR2,	--单据号
						SYSDATE,	--IN	DATE,		--单据日期
						'奖励时激活',	--IN 	VARCHAR2,	--异动描述
						''		--IN	VARCHAR2	--操作员	
					); 
					
					UPDATE CRM_COUPON SET BRANCHTYPE = 3,BRANCHID = '',ACTIVITYTYPENEW=V_BillType,ACTIVITYID=V_BillNo WHERE EID = P_EID AND CouponCode = RC.CouponCode;
				
				END LOOP;
				
				
				
				V_Done := true;				
			END IF;				
			
			
			
		END IF;			
		
		
		
		
		
		IF R1.COUPONFORM = 1 AND V_Done = False THEN
			FOR i IN 1..P_Count LOOP	
				V_BreakPoint:= 'SP_CRM_DOAWARD_100';
        			IF P_ActionID='BIRTHDAYGIFT' OR P_ActionID='MARRYGIFT' OR P_ActionID='REGGIFT' THEN
	        			SP_CRM_CreateNewCoupon(
					P_EID,		--IN	VARCHAR2,	--企业ID
					R1.COUPONFORMID,--IN	VARCHAR2,	--券类型
					'',		--IN	VARCHAR2,	--券号
					null,		--IN	DATE,		--有效开始日期
					null,		--IN	DATE,		--有效截止日期
					1,		--IN	INTEGER,	--是否电子卡0=否 1=是
					'奖励生成',	--IN	VARCHAR2,	--描述
					0,		--IN	NUMBER,		--面额	0默认为券面额
					0,		--IN 	NUMBER,		--成交价
					'CRM043',	--IN	VARCHAR2,	--描述
					V_BillNo,	--IN	VARCHAR2,	--单号
					P_CompanyID,	--IN	VARCHAR2,	--发券公司
					'',		--IN	VARCHAR2,	--收款公司
					P_ShopID,	--IN	VARCHAR2,	--门店
					P_ChannelID,	--IN	VARCHAR2,	--渠道
					'',		--IN	VARCHAR2,	--员工
					'',		--IN	VARCHAR2,	--部门
					'',		--IN	VARCHAR2,	--终端
					P_MEMBERID,	--IN	VARCHAR2,	--所属会员
					'',		--IN	VARCHAR2,	--APPTYPE
					P_AppID,	--IN	VARCHAR2,	--APPID
					P_OpenID,	--IN	VARCHAR2,	--OPENID
					10,		--IN	INTEGER,	--营销活动类型
					P_IncentiveBillNo,--IN	VARCHAR2,	--营销活动ID
					4,		--IN	INTEGER,	--状态 1生成 2发行 4激活 6冻结 9已核销 
					'',		--IN	VARCHAR2	--操作人
					V_CouponNo
					); 
        			ELSE
					SP_CRM_CreateNewCoupon(
					P_EID,		--IN	VARCHAR2,	--企业ID
					R1.COUPONFORMID,--IN	VARCHAR2,	--券类型
					'',		--IN	VARCHAR2,	--券号
					null,		--IN	DATE,		--有效开始日期
					null,		--IN	DATE,		--有效截止日期
					1,		--IN	INTEGER,	--是否电子卡0=否 1=是
					'奖励生成',	--IN	VARCHAR2,	--描述
					0,		--IN	NUMBER,		--面额	0默认为券面额
					0,		--IN 	NUMBER,		--成交价
					V_BillType,	--IN	VARCHAR2,	--描述
					V_BillNo,	--IN	VARCHAR2,	--单号
					P_CompanyID,	--IN	VARCHAR2,	--发券公司
					'',		--IN	VARCHAR2,	--收款公司
					P_ShopID,	--IN	VARCHAR2,	--门店
					P_ChannelID,	--IN	VARCHAR2,	--渠道
					'',		--IN	VARCHAR2,	--员工
					'',		--IN	VARCHAR2,	--部门
					'',		--IN	VARCHAR2,	--终端
					P_MEMBERID,	--IN	VARCHAR2,	--所属会员
					'',		--IN	VARCHAR2,	--APPTYPE
					P_AppID,	--IN	VARCHAR2,	--APPID
					P_OpenID,	--IN	VARCHAR2,	--OPENID
					1,		--IN	INTEGER,	--营销活动类型
					P_IncentiveBillNo,--IN	VARCHAR2,	--营销活动ID
					4,		--IN	INTEGER,	--状态 1生成 2发行 4激活 6冻结 9已核销 
					'',		--IN	VARCHAR2	--操作人
					V_CouponNo
					); 
				END IF;
				
				V_Key := sys_guid();
				INSERT INTO CRM_AWARDRESULT_COUPON(
					EID,		AWARDID,	ACTIONKEY,	ID,		MEMBERID,
					COUPONTYPEID,	COUPONCODE,	COUPONPACKID,	CREATEOPID,	CREATETIME,
					LASTMODIOPID,	LASTMODITIME,	BILLTYPE,	BILLNO,
					INCENTIVEBILLTYPE,INCENTIVEBILLNO
				)
				VALUES
				(
					P_EID,		R1.AWARDID,	P_ACTIONKEY,	V_Key,		P_MEMBERID,
					R1.COUPONFORMID,V_CouponNo,	'',		'',		SYSDATE,
					'',		SYSDATE,	V_BillType,			V_BillNo,
					P_IncentiveBillType,	P_IncentiveBillNo
				);
				
			END LOOP;
			
			V_BreakPoint:= 'SP_CRM_DOAWARD_200';
			UPDATE CRM_AWARDRESULT
			SET MEMBERID = P_MEMBERID,
			COUPON = COUPON + P_Count,
			LASTMODITIME = SYSDATE
			WHERE EID = P_EID
			  AND AWARDID = R1.AWARDID
			  AND ACTIONKEY = P_ACTIONKEY;
			IF (SQL%ROWCOUNT = 0) OR (SQL%ROWCOUNT IS NULL) THEN
				INSERT INTO CRM_AWARDRESULT
				(
				EID,AWARDID,ACTIONKEY,MEMBERID,
				POINT,AMOUNT,BEAN,COUPON,AWARDGOODS,GOODS,
				CREATEOPID,CREATETIME,LASTMODIOPID,LASTMODITIME,
				BILLTYPE,BILLNO,INCENTIVEBILLTYPE,INCENTIVEBILLNO
				,COMPANYID,CHANNELID,SHOPID,STATUS
				)
				VALUES
				(
				P_EID,R1.AWARDID,P_ACTIONKEY,P_MEMBERID,
				0,	0,	0,P_COUNT,0,0,
				'',SYSDATE,'',SYSDATE,
				V_BillType,V_BillNo,P_IncentiveBillType,P_IncentiveBillNo
				,P_CompanyID,P_ChannelID,P_ShopID,100
				);			
			END IF;
			
		END IF;	
		
		IF R1.COUPONFORM = 2 THEN
			FOR i IN 1..P_Count LOOP	
				V_BreakPoint:= 'SP_CRM_DOAWARD_100';
				
				FOR C4 IN(
					SELECT COUPONTYPEID,QUANTITY 
					FROM CRM_COUPONPACKITEM
					WHERE EID=P_EID AND COUPONPACKID = R1.COUPONFORMID
					ORDER BY SERIALNO
				)
				LOOP
					
					FOR j IN 1..C4.QUANTITY LOOP	
            					IF P_ActionID='BIRTHDAYGIFT' OR P_ActionID='MARRYGIFT' OR P_ActionID='REGGIFT' THEN
							SP_CRM_CreateNewCoupon(
							P_EID,		--IN	VARCHAR2,	--企业ID
							C4.COUPONTYPEID,--IN	VARCHAR2,	--券类型
							'',		--IN	VARCHAR2,	--券号
							null,		--IN	DATE,		--有效开始日期
							null,		--IN	DATE,		--有效截止日期
							1,		--IN	INTEGER,	--是否电子卡0=否 1=是
							'奖励生成',	--IN	VARCHAR2,	--描述
							0,		--IN	NUMBER,		--面额	0默认为券面额
							0,		--IN 	NUMBER,		--成交价
							'CRM043',	--IN	VARCHAR2,	--描述
							V_BillNo,	--IN	VARCHAR2,	--单号
							P_CompanyID,	--IN	VARCHAR2,	--发券公司
							'',		--IN	VARCHAR2,	--收款公司
							P_ShopID,	--IN	VARCHAR2,	--门店
							P_ChannelID,	--IN	VARCHAR2,	--渠道
							'',		--IN	VARCHAR2,	--员工
							'',		--IN	VARCHAR2,	--部门
							'',		--IN	VARCHAR2,	--终端
							P_MEMBERID,	--IN	VARCHAR2,	--所属会员
							'',		--IN	VARCHAR2,	--APPTYPE
							P_AppID,	--IN	VARCHAR2,	--APPID
							P_OpenID,	--IN	VARCHAR2,	--OPENID
							10,		--IN	INTEGER,	--营销活动类型
							P_IncentiveBillNo,--IN	VARCHAR2,	--营销活动ID
							4,		--IN	INTEGER,	--状态 1生成 2发行 4激活 6冻结 9已核销 
							'',		--IN	VARCHAR2	--操作人
							V_CouponNo
							); 
						ELSE
							SP_CRM_CreateNewCoupon(
							P_EID,		--IN	VARCHAR2,	--企业ID
							C4.COUPONTYPEID,--IN	VARCHAR2,	--券类型
							'',		--IN	VARCHAR2,	--券号
							null,		--IN	DATE,		--有效开始日期
							null,		--IN	DATE,		--有效截止日期
							1,		--IN	INTEGER,	--是否电子卡0=否 1=是
							'奖励生成',	--IN	VARCHAR2,	--描述
							0,		--IN	NUMBER,		--面额	0默认为券面额
							0,		--IN 	NUMBER,		--成交价
							V_BillType,	--IN	VARCHAR2,	--描述
							V_BillNo,	--IN	VARCHAR2,	--单号
							P_CompanyID,	--IN	VARCHAR2,	--发券公司
							'',		--IN	VARCHAR2,	--收款公司
							P_ShopID,	--IN	VARCHAR2,	--门店
							P_ChannelID,	--IN	VARCHAR2,	--渠道
							'',		--IN	VARCHAR2,	--员工
							'',		--IN	VARCHAR2,	--部门
							'',		--IN	VARCHAR2,	--终端
							P_MEMBERID,	--IN	VARCHAR2,	--所属会员
							'',		--IN	VARCHAR2,	--APPTYPE
							P_AppID,	--IN	VARCHAR2,	--APPID
							P_OpenID,	--IN	VARCHAR2,	--OPENID
							1,		--IN	INTEGER,	--营销活动类型
							P_IncentiveBillNo,--IN	VARCHAR2,	--营销活动ID
							4,		--IN	INTEGER,	--状态 1生成 2发行 4激活 6冻结 9已核销 
							'',		--IN	VARCHAR2	--操作人
							V_CouponNo
							); 
						END IF;
						
						V_Key := sys_guid();
						INSERT INTO CRM_AWARDRESULT_COUPON(
							EID,		AWARDID,	ACTIONKEY,	ID,		MEMBERID,
							COUPONTYPEID,	COUPONCODE,	COUPONPACKID,	CREATEOPID,	CREATETIME,
							LASTMODIOPID,	LASTMODITIME,	BILLTYPE,	BILLNO,
							INCENTIVEBILLTYPE,INCENTIVEBILLNO
						)
						VALUES
						(
							P_EID,		R1.AWARDID,	P_ACTIONKEY,	V_Key,		P_MEMBERID,
							C4.COUPONTYPEID,V_CouponNo,	R1.COUPONFORMID,'',		SYSDATE,
							'',		SYSDATE,	V_BillType,			V_BillNo,
							P_IncentiveBillType,	P_IncentiveBillNo
						);
						
					END LOOP;	
				END LOOP;					
				
			END LOOP;
			
			V_BreakPoint:= 'SP_CRM_DOAWARD_200';
			UPDATE CRM_AWARDRESULT
			SET MEMBERID = P_MEMBERID,
			COUPON = COUPON + P_Count,
			LASTMODITIME = SYSDATE
			WHERE EID = P_EID
			  AND AWARDID = R1.AWARDID
			  AND ACTIONKEY = P_ACTIONKEY;
			IF (SQL%ROWCOUNT = 0) OR (SQL%ROWCOUNT IS NULL) THEN
				INSERT INTO CRM_AWARDRESULT
				(
				EID,AWARDID,ACTIONKEY,MEMBERID,
				POINT,AMOUNT,BEAN,COUPON,AWARDGOODS,GOODS,
				CREATEOPID,CREATETIME,LASTMODIOPID,LASTMODITIME,
				BILLTYPE,BILLNO,INCENTIVEBILLTYPE,INCENTIVEBILLNO
				,COMPANYID,CHANNELID,SHOPID,STATUS
				)
				VALUES
				(
				P_EID,R1.AWARDID,P_ACTIONKEY,P_MEMBERID,
				0,	0,	0,P_COUNT,0,0,
				'',SYSDATE,'',SYSDATE,
				V_BillType,V_BillNo,P_IncentiveBillType,P_IncentiveBillNo
				,P_CompanyID,P_ChannelID,P_ShopID,100				
				);			
			END IF;
			
		END IF;		
				
	END IF;		

	V_BreakPoint:= 'SP_CRM_DOAWARD_060';
	IF R1.AWARDGOODS = 1 THEN	--奖励赠品，不直接奖励，而是返回结构供前端选择。
		UPDATE CRM_AWARDRESULT
		SET MEMBERID = P_MEMBERID,
		GOODS = GOODS+P_Count,
		AWARDGOODS = 1,
		LASTMODITIME = SYSDATE
		WHERE EID = P_EID
		  AND AWARDID = R1.AWARDID
		  AND ACTIONKEY = P_ACTIONKEY;
		IF (SQL%ROWCOUNT = 0) OR (SQL%ROWCOUNT IS NULL) THEN
			INSERT INTO CRM_AWARDRESULT
			(
			EID,AWARDID,ACTIONKEY,MEMBERID,
			POINT,AMOUNT,BEAN,COUPON,AWARDGOODS,GOODS,
			CREATEOPID,CREATETIME,LASTMODIOPID,LASTMODITIME,
			BILLTYPE,BILLNO,INCENTIVEBILLTYPE,INCENTIVEBILLNO
			,COMPANYID,CHANNELID,SHOPID,STATUS
			)
			VALUES
			(
			P_EID,R1.AWARDID,P_ACTIONKEY,P_MEMBERID,
			0,	0,	0,0,1,P_Count,
			'',SYSDATE,'',SYSDATE,
			V_BillType,V_BillNo,P_IncentiveBillType,P_IncentiveBillNo	
			,P_CompanyID,P_ChannelID,P_ShopID,100			
			);			
		END IF;
	END IF;

	--直接到账的电子类产品直接记录次数
	IF R1.AWARDCOUPON = 1 or R1.AWARDPOINT = 1 or R1.AWARDSAVING = 1 or R1.AWARDBEAN = 1 THEN
		V_BreakPoint:= 'SP_CRM_DOAWARD_300';
		INSERT INTO CRM_INCENTIVEMEMBER3
		(EID,		BILLNO,		MEMBERID,	ACTIONID,	
		ACTIONKEY,	ACTIONNO,	AWARDID,	COUNT,
		LASTMODIOPID,	LASTMODITIME,ID
		)
		VALUES
		(
		P_EID,	P_IncentiveBILLNO,P_MEMBERID,P_ACTIONID,
		P_ACTIONKEY,	P_ACTIONNO,	P_AWARDID,	P_COUNT,
		P_MEMBERID,	SYSDATE,'INIT'
		);
	END IF;
	
	IF P_ACTIONID = 'SHARE_REGISTER' THEN
		
		UPDATE CRM_MEMBERFANS_GATHER SET TOTALPOINT = TOTALPOINT + V_AwardPoint,
						TOTALAMOUNT = TOTALAMOUNT + V_AwardAmount,
						TOTALBEAN = TOTALBEAN + V_AwardBean,
						TOTALCOUPON = TOTALCOUPON + V_AwardCoupon,
						LASTMODITIME = SYSDATE
		WHERE EID = P_EID AND MEMBERID = P_MEMBERID;
		IF (SQL%ROWCOUNT = 0) OR (SQL%ROWCOUNT IS NULL) THEN
			INSERT INTO CRM_MEMBERFANS_GATHER(
				EID,	MEMBERID,	TOTALPOINT,	TOTALAMOUNT,	TOTALBEAN,	TOTALCOUPON,
				LASTMODIOPID,	LASTMODITIME
			)
			VALUES
			(
				P_EID,	P_MEMBERID,	V_AwardPoint,	V_AwardAmount,	V_AwardBean,	V_AwardCoupon,
				P_MEMBERID,SYSDATE
			);
		END IF;
	END IF;	
	
		
EXCEPTION WHEN OTHERS THEN
	Raise_Application_Error(-20001, v_BreakPoint || '-'|| SQLERRM);  
END;
