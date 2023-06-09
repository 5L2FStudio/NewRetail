--------------------------------------------------------
--  DDL for Function F_CRM_BILLQUERY
--------------------------------------------------------

  CREATE OR REPLACE EDITIONABLE FUNCTION "POSV3"."F_CRM_BILLQUERY" (
P_EID IN VARCHAR2,
P_MemberID IN VARCHAR2,
P_CardNo  IN VARCHAR2,
P_BeginDate VARCHAR2,	
P_EndDate VARCHAR2	
) 
RETURN T_BillQuery_TABLE 
IS
--------------------------------------------------------------------------------
--说明　　 : 账单查询
--数据流说明:
--创建者   : JW
--创建时间 : 2017-07-25
--修改记录流水:
--修改人        
--
--------------------------------------------------------------------------------

t T_BillQuery_TABLE;
r BillQueryRecord;

TYPE T_CURSOR IS REF CURSOR;
v_cur T_CURSOR;

V_SQL VARCHAR2(2000);

V_BillType VARCHAR2(20);
V_BillName VARCHAR2(50);
V_BillNo VARCHAR2(50);
V_SOURCEBILLNO VARCHAR2(50);
V_TerminalID VARCHAR2(50);
V_DESCRIPTION VARCHAR2(200);
V_ORGTYPE VARCHAR2(20);
V_ORGID VARCHAR2(50);
V_ORGNAME VARCHAR2(100);
V_PAYTYPE VARCHAR2(10);
V_PAYNAME VARCHAR2(50);
V_PAYNO VARCHAR2(50);
V_AMOUNT NUMBER(18,4);
V_POINT NUMBER(18,4);
V_BILLDATE DATE;
V_BILLTIME DATE;
	
BEGIN

	t := T_BillQuery_TABLE();
	
	--select a.BILLTYPE,b.BILLTYPENAME BILLNAME,a.BILLNO,a.TERMINALID,b.BILLTYPENAME DESCRIPTION,2 ORGTYPE,a.SHOPID ORGID,'' ORGNAME,1 PAYTYPE,'卡' PAYNAME,a.CARDNO PAYNO,(case a.ACCOUNTTYPE when 1 then a.DIRECT*a.CHANGEVALUE else 0 end) AMOUNT,(case a.ACCOUNTTYPE when 3 then a.DIRECT*a.CHANGEVALUE else 0 end) POINT,a.BILLDATE,a.BILLDATE BILLTIME 
	--from CRM_CARDACCOUNTCHANGE a 
	--left join CRM_BILLTYPE b on a.BILLTYPE=b.BILLTYPE
	--left join CRM_SHOP s on a.SHOPID = s.SHOPID

	V_SQL := ''
	||'select a.DIRECT,a.BILLTYPE,NVL(b.BILLTYPENAME,REASONID) BILLNAME,a.BILLNO,d.BILLNO as SOURCEBILLNO,a.TERMINALID,a.DESCRIPTION,''2'' ORGTYPE,a.SHOPID ORGID,'''' ORGNAME,''1'' PAYTYPE,''卡'' PAYNAME,a.CARDNO PAYNO,(case a.ACCOUNTTYPE when 1 then a.DIRECT*a.CHANGEVALUE else 0 end) AMOUNT,(case a.ACCOUNTTYPE when 3 then a.DIRECT*a.CHANGEVALUE else 0 end) POINT,a.CREATETIME BILLDATE,a.CREATETIME BILLTIME '
	||' from CRM_CARDACCOUNTCHANGE a '
	||' left join CRM_BILLTYPE b on a.BILLTYPE=b.BILLTYPE'
	||' left join DCP_ORG s on a.EID = s.EID and a.SHOPID = s.ORGANIZATIONNO'
	||' left join CRM_CARD c on a.EID = c.EID and a.CARDID = c.CARDID'
  ||' left join CRM_CONSUME_CARD d on a.EID = d.EID and a.BILLNO = d.CARDBILLNO and a.BILLTYPE=''CRM016'''
	||' where a.EID='''||P_EID||''''
	||' and a.BILLDATE >= to_date('''||P_BeginDate||''',''yyyy-MM-dd'')'
	||' and a.BILLDATE <= to_date('''||P_EndDate||''',''yyyy-MM-dd'')'
	||' and a.BILLTYPE <> ''CRM002'' and a.BILLTYPE <> ''CRM004'''
	;
	
	IF P_MemberID is not null THEN
		V_SQL := V_SQL ||' and c.MEMBERID = '''||P_MemberID||'''';
	END IF;		
	IF P_CardNo is not null THEN
		V_SQL := V_SQL ||' and a.CARDNO = '''||P_CardNo||'''';
	END IF;		
	
	--V_SQL := V_SQL||' order by a.CREATETIME';

	
	V_SQL := ''
	||'SELECT BILLTYPE,BILLNAME,BILLNO,SOURCEBILLNO,TERMINALID,DESCRIPTION,ORGTYPE,ORGID,ORGNAME,PAYTYPE,PAYNAME,PAYNO,'
	||'SUM(AMOUNT) AMOUNT,SUM(POINT) POINT,MAX(BILLDATE) BILLDATE, MAX(BILLTIME) BILLTIME'
  	--||'AMOUNT,POINT,BILLDATE,BILLTIME'
	||' FROM ('||V_Sql||')'
	||' GROUP BY DIRECT,BILLTYPE,BILLNAME,BILLNO,SOURCEBILLNO,TERMINALID,DESCRIPTION,ORGTYPE,ORGID,ORGNAME,PAYTYPE,PAYNAME,PAYNO';
	
	V_SQL := V_SQL||' order by BILLTIME';
	
	--V_SQL := 'select BILLTYPE,BILLNO from CRM_CARDACCOUNTCHANGE';

 	OPEN v_cur FOR V_SQL; 
   	FETCH v_cur INTO V_BillType,V_BillName,V_BillNo,V_SOURCEBILLNO,V_TerminalID,V_DESCRIPTION,V_ORGTYPE,V_ORGID,V_ORGNAME,V_PAYTYPE,V_PAYNAME,V_PAYNO,V_AMOUNT,V_POINT,V_BILLDATE,V_BILLTIME;
   	WHILE v_cur%FOUND
	LOOP        
		--r := BillQueryRecord();
		--r.BILLNO := V_BillNo;
		
		t.extend;
		t(t.count) := BillQueryRecord(V_BillType,V_BillName,V_BillNo,V_SOURCEBILLNO,V_TerminalID,V_DESCRIPTION,V_ORGTYPE,V_ORGID,V_ORGNAME,V_PAYTYPE,V_PAYNAME,V_PAYNO,V_AMOUNT,V_POINT,V_BILLDATE,V_BILLTIME);
     		
	FETCH v_cur INTO V_BillType,V_BillName,V_BillNo,V_SOURCEBILLNO,V_TerminalID,V_DESCRIPTION,V_ORGTYPE,V_ORGID,V_ORGNAME,V_PAYTYPE,V_PAYNAME,V_PAYNO,V_AMOUNT,V_POINT,V_BILLDATE,V_BILLTIME;	
     	END LOOP;
     	CLOSE v_cur;
     	

	return t;

END;

/
