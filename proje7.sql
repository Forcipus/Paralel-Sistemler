-- PROJE 7: OTOMATİK DİNAMİK YEDEKLEME SCRIPT'I
DECLARE @DBName NVARCHAR(100) = 'WideWorldImporters' -- Database adı
DECLARE @BackupFolder NVARCHAR(500) = 'C:\SQL_Yedekler\' -- Yedeklerin kaydedileceği klasör (Klasörü C'de önceden oluştur)
DECLARE @FileName NVARCHAR(500)
DECLARE @DateStamp NVARCHAR(20)

-- O anki tarih ve saati YYYYMMDD_HHMMSS formatına getiriyoruz (Üzerine yazmayı engellemek için)
SELECT @DateStamp = CONVERT(NVARCHAR(8), GETDATE(), 112) + '_' + 
                    REPLACE(CONVERT(NVARCHAR(8), GETDATE(), 108), ':', '')

-- Tam dosya yolunu oluşturuyoruz (Örn: C:\SQL_Yedekler\SeninVeritabanıAdın_20260605_190000.bak)
SET @FileName = @BackupFolder + @DBName + '_' + @DateStamp + '.bak'

-- Yedekleme komutunu çalıştırıyoruz
BACKUP DATABASE @DBName
TO DISK = @FileName
WITH FORMAT, 
     MEDIANAME = 'SQL_Automated_Backups',
     NAME = 'Full Backup of ' + @DBName,
     STATS = 10; -- İlerleme durumunu %10'da bir loglar
GO