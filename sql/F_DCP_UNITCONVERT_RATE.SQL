CREATE FUNCTION F_DCP_UNITCONVERT_RATE (
    @P_EID NVARCHAR(50),
    @P_PluNo NVARCHAR(50),
    @P_FromUnit NVARCHAR(50),
    @P_ToUnit NVARCHAR(50)
)
RETURNS FLOAT
AS
BEGIN
    DECLARE
        @V_RATE FLOAT,
        @V_TempRate FLOAT,
        @V_BASEUNIT NVARCHAR(32),
        @V_Success1 INT,
        @V_Success2 INT,
        @V_Rate1 FLOAT,
        @V_div1 FLOAT,
        @V_Rate2 FLOAT,
        @V_div2 FLOAT,
        @V_OQTY FLOAT,
        @V_QTY FLOAT;

    IF @P_FromUnit = @P_ToUnit
    BEGIN
        RETURN 1;
    END;

    -- 1.先别管基准单位，从通用单位查找有没有直接的换算关系
    BEGIN
        SELECT @V_TempRate = UNIT_RATIO
        FROM DCP_UNITCONVERT
        WHERE EID = @P_EID
            AND OUNIT = @P_FromUnit
            AND UNIT = @P_ToUnit;

        IF @@ROWCOUNT > 0
        BEGIN
            SET @V_RATE = @V_TempRate;
            RETURN @V_RATE;
        END
        ELSE
        BEGIN
            SELECT @V_TempRate = UNIT_RATIO
            FROM DCP_UNITCONVERT
            WHERE EID = @P_EID
                AND OUNIT = @P_ToUnit
                AND UNIT = @P_FromUnit;

            IF @@ROWCOUNT > 0
            BEGIN
                SET @V_RATE = ROUND(1 / @V_TempRate, 8);
                RETURN @V_RATE;
            END;
        END;
    END;

    -- 2.再取基准单位，尝试通过基准单位来做换算
    BEGIN
        SELECT @V_BASEUNIT = BASEUNIT
        FROM DCP_GOODS
        WHERE EID = @P_EID AND PLUNO = @P_PluNo;

        IF @@ROWCOUNT = 0
        BEGIN
            RAISERROR('品号%s单位换算失败,品号信息不存在', 16, 1, @P_PluNo);
            RETURN NULL;
        END;
    END;

    SET @V_Success1 = 0;
    IF @P_FromUnit = @V_BASEUNIT
    BEGIN
        SET @V_Rate1 = 1;
        SET @V_div1 = 1;
        SET @V_Success1 = 1;
    END
    ELSE
    BEGIN
        SELECT @V_TempRate = UNIT_RATIO
        FROM DCP_UNITCONVERT
        WHERE EID = @P_EID
            AND OUNIT = @P_FromUnit
            AND UNIT = @V_BASEUNIT;

        IF @@ROWCOUNT > 0
        BEGIN
            SET @V_Rate1 = @V_TempRate;
            SET @V_div1 = 1;
            SET @V_Success1 = 1;
        END
        ELSE
        BEGIN
            SELECT @V_TempRate = UNIT_RATIO
            FROM DCP_UNITCONVERT
            WHERE EID=@P_EID AND OUNIT = @V_BASEUNIT AND UNIT = @P_FromUnit;
			IF @@ROWCOUNT > 0
			BEGIN
				SET @V_Rate1 = 1;
				SET @V_div1 = @V_TempRate;
				SET @V_Success1 = 1;
			END;
		END;
	END;

	SET @V_Success2 = 0;
	IF @P_ToUnit = @V_BASEUNIT
	BEGIN
		SET @V_Rate2 = 1;
		SET @V_div2 = 1;
		SET @V_Success2 = 1;
	END
	ELSE
	BEGIN
		SELECT @V_TempRate = UNIT_RATIO
		FROM DCP_UNITCONVERT
		WHERE EID = @P_EID
			AND OUNIT = @V_BASEUNIT
			AND UNIT = @P_ToUnit;

		IF @@ROWCOUNT > 0
		BEGIN
			SET @V_Rate2 = @V_TempRate;
			SET @V_div2 = 1;
			SET @V_Success2 = 1;
		END
		ELSE
		BEGIN
			SELECT @V_TempRate = UNIT_RATIO
			FROM DCP_UNITCONVERT
			WHERE EID = @P_EID
				AND OUNIT = @P_ToUnit
				AND UNIT = @V_BASEUNIT;

			IF @@ROWCOUNT > 0
			BEGIN
				SET @V_Rate2 = 1;
				SET @V_div2 = @V_TempRate;
				SET @V_Success2 = 1;
			END;
		END;
	END;

	IF @V_Success1 = 1 AND @V_Success2 = 1
	BEGIN
		SET @V_RATE = ROUND((@V_Rate1 * @V_Rate2) / (@V_div1 * @V_div2), 8);
		RETURN @V_RATE;
	END;

	IF @V_Success1 = 0
	BEGIN
		SELECT @V_OQTY = OQTY, @V_QTY = QTY
		FROM DCP_GOODS_UNIT
		WHERE EID = @P_EID
			AND PLUNO = @P_PluNo
			AND OUNIT = @P_FromUnit
			AND UNIT = @V_BASEUNIT;

		IF @@ROWCOUNT > 0
		BEGIN
			SET @V_Rate1 = @V_QTY;
			SET @V_div1 = @V_OQTY;
			SET @V_Success1 = 1;
		END
		ELSE
		BEGIN
			SELECT @V_OQTY = OQTY, @V_QTY = QTY
			FROM DCP_GOODS_UNIT
			WHERE EID = @P_EID
				AND PLUNO = @P_PluNo
				AND OUNIT = @V_BASEUNIT
				AND UNIT = @P_FromUnit;

			IF @@ROWCOUNT > 0
			BEGIN
				SET @V_Rate1 = @V_OQTY;
				SET @V_div1 = @V_QTY;
				SET @V_Success1 = 1;
			END;
		END;
	END;

	IF @V_Success2 = 0
	BEGIN
		SELECT @V_OQTY = OQTY, @V_QTY = QTY
		FROM DCP_GOODS_UNIT
		WHERE EID = @P_EID
			AND PLUNO = @P_PluNo
			AND OUNIT = @V_BASEUNIT
			AND UNIT = @P_ToUnit;
		IF @@ROWCOUNT > 0
		BEGIN
			SET @V_RATE2 = @V_QTY;
			SET @V_DIV2 = @V_OQTY;
			SET @V_Success2 = 1;
		END
		ELSE
		BEGIN
			SELECT @V_OQTY = OQTY, @V_QTY = QTY
			FROM DCP_GOODS_UNIT
			WHERE EID = @P_EID
				AND PLUNO = @P_PluNo
				AND OUNIT = @P_ToUnit
				AND UNIT = @V_BASEUNIT;

			IF @@ROWCOUNT > 0
			BEGIN
				SET @V_Rate2 = @V_OQTY;
				SET @V_Div2 = @V_QTY;
				SET @V_Success2 = 1;
			END;
		END;
	END;

	IF @V_Success1 = 1 AND @V_Success2 = 1
	BEGIN
		SET @V_Rate = ROUND((@V_Rate1 * @V_Rate2) / (@V_Div1 * @V_Div2), 8);
		RETURN @V_Rate;
	END
	ELSE
	BEGIN
		RAISERROR('品号 %s 单位换算失败 %s => %s', 16, 1, @P_PluNo, @P_FromUnit, @P_ToUnit);
		RETURN NULL;
	END;
END;
GO
