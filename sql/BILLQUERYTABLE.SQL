CREATE FUNCTION [dbo].[F_CRM_BILLQUERY] (
    @P_EID NVARCHAR(50),
    @P_MemberID NVARCHAR(50),
    @P_CardNo NVARCHAR(50),
    @P_BeginDate NVARCHAR(10),
    @P_EndDate NVARCHAR(10)
)
RETURNS @T_BillQuery_TABLE TABLE (
    BILLTYPE NVARCHAR(20),
    BILLNAME NVARCHAR(50),
    BILLNO NVARCHAR(50),
    SOURCEBILLNO NVARCHAR(50),
    TERMINALID NVARCHAR(50),
    DESCRIPTION NVARCHAR(200),
    ORGTYPE NVARCHAR(20),
    ORGID NVARCHAR(50),
    ORGNAME NVARCHAR(100),
    PAYTYPE NVARCHAR(10),
    PAYNAME NVARCHAR(50),
    PAYNO NVARCHAR(50),
    AMOUNT NUMERIC(18, 4),
    POINT NUMERIC(18, 4),
    BILLDATE DATE,
    BILLTIME DATE
)
AS
BEGIN
    INSERT INTO @T_BillQuery_TABLE
    SELECT
        BILLTYPE,
        BILLNAME,
        BILLNO,
        SOURCEBILLNO,
        TERMINALID,
        DESCRIPTION,
        ORGTYPE,
        ORGID,
        ORGNAME,
        PAYTYPE,
        PAYNAME,
        PAYNO,
        SUM(AMOUNT) AS AMOUNT,
        SUM(POINT) AS POINT,
        MAX(BILLDATE) AS BILLDATE,
        MAX(BILLTIME) AS BILLTIME
    FROM (
        SELECT
            a.DIRECT,
            a.BILLTYPE,
            ISNULL(b.BILLTYPENAME, REASONID) BILLNAME,
            a.BILLNO,
            d.BILLNO AS SOURCEBILLNO,
            a.TERMINALID,
            a.DESCRIPTION,
            '2' AS ORGTYPE,
            a.SHOPID AS ORGID,
            '' AS ORGNAME,
            '1' AS PAYTYPE,
            '卡' AS PAYNAME,
            a.CARDNO AS PAYNO,
            (CASE a.ACCOUNTTYPE
                WHEN 1 THEN a.DIRECT * a.CHANGEVALUE
                ELSE 0
            END) AS AMOUNT,
            (CASE a.ACCOUNTTYPE
                WHEN 3 THEN a.DIRECT * a.CHANGEVALUE
                ELSE 0
            END) AS POINT,
            a.CREATETIME AS BILLDATE,
            a.CREATETIME AS BILLTIME
        FROM CRM_CARDACCOUNTCHANGE a
        LEFT JOIN CRM_BILLTYPE b ON a.BILLTYPE = b.BILLTYPE
        LEFT JOIN DCP_ORG s ON a.EID = s.EID AND a.SHOPID = s.ORGANIZATIONNO
        LEFT JOIN CRM_CARD c ON a.EID = c.EID AND a.CARDID = c.CARDID
        LEFT JOIN CRM_CONSUME_CARD d ON a.EID = d.EID AND a.BILLNO = d.CARDBILLNO AND a.BILLTYPE = 'CRM016'
        WHERE
            a.EID = @P_EID
            AND a.BILLDATE >= CONVERT(DATE, @P_BeginDate, 126)
            AND a.BILLDATE <= CONVERT(DATE, @P_EndDate, 126)
            AND a.BILLTYPE <> 'CRM002'
            AND a.BILLTYPE <> 'CRM004'
            AND (c.MEMBERID = @P_MemberID OR @P_MemberID IS NULL)
            AND (a.CARDNO = @P_CardNo OR @P_CardNo IS NULL)
    ) AS subquery
    GROUP BY
        DIRECT,
        BILLTYPE,
        BILLNAME,
        BILLNO,
        SOURCEBILLNO,
        TERMINALID,
        DESCRIPTION,
        ORGTYPE,
        ORGID,
        ORGNAME,
        PAYTYPE,
        PAYNAME,
        PAYNO
    ORDER BY
        BILLTIME;

    RETURN 
END;
