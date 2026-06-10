-- 1. ADIM: ETL İÇİN KİRLİ KAYNAK TABLONUN OLUŞTURULMASI (EXTRACT)
-- Orijinal tablodan veri çekiyoruz ama içine bilerek hatalar bırakıyoruz.

SELECT TOP 1000 
    CustomerID,
    CustomerName,
    -- 1. Hata: Bazı e-postaları bilerek NULL (eksik) yapıyoruz
    CASE WHEN CustomerID % 5 = 0 THEN NULL ELSE PrimaryContactPersonID END AS ContactPerson,
    
    -- 2. Hata: Telefon numaralarındaki parantez ve boşlukları bozarak tutarsız yapıyoruz
    CASE 
        WHEN CustomerID % 3 = 0 THEN REPLACE(REPLACE(PhoneNumber, '(', ''), ')', '')
        WHEN CustomerID % 4 = 0 THEN '000-000-0000' -- Hatalı/Sahte numara
        ELSE PhoneNumber 
    END AS PhoneNumber,
    
    -- 3. Hata: Şehir isimlerinde tutarsızlık ve küçük/büyük harf karmaşası yaratıyoruz
    CASE 
        WHEN CustomerID % 2 = 0 THEN LOWER(DeliveryAddressLine1)
        ELSE UPPER(DeliveryAddressLine1)
    END AS DeliveryAddress,
    
    -- 4. Hata: Kayıt tarihlerini string (yanlış format) olarak alıyoruz
    CONVERT(VARCHAR(50), AccountOpenedDate, 105) AS RegistrationDate
INTO WideWorldImporters.dbo.Ham_Musteri_Verisi -- Kirli ara tablomuz oluşuyor
FROM WideWorldImporters.Sales.Customers;
GO

------
-- 2.1 HEDEF TABLONUN (TEMİZ VERİ AMBARI) OLUŞTURULMASI
CREATE TABLE WideWorldImporters.dbo.Dim_Musteri_Temiz (
    CustomerID INT PRIMARY KEY,
    CustomerName NVARCHAR(100),
    ContactPerson NVARCHAR(50),      -- NULL yerine 'Bilinmiyor' yazacağız
    PhoneNumber NVARCHAR(30),        -- Formatı (XXX) XXX-XXXX yapacağız
    DeliveryAddress NVARCHAR(200),   -- Tamamı standart büyük harf olacak
    RegistrationDate DATE            -- VARCHAR'dan gerçek DATE formatına dönecek
);
GO

------
-- 2.2 VERİ TEMİZLEME VE DÖNÜŞTÜRME SORGUSU (TRANSFORM & LOAD)
TRUNCATE TABLE WideWorldImporters.dbo.Dim_Musteri_Temiz;
GO
INSERT INTO WideWorldImporters.dbo.Dim_Musteri_Temiz
SELECT 
    CustomerID,
    CustomerName,
    
    -- 1. Eksik Veri Temizleme: NULL olan yerlere COALESCE ile 'Bilinmiyor' atıyoruz
    ISNULL(CAST(ContactPerson AS NVARCHAR(50)), 'Bilinmiyor') AS ContactPerson,
    
    -- 2. Tutarsız Veri Temizleme: Telefonları temizleyip standart formata sokuyoruz
    -- Eğer sahte/hatalı '000-000-0000' ise onu da standart bir uyarı metnine çeviriyoruz
    CASE 
        WHEN PhoneNumber = '000-000-0000' THEN 'Geçersiz Numara'
        ELSE 
            -- Sayıları temizleyip standart (XXX) XXX-XXXX formatına getirme simülasyonu
            '(' + SUBSTRING(REPLACE(REPLACE(REPLACE(PhoneNumber, ' ', ''), '-', ''), ')', ''), 1, 3) + ') ' +
            SUBSTRING(REPLACE(REPLACE(REPLACE(PhoneNumber, ' ', ''), '-', ''), ')', ''), 4, 3) + '-' +
            SUBSTRING(REPLACE(REPLACE(REPLACE(PhoneNumber, ' ', ''), '-', ''), ')', ''), 7, 4)
    END AS PhoneNumber,
    
    -- 3. Standartlaştırma: Adreslerdeki büyük/küçük harf karmaşasını UPPER ile çözüyoruz
    UPPER(TRIM(DeliveryAddress)) AS DeliveryAddress,
    
    -- 4. Yanlış Format Dönüştürme: VARCHAR (105 - DD-MM-YYYY) olan veriyi gerçek DATE tipine çeviriyoruz
    CONVERT(DATE, RegistrationDate, 105) AS RegistrationDate

FROM WideWorldImporters.dbo.Ham_Musteri_Verisi;
GO
-------
-- 3.1 DIŞ KAYNAKTAN GELEN YABANCI/UYUMSUZ TABLONUN SİMÜLASYONU
CREATE TABLE WideWorldImporters.dbo.Dis_Kaynak_Musteri (
    DisID INT,
    Isim NVARCHAR(100),
    EyaletKodu NVARCHAR(10), -- Bizim sistemde 'StateProvinceID' var (Sayı), burada ise metin (Örn: 'NY', 'TX')
    MusteriTipi NVARCHAR(20) -- Bizim sistemde 'CustomerCategoryID' var, burada ise 'B2B', 'B2C' yazıyor
);

-- Örnek bir veri yüklüyoruz
INSERT INTO WideWorldImporters.dbo.Dis_Kaynak_Musteri VALUES 
(9001, 'Anadolu Lojistik', 'NY', 'B2B'),
(9002, 'Ahmet Yılmaz', 'TX', 'B2C');
GO
------
-- 3.2 FARKLI KAYNAKTAKİ VERİYİ BİZİM STANDARTLARIMIZA DÖNÜŞTÜRME SORGUSU
SELECT 
    dk.DisID AS CustomerID,
    dk.Isim AS CustomerName,
    
    -- Eyalet Metnini (NY, TX), WWI sistemindeki StateProvinceID (Sayı) karşılığına dönüştürüyoruz
    COALESCE(sp.StateProvinceID, 0) AS StateProvinceID,
    
    -- Müşteri Tipini (B2B, B2C), WWI sistemindeki CustomerCategoryID karşılığına dönüştürüyoruz
    CASE 
        WHEN dk.MusteriTipi = 'B2B' THEN (SELECT CustomerCategoryID FROM WideWorldImporters.Sales.CustomerCategories WHERE CustomerCategoryName = 'Novelty Items Shop')
        WHEN dk.MusteriTipi = 'B2C' THEN (SELECT CustomerCategoryID FROM WideWorldImporters.Sales.CustomerCategories WHERE CustomerCategoryName = 'Computer Store')
        ELSE 4 -- Diğer/Standart Kategori ID
    END AS CustomerCategoryID

FROM WideWorldImporters.dbo.Dis_Kaynak_Musteri dk
-- Eyalet kodlarını eşitlemek için WWI'ın kendi coğrafya tablosuyla JOIN atıyoruz (Entegrasyon)
LEFT JOIN WideWorldImporters.Application.StateProvinces sp 
    ON dk.EyaletKodu = sp.StateProvinceCode;
GO
------
-- 4.1 HEDEF TABLOYU KONTROL ETME VE FULL LOAD (TAM YÜKLEME) SİMÜLASYONU
USE WideWorldImporters;
GO

-- Eğer hedef tabloda önceden kalan test verileri varsa temizliyoruz (Truncate)
TRUNCATE TABLE dbo.Dim_Musteri_Temiz;
GO

-- Temizlenmiş verilerin nihai olarak hedef tabloya yüklenmesi (Load)
INSERT INTO dbo.Dim_Musteri_Temiz (CustomerID, CustomerName, ContactPerson, PhoneNumber, DeliveryAddress, RegistrationDate)
SELECT 
    CustomerID,
    CustomerName,
    ISNULL(CAST(ContactPerson AS NVARCHAR(50)), 'Bilinmiyor'),
    CASE 
        WHEN PhoneNumber = '000-000-0000' THEN 'Geçersiz Numara'
        ELSE 
            '(' + SUBSTRING(REPLACE(REPLACE(REPLACE(PhoneNumber, ' ', ''), '-', ''), ')', ''), 1, 3) + ') ' +
            SUBSTRING(REPLACE(REPLACE(REPLACE(PhoneNumber, ' ', ''), '-', ''), ')', ''), 4, 3) + '-' +
            SUBSTRING(REPLACE(REPLACE(REPLACE(PhoneNumber, ' ', ''), '-', ''), ')', ''), 7, 4)
    END,
    UPPER(TRIM(DeliveryAddress)),
    CONVERT(DATE, RegistrationDate, 105)
FROM dbo.Ham_Musteri_Verisi;
GO

-- 4.2 YÜKLENEN VERİLERİ KONTROL ETME
SELECT TOP 10 * FROM dbo.Dim_Musteri_Temiz;
GO
-------
-- 5.1 VERİ KALİTESİ VE ETL ÖZET RAPORU SORGUSU
USE WideWorldImporters;
GO

SELECT 
    (SELECT COUNT(*) FROM dbo.Ham_Musteri_Verisi) AS [Toplam İşlenen Satır Sayısı],
    
    (SELECT COUNT(*) FROM dbo.Dim_Musteri_Temiz WHERE ContactPerson = 'Bilinmiyor') AS [Düzeltilen Eksik Veri (NULL) Sayısı],
    
    (SELECT COUNT(*) FROM dbo.Dim_Musteri_Temiz WHERE PhoneNumber = 'Geçersiz Numara') AS [Yakalanan Sahte/Hatalı Telefon Sayısı],
    
    -- Veri Kalite Skorunu yüzde olarak hesaplayan dinamik alan
    CAST(
        (1.0 - (CAST((SELECT COUNT(*) FROM dbo.Dim_Musteri_Temiz WHERE PhoneNumber = 'Geçersiz Numara' OR ContactPerson = 'Bilinmiyor') AS FLOAT) / 
        CAST((SELECT COUNT(*) FROM dbo.Ham_Musteri_Verisi) AS FLOAT))) * 100 
    AS DECIMAL(5,2)) AS [Veri Kalite Başarı Skoru (%)]
GO