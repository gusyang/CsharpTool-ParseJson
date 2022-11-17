USE [Imk]
GO
--drop proc dbo.UP_TransferPromotionItemsToHis
--go
CREATE PROCEDURE dbo.UP_TransferPromotionItemsToHis
AS
BEGIN    
SET NOCOUNT ON;   
    -- current trancount    
    DECLARE  @__trancount int;
    SELECT  @__trancount = @@TRANCOUNT;

    BEGIN TRY    
        DECLARE    
        @row_batch int,    
        @row_limit int,    
        @row_process int,    
        @row_count int;   
         
            
        -- row batch and data keep date    
        SELECT
            @row_batch = 500, -- each batch process rows    
            @row_limit = 200000, -- total row process limit    
            @row_process = 0;            -- process rows total    
            
        -- ===========================================    
        -- get process rows    
        SELECT @row_count = COUNT(a.TransactionNumber)
        FROM imk.dbo.[PromotionItems] a WITH(NOLOCK)
        INNER JOIN imk.[dbo].[PromotionCodeMaster_His] b with(NOLOCK) on 
        a.PromotionCode = b.PromotionCode ;    
            
        IF @row_count = 0      
            RETURN;                
            
		--Set @row_count = @row_batch;
        --RAISERROR('%d rows need process, current process limit %d rows', 10, 1, @row_count, @row_limit) WITH NOWAIT    
            
        WHILE @row_process < @row_limit  AND @row_count > 0                
        BEGIN
            -- move data    
            IF @__trancount = 0    
                BEGIN TRAN;    
            ELSE    
                SAVE TRAN __TRAN_SavePoint;  

            DELETE TOP(@row_batch) A 
            OUTPUT deleted.*    
            INTO imk.[dbo].[PromotionItems_His] 
            FROM imk.dbo.[PromotionItems] A with(NOLOCK) 
               INNER JOIN imk.[dbo].[PromotionCodeMaster_His] b with(NOLOCK) on 
				a.PromotionCode = b.PromotionCode;

            SELECT @row_count = @@ROWCOUNT,
                @row_process = @row_process + @row_count;

            IF XACT_STATE() = 1 AND @__trancount = 0        
                COMMIT;
                
            WAITFOR DELAY '00:00:05'
        END

            
        IF @__trancount = 0    
        BEGIN
            IF XACT_STATE() = -1    
        ROLLBACK TRAN;    
        ELSE    
        BEGIN
            WHILE @@TRANCOUNT > 0    
                COMMIT TRAN;
            END
        END    
    END TRY    
    BEGIN CATCH    
    IF XACT_STATE() <> 0    
    BEGIN
            IF @__trancount = 0    
                ROLLBACK TRAN;    
            ELSE IF XACT_STATE() = 1 AND @@TRANCOUNT > @__trancount    
                ROLLBACK TRAN __TRAN_SavePoint;
    END    
        
    DECLARE    
    @__error_number int,    
    @__error_message nvarchar(2048),    
    @__error_severity int,    
    @__error_state int,    
    @__error_line int,    
    @__error_procedure nvarchar(126),    
    @__user_name nvarchar(128),    
    @__host_name nvarchar(128);    
        
    SELECT
        @__error_number = ERROR_NUMBER(),
        @__error_message = ERROR_MESSAGE(),
        @__error_severity = ERROR_SEVERITY(),
        @__error_state = ERROR_STATE(),
        @__error_line = ERROR_LINE(),
        @__error_procedure = ERROR_PROCEDURE(),
        @__user_name = SUSER_SNAME(),
        @__host_name = HOST_NAME();    
        
    RAISERROR(    
    N'User: %s, Host: %s, Procedure: %s, Error %d, Level %d, State %d, Line %d, Message: %s ',    
    @__error_severity,    
    1,    
    @__user_name,    
    @__host_name,    
    @__error_procedure,    
    @__error_number,    
    @__error_severity,    
    @__error_state,    
    @__error_line,    
    @__error_message);    
    END CATCH   
END
