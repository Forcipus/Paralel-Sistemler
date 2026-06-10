--Zafiyetli Kod Örneği:
USE WideWorldImporters;
DECLARE @UserName NVARCHAR(50) = ''' OR ''1''=''1'; 
DECLARE @Query NVARCHAR(MAX) = 'SELECT * FROM Application.People WHERE LogonName = ''' + @UserName + '''';
EXEC sp_executesql @Query;


--A. Kimlik Doğrulama Atlatma (Authentication Bypass)
USE WideWorldImporters;
SELECT FullName, EmailAddress 
FROM Application.People 
WHERE LogonName = '' OR 1=1 --';

--B. Veri Sızdırma (UNION Based SQLi)
USE WideWorldImporters;
SELECT FullName FROM Application.People WHERE PersonID = -1
UNION
SELECT name FROM sys.databases;

--A. Parametreli Sorgular (Prepared Statements)
USE WideWorldImporters;
DECLARE @SecureUser NVARCHAR(50) = 'Admin';
SELECT * FROM Application.People WHERE LogonName = @SecureUser;

--B. Stored Procedure (Saklı Yordam) Kullanımı
USE WideWorldImporters;
GO
CREATE PROCEDURE dbo.usp_GetUserProfile
    @LogonName NVARCHAR(50)
AS
BEGIN
    SELECT FullName, EmailAddress FROM Application.People WHERE LogonName = @LogonName;
END;

-- Zafiyetli Sorgu Örneği
USE WideWorldImporters;
DECLARE @UserEntry NVARCHAR(MAX);
-- Saldırganın girişi: ' OR '1'='1
SET @UserEntry = ''' OR ''1''=''1'; 

DECLARE @DynamicSQL NVARCHAR(MAX);
SET @DynamicSQL = 'SELECT FullName, EmailAddress, PhoneNumber 
                   FROM Application.People 
                   WHERE LogonName = ''' + @UserEntry + '''';

PRINT 'Çalıştırılan Sorgu: ' + @DynamicSQL;
EXEC sp_executesql @DynamicSQL;

-- Güvenli (Parametreli) Sorgu Örneği
USE WideWorldImporters;
DECLARE @SecureEntry NVARCHAR(MAX) = ''' OR ''1''=''1'; -- Aynı saldırı girişi

-- Parametreli yapı kullanımı
EXEC sp_executesql 
    N'SELECT FullName, EmailAddress, PhoneNumber 
      FROM Application.People 
      WHERE LogonName = @LogonName', 
    N'@LogonName NVARCHAR(MAX)', 
    @LogonName = @SecureEntry;

--Stored Procedure ile Korunma
CREATE PROCEDURE dbo.usp_GetPersonProfile
@LogonName NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT FullName, EmailAddress, PhoneNumber 
    FROM Application.People 
    WHERE LogonName = @LogonName;
END;
