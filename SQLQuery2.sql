--Zamanlayıcılarla Yedekleme 
BACKUP DATABASE [WideWorldImporters] 
TO DISK = N'C:\Backups\WWI_Auto.bak' 
WITH NO_COMPRESSION, FORMAT, INIT; 

--Verinin Yanlışlıkla Silinmesi
DROP TABLE Sales.InvoiceLines;
SELECT * FROM Sales.Invoices WHERE InvoiceID > 70000;

--T-SQL ile Teknik Doğrulama
RESTORE VERIFYONLY 
FROM DISK = N'C:\'; 
      
--Checksum
BACKUP DATABASE [WideWorldImporters] 
TO DISK = N'C:\Backups\WWI_Checksum_Test.bak' 
WITH CHECKSUM;
