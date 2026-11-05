
/* =========================================================
   GLOBAL CRIME INTELLIGENCE & PUBLIC SAFETY ANALYTICS
   Database: Your current SQL Server database
   Table: dbo.Global_Crime_Analytics_Master
   Platform: Microsoft SQL Server
   ========================================================= */

SET NOCOUNT ON;

-- 0. VERIFY TABLE
IF OBJECT_ID('dbo.Global_Crime_Analytics_Master', 'U') IS NULL
BEGIN
    THROW 50001,
    'Table dbo.Global_Crime_Analytics_Master does not exist. Import the CSV first.',
    1;
END;

------------------------------------------------------------
-- 1. GENERAL DATA OVERVIEW
------------------------------------------------------------

-- Total records
SELECT COUNT(*) AS Total_Records
FROM dbo.Global_Crime_Analytics_Master;

-- Table columns and data types
SELECT
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Global_Crime_Analytics_Master'
ORDER BY ORDINAL_POSITION;

-- Available years
SELECT
    MIN([year]) AS First_Year,
    MAX([year]) AS Last_Year,
    COUNT(DISTINCT [year]) AS Number_Of_Years
FROM dbo.Global_Crime_Analytics_Master;

-- Countries and geographical coverage
SELECT
    COUNT(DISTINCT geo_code) AS Unique_Geographies,
    COUNT(DISTINCT country_name) AS Unique_Country_Names,
    COUNT(DISTINCT country_code) AS Unique_Country_Codes
FROM dbo.Global_Crime_Analytics_Master;

-- Records by source
SELECT
    source_publisher,
    source_dataset,
    COUNT(*) AS Total_Records
FROM dbo.Global_Crime_Analytics_Master
GROUP BY source_publisher, source_dataset
ORDER BY Total_Records DESC;

-- Records by module
SELECT
    module,
    COUNT(*) AS Total_Records
FROM dbo.Global_Crime_Analytics_Master
GROUP BY module
ORDER BY Total_Records DESC;


------------------------------------------------------------
-- 2. DATA QUALITY ANALYSIS
------------------------------------------------------------

-- Missing values by important columns
SELECT
    COUNT(*) AS Total_Rows,

    SUM(CASE WHEN country_code IS NULL OR LTRIM(RTRIM(country_code)) = '' THEN 1 ELSE 0 END) AS Missing_Country_Code,

    SUM(CASE WHEN geo_code IS NULL OR LTRIM(RTRIM(geo_code)) = '' THEN 1 ELSE 0 END) AS Missing_Geo_Code,

    SUM(CASE WHEN country_name IS NULL OR LTRIM(RTRIM(country_name)) = '' THEN 1 ELSE 0 END) AS Missing_Country_Name,

    SUM(CASE WHEN [year] IS NULL THEN 1 ELSE 0 END) AS Missing_Year,

    SUM(CASE WHEN indicator_code IS NULL OR LTRIM(RTRIM(indicator_code)) = '' THEN 1 ELSE 0 END) AS Missing_Indicator_Code,

    SUM(CASE WHEN [value] IS NULL THEN 1 ELSE 0 END) AS Missing_Value

FROM dbo.Global_Crime_Analytics_Master;

-- Missing values by data quality flag
SELECT
    data_quality_flag,
    COUNT(*) AS Total_Records
FROM dbo.Global_Crime_Analytics_Master
GROUP BY data_quality_flag
ORDER BY Total_Records DESC;

-- Negative values
SELECT *
FROM dbo.Global_Crime_Analytics_Master
WHERE [value] < 0;

-- Possible duplicate records
-- This is a candidate key for investigation, not proof of duplication.
SELECT
    geo_code,
    [year],
    indicator_code,
    sex,
    victim_relationship,
    measure_type,
    source_dataset,
    COUNT(*) AS Duplicate_Count
FROM dbo.Global_Crime_Analytics_Master
GROUP BY
    geo_code,
    [year],
    indicator_code,
    sex,
    victim_relationship,
    measure_type,
    source_dataset
HAVING COUNT(*) > 1
ORDER BY Duplicate_Count DESC;

-- Available indicator codes
SELECT
    indicator_code,
    indicator_name,
    COUNT(*) AS Total_Records
FROM dbo.Global_Crime_Analytics_Master
GROUP BY indicator_code, indicator_name
ORDER BY Total_Records DESC;

-- Crime categories
SELECT
    crime_category,
    COUNT(*) AS Total_Records
FROM dbo.Global_Crime_Analytics_Master
GROUP BY crime_category
ORDER BY Total_Records DESC;

-- Sex categories
SELECT
    sex,
    COUNT(*) AS Total_Records
FROM dbo.Global_Crime_Analytics_Master
GROUP BY sex
ORDER BY Total_Records DESC;

-- Measurement types
SELECT
    measure_type,
    unit,
    COUNT(*) AS Total_Records
FROM dbo.Global_Crime_Analytics_Master
GROUP BY measure_type, unit
ORDER BY Total_Records DESC;


------------------------------------------------------------
-- 3. GLOBAL HOMICIDE ANALYSIS
-- Indicator: VC.IHR.PSRC.P5
------------------------------------------------------------

-- Global average homicide rate by year
SELECT
    [year],
    AVG([value]) AS Average_Country_Homicide_Rate,
    COUNT(DISTINCT geo_code) AS Reporting_Geographies
FROM dbo.Global_Crime_Analytics_Master
WHERE indicator_code = 'VC.IHR.PSRC.P5'
GROUP BY [year]
ORDER BY [year];

-- Homicide rate by country and year
SELECT
    geo_code,
    country_name,
    region,
    income_group,
    [year],
    AVG([value]) AS Homicide_Rate
FROM dbo.Global_Crime_Analytics_Master
WHERE indicator_code = 'VC.IHR.PSRC.P5'
GROUP BY
    geo_code,
    country_name,
    region,
    income_group,
    [year]
ORDER BY [year], Homicide_Rate DESC;

-- Latest available homicide rate per country
WITH CountryRates AS
(
    SELECT
        geo_code,
        country_name,
        region,
        income_group,
        [year],
        AVG([value]) AS Homicide_Rate
    FROM dbo.Global_Crime_Analytics_Master
    WHERE indicator_code = 'VC.IHR.PSRC.P5'
    GROUP BY
        geo_code,
        country_name,
        region,
        income_group,
        [year]
),
RankedRates AS
(
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY geo_code
            ORDER BY [year] DESC
        ) AS rn
    FROM CountryRates
)
SELECT
    geo_code,
    country_name,
    region,
    income_group,
    [year],
    Homicide_Rate
FROM RankedRates
WHERE rn = 1
ORDER BY Homicide_Rate DESC;

-- Top 15 countries by latest available homicide rate
WITH CountryRates AS
(
    SELECT
        geo_code,
        country_name,
        [year],
        AVG([value]) AS Homicide_Rate
    FROM dbo.Global_Crime_Analytics_Master
    WHERE indicator_code = 'VC.IHR.PSRC.P5'
    GROUP BY geo_code, country_name, [year]
),
RankedRates AS
(
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY geo_code
            ORDER BY [year] DESC
        ) AS rn
    FROM CountryRates
)
SELECT TOP 15
    country_name,
    [year],
    Homicide_Rate
FROM RankedRates
WHERE rn = 1
ORDER BY Homicide_Rate DESC;

-- Lowest 15 countries by latest available rate
WITH CountryRates AS
(
    SELECT
        geo_code,
        country_name,
        [year],
        AVG([value]) AS Homicide_Rate
    FROM dbo.Global_Crime_Analytics_Master
    WHERE indicator_code = 'VC.IHR.PSRC.P5'
    GROUP BY geo_code, country_name, [year]
),
RankedRates AS
(
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY geo_code
            ORDER BY [year] DESC
        ) AS rn
    FROM CountryRates
)
SELECT TOP 15
    country_name,
    [year],
    Homicide_Rate
FROM RankedRates
WHERE rn = 1
ORDER BY Homicide_Rate ASC;

-- Homicide rate by region and year
SELECT
    region,
    [year],
    AVG([value]) AS Average_Homicide_Rate,
    COUNT(DISTINCT geo_code) AS Reporting_Geographies
FROM dbo.Global_Crime_Analytics_Master
WHERE indicator_code = 'VC.IHR.PSRC.P5'
GROUP BY region, [year]
ORDER BY [year], Average_Homicide_Rate DESC;

-- Homicide rate by income group
SELECT
    income_group,
    [year],
    AVG([value]) AS Average_Homicide_Rate,
    COUNT(DISTINCT geo_code) AS Reporting_Geographies
FROM dbo.Global_Crime_Analytics_Master
WHERE indicator_code = 'VC.IHR.PSRC.P5'
GROUP BY income_group, [year]
ORDER BY [year], Average_Homicide_Rate DESC;


------------------------------------------------------------
-- 4. YEAR-OVER-YEAR HOMICIDE TRENDS
------------------------------------------------------------

WITH YearlyRates AS
(
    SELECT
        geo_code,
        country_name,
        [year],
        AVG([value]) AS Homicide_Rate
    FROM dbo.Global_Crime_Analytics_Master
    WHERE indicator_code = 'VC.IHR.PSRC.P5'
    GROUP BY geo_code, country_name, [year]
),
Trend AS
(
    SELECT *,
        LAG([year]) OVER (
            PARTITION BY geo_code
            ORDER BY [year]
        ) AS Previous_Reported_Year,

        LAG(Homicide_Rate) OVER (
            PARTITION BY geo_code
            ORDER BY [year]
        ) AS Previous_Rate
    FROM YearlyRates
)
SELECT
    country_name,
    [year],
    Homicide_Rate,
    Previous_Reported_Year,
    Previous_Rate,
    CASE
        WHEN Previous_Rate IS NULL THEN NULL
        WHEN [year] - Previous_Reported_Year <> 1 THEN NULL
        ELSE Homicide_Rate - Previous_Rate
    END AS YoY_Change_Per_100K,
    CASE
        WHEN Previous_Rate IS NULL THEN NULL
        WHEN [year] - Previous_Reported_Year <> 1 THEN NULL
        ELSE ((Homicide_Rate - Previous_Rate) / NULLIF(Previous_Rate, 0)) * 100
    END AS YoY_Change_Percentage
FROM Trend
ORDER BY country_name, [year];


------------------------------------------------------------
-- 5. MALE VS FEMALE HOMICIDE ANALYSIS
------------------------------------------------------------

-- Global male and female rates by year
SELECT
    [year],

    AVG(CASE
        WHEN indicator_code = 'VC.IHR.PSRC.MA.P5'
        THEN [value]
    END) AS Male_Homicide_Rate,

    AVG(CASE
        WHEN indicator_code = 'VC.IHR.PSRC.FE.P5'
        THEN [value]
    END) AS Female_Homicide_Rate

FROM dbo.Global_Crime_Analytics_Master
WHERE indicator_code IN
(
    'VC.IHR.PSRC.MA.P5',
    'VC.IHR.PSRC.FE.P5'
)
GROUP BY [year]
ORDER BY [year];

-- Male vs female by country and year
SELECT
    geo_code,
    country_name,
    [year],

    AVG(CASE
        WHEN indicator_code = 'VC.IHR.PSRC.MA.P5'
        THEN [value]
    END) AS Male_Rate,

    AVG(CASE
        WHEN indicator_code = 'VC.IHR.PSRC.FE.P5'
        THEN [value]
    END) AS Female_Rate

FROM dbo.Global_Crime_Analytics_Master
WHERE indicator_code IN
(
    'VC.IHR.PSRC.MA.P5',
    'VC.IHR.PSRC.FE.P5'
)
GROUP BY geo_code, country_name, [year]
ORDER BY [year], country_name;

-- Male to female rate ratio
WITH SexRates AS
(
    SELECT
        geo_code,
        country_name,
        [year],

        AVG(CASE
            WHEN indicator_code = 'VC.IHR.PSRC.MA.P5'
            THEN [value]
        END) AS Male_Rate,

        AVG(CASE
            WHEN indicator_code = 'VC.IHR.PSRC.FE.P5'
            THEN [value]
        END) AS Female_Rate

    FROM dbo.Global_Crime_Analytics_Master
    WHERE indicator_code IN
    (
        'VC.IHR.PSRC.MA.P5',
        'VC.IHR.PSRC.FE.P5'
    )
    GROUP BY geo_code, country_name, [year]
)
SELECT
    country_name,
    [year],
    Male_Rate,
    Female_Rate,
    Male_Rate / NULLIF(Female_Rate, 0) AS Male_Female_Ratio
FROM SexRates
ORDER BY [year], Male_Female_Ratio DESC;


------------------------------------------------------------
-- 6. EUROSTAT CRIME ANALYSIS
------------------------------------------------------------

-- Recorded homicide counts by year
SELECT
    [year],
    SUM([value]) AS Recorded_Homicide_Count,
    COUNT(DISTINCT geo_code) AS Reporting_Geographies
FROM dbo.Global_Crime_Analytics_Master
WHERE indicator_code = 'ICCS0101_NR'
  AND source_dataset = 'crim_off_cat'
  AND measure_type = 'Count'
GROUP BY [year]
ORDER BY [year];

-- European crime categories by year
SELECT
    [year],
    crime_category,
    indicator_name,
    SUM([value]) AS Recorded_Count,
    COUNT(DISTINCT geo_code) AS Reporting_Geographies
FROM dbo.Global_Crime_Analytics_Master
WHERE source_dataset = 'crim_off_cat'
  AND measure_type = 'Count'
GROUP BY
    [year],
    crime_category,
    indicator_name
ORDER BY [year], Recorded_Count DESC;

-- Offence codes and categories
SELECT
    offence_code,
    crime_category,
    indicator_name,
    COUNT(*) AS Total_Records
FROM dbo.Global_Crime_Analytics_Master
WHERE source_dataset = 'crim_off_cat'
GROUP BY offence_code, crime_category, indicator_name
ORDER BY Total_Records DESC;

-- European reporting coverage by year
SELECT
    [year],
    COUNT(DISTINCT geo_code) AS Reporting_Geographies
FROM dbo.Global_Crime_Analytics_Master
WHERE source_dataset = 'crim_off_cat'
  AND measure_type = 'Count'
GROUP BY [year]
ORDER BY [year];

-- Victim relationship records
SELECT
    [year],
    victim_relationship,
    sex,
    COUNT(*) AS Number_Of_Records,
    AVG([value]) AS Average_Value
FROM dbo.Global_Crime_Analytics_Master
WHERE source_dataset = 'crim_hom_vrel'
GROUP BY [year], victim_relationship, sex
ORDER BY [year], Number_Of_Records DESC;


------------------------------------------------------------
-- 7. POPULATION ANALYSIS
-- Indicator: SP.POP.TOTL
------------------------------------------------------------

-- Population by country and year
SELECT
    geo_code,
    country_name,
    region,
    [year],
    SUM([value]) AS Population
FROM dbo.Global_Crime_Analytics_Master
WHERE indicator_code = 'SP.POP.TOTL'
GROUP BY geo_code, country_name, region, [year]
ORDER BY [year], Population DESC;

-- Population by region and year
SELECT
    region,
    [year],
    SUM([value]) AS Regional_Population,
    COUNT(DISTINCT geo_code) AS Reporting_Geographies
FROM dbo.Global_Crime_Analytics_Master
WHERE indicator_code = 'SP.POP.TOTL'
GROUP BY region, [year]
ORDER BY [year], Regional_Population DESC;


------------------------------------------------------------
-- 8. SOCIOECONOMIC ANALYSIS
------------------------------------------------------------

-- GDP per capita
SELECT
    country_name,
    [year],
    AVG([value]) AS GDP_Per_Capita
FROM dbo.Global_Crime_Analytics_Master
WHERE indicator_code = 'NY.GDP.PCAP.CD'
GROUP BY country_name, geo_code, [year]
ORDER BY [year], GDP_Per_Capita DESC;

-- Unemployment
SELECT
    country_name,
    [year],
    AVG([value]) AS Unemployment_Percentage
FROM dbo.Global_Crime_Analytics_Master
WHERE indicator_code = 'SL.UEM.TOTL.ZS'
GROUP BY country_name, geo_code, [year]
ORDER BY [year], Unemployment_Percentage DESC;

-- Youth unemployment
SELECT
    country_name,
    [year],
    AVG([value]) AS Youth_Unemployment_Percentage
FROM dbo.Global_Crime_Analytics_Master
WHERE indicator_code = 'SL.UEM.1524.ZS'
GROUP BY country_name, geo_code, [year]
ORDER BY [year], Youth_Unemployment_Percentage DESC;

-- Gini index
SELECT
    country_name,
    [year],
    AVG([value]) AS Gini_Index
FROM dbo.Global_Crime_Analytics_Master
WHERE indicator_code = 'SI.POV.GINI'
GROUP BY country_name, geo_code, [year]
ORDER BY [year], Gini_Index DESC;


------------------------------------------------------------
-- 9. COMBINED CRIME AND SOCIOECONOMIC DATA
-- One record per country and year per indicator.
------------------------------------------------------------

WITH Crime AS
(
    SELECT
        geo_code,
        country_name,
        [year],
        AVG([value]) AS Homicide_Rate
    FROM dbo.Global_Crime_Analytics_Master
    WHERE indicator_code = 'VC.IHR.PSRC.P5'
    GROUP BY geo_code, country_name, [year]
),
GDP AS
(
    SELECT geo_code, [year], AVG([value]) AS GDP_Per_Capita
    FROM dbo.Global_Crime_Analytics_Master
    WHERE indicator_code = 'NY.GDP.PCAP.CD'
    GROUP BY geo_code, [year]
),
Unemployment AS
(
    SELECT geo_code, [year], AVG([value]) AS Unemployment_Rate
    FROM dbo.Global_Crime_Analytics_Master
    WHERE indicator_code = 'SL.UEM.TOTL.ZS'
    GROUP BY geo_code, [year]
),
YouthUnemployment AS
(
    SELECT geo_code, [year], AVG([value]) AS Youth_Unemployment_Rate
    FROM dbo.Global_Crime_Analytics_Master
    WHERE indicator_code = 'SL.UEM.1524.ZS'
    GROUP BY geo_code, [year]
),
Gini AS
(
    SELECT geo_code, [year], AVG([value]) AS Gini_Index
    FROM dbo.Global_Crime_Analytics_Master
    WHERE indicator_code = 'SI.POV.GINI'
    GROUP BY geo_code, [year]
),
Population AS
(
    SELECT geo_code, [year], SUM([value]) AS Population
    FROM dbo.Global_Crime_Analytics_Master
    WHERE indicator_code = 'SP.POP.TOTL'
    GROUP BY geo_code, [year]
)
SELECT
    C.geo_code,
    C.country_name,
    C.[year],
    C.Homicide_Rate,
    P.Population,
    G.GDP_Per_Capita,
    U.Unemployment_Rate,
    Y.Youth_Unemployment_Rate,
    I.Gini_Index
FROM Crime C
LEFT JOIN Population P
    ON C.geo_code = P.geo_code AND C.[year] = P.[year]
LEFT JOIN GDP G
    ON C.geo_code = G.geo_code AND C.[year] = G.[year]
LEFT JOIN Unemployment U
    ON C.geo_code = U.geo_code AND C.[year] = U.[year]
LEFT JOIN YouthUnemployment Y
    ON C.geo_code = Y.geo_code AND C.[year] = Y.[year]
LEFT JOIN Gini I
    ON C.geo_code = I.geo_code AND C.[year] = I.[year]
ORDER BY C.[year], C.country_name;


------------------------------------------------------------
-- 10. POPULATION-WEIGHTED HOMICIDE RATE
-- For countries with both homicide and population data
-- in the same year.
------------------------------------------------------------

WITH CountryYear AS
(
    SELECT
        C.geo_code,
        C.country_name,
        C.[year],
        C.Homicide_Rate,
        P.Population
    FROM
    (
        SELECT
            geo_code,
            country_name,
            [year],
            AVG([value]) AS Homicide_Rate
        FROM dbo.Global_Crime_Analytics_Master
        WHERE indicator_code = 'VC.IHR.PSRC.P5'
        GROUP BY geo_code, country_name, [year]
    ) C
    INNER JOIN
    (
        SELECT
            geo_code,
            [year],
            SUM([value]) AS Population
        FROM dbo.Global_Crime_Analytics_Master
        WHERE indicator_code = 'SP.POP.TOTL'
        GROUP BY geo_code, [year]
    ) P
        ON C.geo_code = P.geo_code
       AND C.[year] = P.[year]
)
SELECT
    [year],
    SUM(Homicide_Rate * Population) /
        NULLIF(SUM(Population), 0) AS Population_Weighted_Rate,
    COUNT(DISTINCT geo_code) AS Countries_Included,
    SUM(Population) AS Population_Covered
FROM CountryYear
GROUP BY [year]
ORDER BY [year];


------------------------------------------------------------
-- 11. HOMICIDE RATE BANDS
------------------------------------------------------------

WITH CountryRates AS
(
    SELECT
        geo_code,
        country_name,
        [year],
        AVG([value]) AS Homicide_Rate
    FROM dbo.Global_Crime_Analytics_Master
    WHERE indicator_code = 'VC.IHR.PSRC.P5'
    GROUP BY geo_code, country_name, [year]
),
LatestRates AS
(
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY geo_code
            ORDER BY [year] DESC
        ) AS rn
    FROM CountryRates
)
SELECT
    CASE
        WHEN Homicide_Rate < 1 THEN 'Under 1'
        WHEN Homicide_Rate < 3 THEN '1 to 3'
        WHEN Homicide_Rate < 10 THEN '3 to 10'
        WHEN Homicide_Rate < 25 THEN '10 to 25'
        ELSE '25 and over'
    END AS Homicide_Rate_Band,
    COUNT(*) AS Number_Of_Countries
FROM LatestRates
WHERE rn = 1
GROUP BY
    CASE
        WHEN Homicide_Rate < 1 THEN 'Under 1'
        WHEN Homicide_Rate < 3 THEN '1 to 3'
        WHEN Homicide_Rate < 10 THEN '3 to 10'
        WHEN Homicide_Rate < 25 THEN '10 to 25'
        ELSE '25 and over'
    END
ORDER BY
    CASE
        WHEN
            CASE
                WHEN Homicide_Rate < 1 THEN 1
                WHEN Homicide_Rate < 3 THEN 2
                WHEN Homicide_Rate < 10 THEN 3
                WHEN Homicide_Rate < 25 THEN 4
                ELSE 5
            END = 1 THEN 1
        ELSE MIN(
            CASE
                WHEN Homicide_Rate < 1 THEN 1
                WHEN Homicide_Rate < 3 THEN 2
                WHEN Homicide_Rate < 10 THEN 3
                WHEN Homicide_Rate < 25 THEN 4
                ELSE 5
            END
        )
    END;


------------------------------------------------------------
-- 12. REPORTING COVERAGE BY YEAR
------------------------------------------------------------

WITH HomicideCoverage AS
(
    SELECT
        [year],
        COUNT(DISTINCT geo_code) AS Countries_With_Homicide
    FROM dbo.Global_Crime_Analytics_Master
    WHERE indicator_code = 'VC.IHR.PSRC.P5'
    GROUP BY [year]
),
PopulationCoverage AS
(
    SELECT
        [year],
        COUNT(DISTINCT geo_code) AS Countries_With_Population
    FROM dbo.Global_Crime_Analytics_Master
    WHERE indicator_code = 'SP.POP.TOTL'
    GROUP BY [year]
)
SELECT
    H.[year],
    H.Countries_With_Homicide,
    P.Countries_With_Population,
    CAST(
        100.0 * H.Countries_With_Homicide /
        NULLIF(P.Countries_With_Population, 0)
        AS DECIMAL(10,2)
    ) AS Coverage_Percentage
FROM HomicideCoverage H
LEFT JOIN PopulationCoverage P
    ON H.[year] = P.[year]
ORDER BY H.[year];


------------------------------------------------------------
-- 13. CORRELATION ANALYSIS
-- Pearson correlation across country-year pairs.
-- Correlation is descriptive, not causal.
------------------------------------------------------------

WITH Crime AS
(
    SELECT geo_code, [year], AVG([value]) AS Homicide_Rate
    FROM dbo.Global_Crime_Analytics_Master
    WHERE indicator_code = 'VC.IHR.PSRC.P5'
    GROUP BY geo_code, [year]
),
GDP AS
(
    SELECT geo_code, [year], AVG([value]) AS GDP_Per_Capita
    FROM dbo.Global_Crime_Analytics_Master
    WHERE indicator_code = 'NY.GDP.PCAP.CD'
    GROUP BY geo_code, [year]
),
Unemployment AS
(
    SELECT geo_code, [year], AVG([value]) AS Unemployment_Rate
    FROM dbo.Global_Crime_Analytics_Master
    WHERE indicator_code = 'SL.UEM.TOTL.ZS'
    GROUP BY geo_code, [year]
),
Gini AS
(
    SELECT geo_code, [year], AVG([value]) AS Gini_Index
    FROM dbo.Global_Crime_Analytics_Master
    WHERE indicator_code = 'SI.POV.GINI'
    GROUP BY geo_code, [year]
),
Pairs AS
(
    SELECT
        C.geo_code,
        C.[year],
        C.Homicide_Rate,
        G.GDP_Per_Capita,
        U.Unemployment_Rate,
        I.Gini_Index
    FROM Crime C
    LEFT JOIN GDP G
        ON C.geo_code = G.geo_code AND C.[year] = G.[year]
    LEFT JOIN Unemployment U
        ON C.geo_code = U.geo_code AND C.[year] = U.[year]
    LEFT JOIN Gini I
        ON C.geo_code = I.geo_code AND C.[year] = I.[year]
)
SELECT
    'Homicide vs GDP per Capita' AS Relationship,
    COUNT(*) AS Country_Year_Pairs,
    (
        COUNT(*) * SUM(Homicide_Rate * GDP_Per_Capita)
        - SUM(Homicide_Rate) * SUM(GDP_Per_Capita)
    )
    /
    NULLIF(
        SQRT(
            (
                COUNT(*) * SUM(Homicide_Rate * Homicide_Rate)
                - POWER(SUM(Homicide_Rate), 2)
            )
            *
            (
                COUNT(*) * SUM(GDP_Per_Capita * GDP_Per_Capita)
                - POWER(SUM(GDP_Per_Capita), 2)
            )
        ),
        0
    ) AS Pearson_Correlation
FROM Pairs
WHERE Homicide_Rate IS NOT NULL
  AND GDP_Per_Capita IS NOT NULL

UNION ALL

SELECT
    'Homicide vs Unemployment',
    COUNT(*),
    (
        COUNT(*) * SUM(Homicide_Rate * Unemployment_Rate)
        - SUM(Homicide_Rate) * SUM(Unemployment_Rate)
    )
    /
    NULLIF(
        SQRT(
            (
                COUNT(*) * SUM(Homicide_Rate * Homicide_Rate)
                - POWER(SUM(Homicide_Rate), 2)
            )
            *
            (
                COUNT(*) * SUM(Unemployment_Rate * Unemployment_Rate)
                - POWER(SUM(Unemployment_Rate), 2)
            )
        ),
        0
    )
FROM Pairs
WHERE Homicide_Rate IS NOT NULL
  AND Unemployment_Rate IS NOT NULL

UNION ALL

SELECT
    'Homicide vs Gini',
    COUNT(*),
    (
        COUNT(*) * SUM(Homicide_Rate * Gini_Index)
        - SUM(Homicide_Rate) * SUM(Gini_Index)
    )
    /
    NULLIF(
        SQRT(
            (
                COUNT(*) * SUM(Homicide_Rate * Homicide_Rate)
                - POWER(SUM(Homicide_Rate), 2)
            )
            *
            (
                COUNT(*) * SUM(Gini_Index * Gini_Index)
                - POWER(SUM(Gini_Index), 2)
            )
        ),
        0
    )
FROM Pairs
WHERE Homicide_Rate IS NOT NULL
  AND Gini_Index IS NOT NULL;


------------------------------------------------------------
-- 14. FINAL DATASET SUMMARY
------------------------------------------------------------

SELECT
    COUNT(*) AS Total_Records,
    COUNT(DISTINCT geo_code) AS Unique_Geographies,
    COUNT(DISTINCT country_name) AS Unique_Country_Names,
    COUNT(DISTINCT [year]) AS Available_Years,
    COUNT(DISTINCT indicator_code) AS Unique_Indicators,
    MIN([year]) AS First_Year,
    MAX([year]) AS Last_Year,
    SUM(CASE WHEN [value] IS NULL THEN 1 ELSE 0 END) AS Missing_Values
FROM dbo.Global_Crime_Analytics_Master;

PRINT 'GLOBAL CRIME ANALYSIS SCRIPT COMPLETED';
