-- PROJE 1: PERFORMANS TESTİ İÇİN SORGULAR
USE WideWorldImporters;
GO

-- 1. KÖTÜ SORGUNUN ÇALIŞTIRILMASI (Yavaş ve Optimize Edilmemiş)
-- Tablonun tamamını tarar (Table Scan / Clustered Index Scan yapar)
SELECT InvoiceID, StockItemID, Quantity, UnitPrice, Description
FROM Sales.InvoiceLines
WHERE Description LIKE '%Red%' AND Quantity > 50;
GO
------
-- 2.1 PERFORMANSI UÇURACAK DOĞRU İNDEKSİN OLUŞTURULMASI
CREATE NONCLUSTERED INDEX IX_Sales_InvoiceLines_Quantity_Perf
ON Sales.InvoiceLines (Quantity) -- Arama kriterimiz olan ana kolon
INCLUDE (InvoiceID, StockItemID, UnitPrice, Description); -- SELECT ettiğimiz diğer yardımcı kolonlar
GO
------
-- KULLANILMAYAN VE GEREKSİZ İNDEKSLEERİ TESPİT EDEN DMV SORGUSU
USE WideWorldImporters;
GO

SELECT 
    OBJECT_NAME(i.object_id) AS [Tablo Adı],
    i.name AS [Gereksiz İndeks Adı],
    user_seeks AS [Arama (Seek) Sayısı],
    user_scans AS [Tarama (Scan) Sayısı],
    user_updates AS [Güncelleme/Yazma Maliyeti] -- Veri eklenirken bu indeksi güncellemek için harcanan emek
FROM sys.indexes i
INNER JOIN sys.dm_db_index_usage_stats s 
    ON s.object_id = i.object_id AND s.index_id = i.index_id
WHERE OBJECTPROPERTY(i.object_id, 'IsUserTable') = 1
  AND user_seeks = 0 -- Hiç nokta atışı aramada kullanılmamış
  AND i.type_desc = 'NONCLUSTERED' -- Ana iskelet olmayan yardımcı indeksler
ORDER BY user_updates DESC; -- Yazma maliyeti en yüksek olanı öne çıkar
GO
-------
-- 3.1 KÖTÜ SORGU (Sargable Olmayan - İndeksi Kıran Yapı)
USE WideWorldImporters;
GO

SELECT CustomerID, CustomerName, AccountOpenedDate
FROM Sales.Customers
WHERE YEAR(AccountOpenedDate) = 2013; -- Filtre içinde fonksiyon kullanımı (Hatalı Mantık!)
GO
-----
-- 3.2 İYİLEŞTİRİLMİŞ SORGU (Sargable - Performans Dostu Mantık)
USE WideWorldImporters;
GO

SELECT CustomerID, CustomerName, AccountOpenedDate
FROM Sales.Customers
-- Kolonu rahat bırakıp, aramayı net tarih aralıklarına bölüyoruz
WHERE AccountOpenedDate >= '2013-01-01' AND AccountOpenedDate <= '2013-12-31';
GO
-------
-- 4.1: FARKLI ROLLER İÇİN ERİŞİM YÖNETİMİ
USE WideWorldImporters;
GO

-- 1. ADIM: SİSTEMDE ROLLERİ OLUŞTURUYORUZ (Database Roles)
CREATE ROLE Veri_Analisti_Rolu;
CREATE ROLE Yazilim_Gelistirici_Rolu;
GO

-- 2. ADIM: ROLLERİN YETKİLERİNİ TANIMLIYORUZ
-- Veri Analisti sadece Sales şemasındaki tabloları okuyabilsin (SELECT)
GRANT SELECT ON SCHEMA::Sales TO Veri_Analisti_Rolu;

-- Yazılım Geliştirici Sales şemasında her türlü DML işlemini yapabilsin
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::Sales TO Yazilim_Gelistirici_Rolu;
GO

-- 3. ADIM: TEST İÇİN SQL SERVER LOGIN VE USER'LARINI OLUŞTURUYORUZ
-- Sistem giriş anahtarları (Login)
CREATE LOGIN AnalistTugrul WITH PASSWORD = 'Sifre123_Analist';
CREATE LOGIN GelistiriciTugrul WITH PASSWORD = 'Sifre123_Dev';
GO

-- Veritabanı kullanıcıları (User)
CREATE USER U_Analist FOR LOGIN AnalistTugrul;
CREATE USER U_Gelistirici FOR LOGIN GelistiriciTugrul;
GO

-- 4. ADIM: KULLANICILARI OLUŞTURDUĞUMUZ ROLLERE ATIYORUZ
ALTER ROLE Veri_Analisti_Rolu ADD MEMBER U_Analist;
ALTER ROLE Yazilim_Gelistirici_Rolu ADD MEMBER U_Gelistirici;
GO
-------
-- Analist kullanıcısının kimliğine bürünüyoruz
EXECUTE AS USER = 'U_Analist';

-- TEST 1: Okuma işlemi (Başarılı olması gerekir)
SELECT TOP 5 CustomerID, CustomerName FROM Sales.Customers;

-- TEST 2: Silme işlemi (Hata vermesi gerekir - Yetki Yok)
DELETE FROM Sales.Customers WHERE CustomerID = 1;

-- Kendi admin kimliğimize geri dönüyoruz
REVERT;
GO
