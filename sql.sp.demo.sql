USE [ECommerce2005]
GO


/******************************************************************
*Name        :  dbo.[UP_EC_Point_B2B_TmpJob_CourtesyBizPoint_SpecificCust2021]
*Function    :  Temp job to give biz point to given customer list
* 
*Input       :  @ApplyPoints, Points per customer,
*               @PTAccount  Point acct related to expanse.
*               @PromoBeginDate  Promotion begin.
*               @PromoEndDate  Promotion end.
*Output      : 
*Servername  :	NEWSQL
*Databasename:	ECommerce2005
*Table Used  :
	EC_Point_Transaction    
	Newegg_PremierAccount
	Newegg_Customer
    [EC_NeweggCustomerProfile]
    EC_Point_TMP_Data
*author      :  Gus Yang
*Requested By:  Victor Li(https://jira.newegg.org/browse/UBSD-1777)
*CreateDate  :  2021/1/29
*  1.	Create an account
*  2.	Enroll in the Rewards Program
*  3.	Make a $500 minimum purchase within 30 days

*  Duration: Feb 14 - Feb 28th
*  Bonus Points: 2,500 ($25 in value)
*
******************************************************************/
Create PROCEDURE [dbo].[UP_EC_Point_B2B_TmpJob_CourtesyBizPoint_SpecificCust2021]
    @PTAcctID INT = 926,
    @ApplyPoints INT = 2500,
    @PromoBeginDate DATETIME = '2021-2-15',
    @PromoEndDate DATETIME = '2021-3-15'
AS
SET NOCOUNT ON
BEGIN

    --Declare variable
    DECLARE  @tmpCount INT, @tmpIncrease INT, @tmpCustomerNumber INT, @tmpTransNO INT, @tmpInvoiceDate date, @tmpInvoiceNumber INT, @tmpMsg varchar(50),@tmpSONumber INT;

    /*======================Add Pending Point to Eligable Customer Begin ======================**/    
    --tmpAllInvoice: Qualified customer, have invoice in 30 days
    --tmpInvoice: each merchant have only one customer number qualify
    ;WITH tmpEnrolledCustomer
        AS
        (
            SELECT pa.CustomerNumber, pa.indate AS EnrolledDate, nc.EnteredDate,b.MerchantID
            FROM Ncustomer.dbo.Newegg_PremierAccount pa WITH(NOLOCK)
                INNER JOIN Ncustomer.dbo.Newegg_Customer nc WITH(NOLOCK)
                ON pa.customernumber = nc.customernumber
                INNER JOIN Customer.dbo.MerchantContact  B with(nolock) 
                ON pa.CustomerNumber = b.CustomerNumber                
            WHERE  pa.[Status] = 'A'
                AND pa.CountryCode = 'USB'
                AND pa.indate BETWEEN @PromoBeginDate AND @PromoEndDate
                AND NC.EnteredDate BETWEEN @PromoBeginDate AND @PromoEndDate
                AND not exists(
                    SELECT top 1 1 from dbo.EC_Point_TMP_Data with(nolock)
                    WHERE customernumber = nc.customernumber
                    )
        ),
        tmpCustomer 
        AS(
            SELECT b.CustomerNumber,  a.EnrolledDate,a.EnteredDate,a.MerchantID
            FROM tmpEnrolledCustomer A
            INNER JOIN Customer.dbo.MerchantContact  b with(nolock) 
            ON A.MerchantID = b.MerchantID
        ),
        tmpAllInvoice
        AS
        (
            SELECT InvoiceNumber, A.CustomerNumber, InvoiceAmount, InvoiceDate,B.MerchantID,A.SONumber
            FROM NACT.dbo.NewEgg_InvoiceMaster  A WITH(NOLOCK)
                INNER JOIN tmpCustomer B
                ON A.CustomerNumber = B.CustomerNumber
            WHERE  1 >= DATEDIFF(Day, A.InvoiceDate,GETDATE())
                AND 31 > DATEDIFF(Day, B.EnrolledDate,GETDATE())
        ),
        tmpInvoice
        AS(
            SELECT T.InvoiceNumber, CustomerNumber, InvoiceAmount, InvoiceDate,MerchantID,SONumber FROM tmpAllInvoice AS T
            INNER JOIN (
                SELECT MIN(InvoiceNumber) AS InvoiceNumber FROM tmpAllInvoice
                GROUP BY MerchantID
                HAVING SUM(InvoiceAmount) > 500    -- amount > 500
            ) AS B
            ON T.InvoiceNumber = B.InvoiceNumber
        )

    INSERT INTO dbo.EC_Point_TMP_Data
        ( [CustomerNumber], [EnteredDate] , [EnrolledDate] , [QualifyInvoiceNumber], InvoiceDate , [CountryCode] ,[InDate] , [InUser], MerchantID,SONumber )
    SELECT C.CustomerNumber, C.EnteredDate, C.EnrolledDate, I.InvoiceNumber, I.InvoiceDate, 'USB', GETDATE(), 'B2B Courtesyjob',I.MerchantID,I.SONumber
    FROM tmpCustomer C INNER JOIN tmpInvoice I 
		ON C.CustomerNumber = I.CustomerNumber
    WHERE NOT EXISTS(
	--One eligable merchant have only one record in this table
			SELECT TOP 1 1 FROM DBO.EC_Point_TMP_Data WITH(NOLOCK)
    WHERE MerchantID = C.MerchantID
		)
    --create tmpTB to loop customer by customer number
    IF object_id(N'tempdb.dbo.#tmpTB',N'U') IS NOT NULL
	BEGIN
        DROP TABLE  #tmpTB
    END

    CREATE TABLE #tmpTB
    (
        id int IDENTITY(1,1),
        customernumber int,
        invoicenumber int,
        invoicedate date,
        transno int,
		sonumber int
    );

    -- Only deal with record w/o  PointStatus, Update this stauts after insert pending points
    INSERT into #tmpTB
        (CustomerNumber, invoicenumber, invoicedate,sonumber)
    SELECT Customernumber, QualifyInvoiceNumber, InvoiceDate,SONumber
    FROM DBO.EC_Point_TMP_Data WITH(NOLOCK)
    WHERE PointStatus IS NULL;
    SELECT @tmpCount = SCOPE_IDENTITY(), @tmpIncrease = 1;

    WHILE @tmpIncrease <= @tmpCount
    BEGIN
        SELECT top 1
            @tmpCustomerNumber = CustomerNumber, @tmpInvoiceNumber = invoicenumber, @tmpInvoiceDate = invoicedate, @tmpSONumber = sonumber
        from #tmpTB
        WHERE id = @tmpIncrease;

        --DO not insert duplicate Courtesy point    
        IF NOT EXISTS(
		SELECT TOP 1
            1
        FROM dbo.EC_Point_Transaction WITH(NOLOCK)
        WHERE CustomerNumber = @tmpCustomerNumber AND EventType = 'CourtesyPoint' and CountryCode = 'USB' AND Status = 'P'
        )
        BEGIN
            --insert pending points to transaction table, connect with invoice, active time range  same as the point earned w/ order(invoice date + 30 days) 
            INSERT INTO [dbo].[EC_Point_Transaction]
                (PTAcctID, CustomerNumber, InitPoints, LeftPoints, SONumber, ItemNumber, ComboID
                , Qty, [Status], SODate,InvoiceNumber,InvoiceDate, EventType, Steps, CountryCode, CompanyCode, Memo
                , InDate, InUser, LastEditDate, LastEditUser,[ActivateDate] ,[ExpireDate] )
            VALUES(@PTAcctID, @tmpCustomerNumber, @ApplyPoints, @ApplyPoints, @tmpSONumber, '', 0
                , 0, 'P', GETDATE(), @tmpInvoiceNumber, @tmpInvoiceDate, 'CourtesyPoint', 0, 'USB', 1003, 'Courtesy Points'
                , GETDATE(), 'Job', GETDATE(), 'Courtesyjob', DATEADD(DAY,30,@tmpInvoiceDate), DATEADD(DAY,150,@tmpInvoiceDate));

            --update point transactionnumber to EC_Point_TMP_Data, for fulture active useage.
            SELECT @tmpTransNO = MAX(TransactionNumber)
            FROM dbo.EC_Point_Transaction WITH(NOLOCK)
            WHERE CustomerNumber = @tmpCustomerNumber and CountryCode = 'USB' AND EventType = 'CourtesyPoint';
            UPDATE TOP (1) A
			SET PointStatus = 'P', ActiveDate = DATEADD(DAY,30,@tmpInvoiceDate), [PointTransNo] = @tmpTransNO, Memo = '; Insert Pending Point'
			FROM DBO.EC_Point_TMP_Data A
			WHERE A.CustomerNumber = @tmpCustomerNumber AND CountryCode = 'USB';

            --Add to [EC_NeweggCustomerProfile], insert record if this customer don't exist in this table, otherwise, add this couresy point to pending points 
            IF NOT EXISTS(
			SELECT TOP 1
                1
            FROM [NCustomer].[dbo].[EC_NeweggCustomerProfile] WITH(NOLOCK)
            WHERE CustomerNumber = @tmpCustomerNumber and CountryCode = 'USB')
            BEGIN
                --insert customer profile as pending points
                INSERT INTO [NCustomer].[dbo].[EC_NeweggCustomerProfile]
                    (CustomerNumber, PendingPoints,CountryCode, CompanyCode, InDate, InUser,LastEditDate, LastEditUser)
                VALUES(@tmpCustomerNumber, @ApplyPoints, 'USB', 1003, GETDATE(), 'Job', GETDATE(), 'Courtesyjob');
            END
            ELSE
            BEGIN
                UPDATE TOP(1) A 
				SET PendingPoints = ISNULL(PendingPoints,0) + @ApplyPoints, 
                        LastEditDate = GETDATE(),
                        LastEditUser = 'Courtesyjob'
                FROM [NCustomer].[dbo].[EC_NeweggCustomerProfile] A
                WHERE CustomerNumber = @tmpCustomerNumber and CountryCode = 'USB';
            END
        END
        SELECT @tmpIncrease = @tmpIncrease + 1;
    END
    /*======================Add Pending Point to Eligable Customer End======================*/
    -- init tmp data 
    TRUNCATE TABLE #tmpTB;
    SELECT @tmpCount = 0, @tmpIncrease = 1, @tmpTransNO = 0, @tmpCustomerNumber = 0;
    /*======================Active Pending Point Begin================================**/
    --deal with records time to active and pointstatus is P
    INSERT INTO #tmpTB
        (customernumber,transno)
    SELECT CustomerNumber, [PointTransNo]
    FROM dbo.EC_Point_TMP_Data WITH(NOLOCK)
    WHERE 0 = DATEDIFF(d, ActiveDate, GetDate()) AND PointStatus = 'P';

    SELECT @tmpCount = SCOPE_IDENTITY();

    WHILE @tmpIncrease <= @tmpCount
    BEGIN
        SELECT top 1
            @tmpCustomerNumber = CustomerNumber, @tmpTransNO = transno
        from #tmpTB
        WHERE id = @tmpIncrease;

        --Check custom if still qualify to send this kind of point
        --1.Still a reward member
        --2.Have at least 1 eligible invoice[NOT RMA]
        IF NOT EXISTS(
			SELECT TOP 1
            1
        FROM Ncustomer.dbo.Newegg_PremierAccount pa WITH(NOLOCK)
        WHERE CustomerNumber = @tmpCustomerNumber AND Status = 'A'
            AND GETDATE() BETWEEN StartDate AND ExpirationDate
            AND CountryCode = 'USB'
            AND EXISTS(
				SELECT TOP 1
                1
            FROM NACT.dbo.NewEgg_InvoiceMaster WITH(NOLOCK)
            WHERE CustomerNumber = pa.CustomerNumber
                AND 0 = ISNULL(RMANumber,0)
			)
		)
		BEGIN
            --customer no longer qualify, rollback pending points in transaction table
            SET @tmpMsg = ';Cust Not Qualify'
            UPDATE TOP (1) P
			SET LeftPoints = 0, LastEditDate = GETDATE(), LastEditUser = 'B2B Courtesyjob', Memo = Memo + @tmpMsg
			FROM dbo.EC_Point_Transaction P
			WHERE TransactionNumber = @tmpTransNO AND CustomerNumber = @tmpCustomerNumber
                AND CountryCode = 'USB'
            IF ( @@ROWCOUNT = 0)
			BEGIN
                SET @tmpMsg = @tmpMsg + ';Point Transaction update fail'
            END

            --customer no longer qualify, rollback pending points in profile table			
            UPDATE TOP(1) A 
                    SET PendingPoints = ISNULL(PendingPoints,0) - @ApplyPoints, 
                        LastEditDate = GETDATE(),
                        LastEditUser = 'Courtesyjob'
                FROM [NCustomer].[dbo].[EC_NeweggCustomerProfile] A
                WHERE CustomerNumber = @tmpCustomerNumber and CountryCode = 'USB'
                AND 0 <=ISNULL(PendingPoints,0) - @ApplyPoints
            IF ( @@ROWCOUNT = 0 )
				BEGIN
                SET @tmpMsg = @tmpMsg + ';Profile data erro';
            END
            --customer no longer qualify, update tmp data status to error;
            UPDATE TOP (1) A
			SET PointStatus = 'E',  Memo = Memo + @tmpMsg, LastEditDate = GETDATE(), LastEditUser = 'Courtesyjob'
			FROM DBO.EC_Point_TMP_Data A
			WHERE A.CustomerNumber = @tmpCustomerNumber AND CountryCode = 'USB';
        END
		ELSE
		BEGIN
            --Active Pending Point
            SET @tmpMsg = '';

            UPDATE TOP (1) P
			SET Status = 'A', LastEditDate = GETDATE(), LastEditUser = 'B2B Courtesyjob', Memo = Memo + ';Active Courtesy Points',
			AvailableBalance = @ApplyPoints +(
				SELECT ISNULL(SUM(LeftPoints),0)
            FROM dbo.EC_Point_Transaction WITH(NOLOCK)
            WHERE CustomerNumber = @tmpCustomerNumber AND Status = 'A' AND LeftPoints > 0 AND CountryCode = 'USB'
			)
			FROM dbo.EC_Point_Transaction P
			WHERE TransactionNumber = @tmpTransNO AND CustomerNumber = @tmpCustomerNumber
                AND CountryCode = 'USB' AND Status = 'P';
            IF ( @@ROWCOUNT = 0)
			BEGIN
                SET @tmpMsg = @tmpMsg + ';Point Transaction update fail;'
            END
            -- Move pending point to active in profile
            UPDATE TOP(1) A 
                    SET PendingPoints = ISNULL(PendingPoints,0) - @ApplyPoints, 
						ActivePoints = ISNULL(ActivePoints,0) + @ApplyPoints,
                        PointsLastExpiredate = DATEADD(d,120,GetDate()),
                        LastEditDate = GETDATE(),
                        LastEditUser = 'Courtesyjob'
                FROM [NCustomer].[dbo].[EC_NeweggCustomerProfile] A
                WHERE CustomerNumber = @tmpCustomerNumber and CountryCode = 'USB'
                AND 0 <=ISNULL(PendingPoints,0) - @ApplyPoints AND 0<= ISNULL(ActivePoints,0)
            IF ( @@ROWCOUNT = 0 )
			BEGIN
                SET @tmpMsg = @tmpMsg + ';Profile data error';
            END

            -- No error message, update to A, this cust successed
            IF (@tmpMsg = '')
			BEGIN
                UPDATE TOP (1) A
				SET PointStatus = 'A',  Memo = Memo + ';Actived', LastEditDate = GETDATE(), LastEditUser = 'Courtesyjob'
				FROM DBO.EC_Point_TMP_Data A
				WHERE A.CustomerNumber = @tmpCustomerNumber AND CountryCode = 'USB';
            END
			ELSE
			BEGIN
                UPDATE TOP (1) A
				SET PointStatus = 'E',  Memo = Memo + @tmpMsg, LastEditDate = GETDATE(), LastEditUser = 'Courtesyjob'
				FROM DBO.EC_Point_TMP_Data A
				WHERE A.CustomerNumber = @tmpCustomerNumber AND CountryCode = 'USB'
            ;
            END
        END
        SELECT @tmpIncrease = @tmpIncrease + 1;
    END
/*======================Active Pending Point End================================**/
END

GO
