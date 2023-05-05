CREATE FUNCTION [dbo].[F_DCP_UNITCONVERT] (
    @P_EID NVARCHAR(50),
    @P_PluNo NVARCHAR(50),
    @P_FromUnit NVARCHAR(50),
    @P_ToUnit NVARCHAR(50),
    @P_Qty NUMERIC(23, 8)
)
RETURNS NUMERIC(23, 8)
AS
BEGIN
    --------------------------------------------------------------------------------
    --说明　　 : 获取单位换算量
    --数据流说明:
    --创建者   : JW
    --创建时间 : 2020-06-10
    --修改记录流水:
    --修改人        
    --返回：换算率
    --调用：select F_DCP_UnitConvert('99','001020001','KG','G',2)
    --------------------------------------------------------------------------------

    DECLARE @V_BreakPoint NVARCHAR(255);
    DECLARE @V_Err INTEGER;
    DECLARE @V_Msg NVARCHAR(255);

    DECLARE @V_RATE NUMERIC(18, 4);
    DECLARE @V_Qty NUMERIC(23, 8);

    BEGIN
        SET @V_BreakPoint = 'F_DCP_UnitConvert_010';

        SELECT @V_RATE = dbo.F_DCP_UNITCONVERT_RATE(@P_EID, @P_PluNo, @P_FromUnit, @P_ToUnit)

        SET @V_Qty = @V_RATE * @P_Qty;

        RETURN @V_Qty;
    END;
END;
GO
