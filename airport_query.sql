/*
--------------------------------------------------------------
2025 PRE-DEPARTURE DELAY ANALYSIS
--------------------------------------------------------------

This script aggregates data to analyze the delay pattern among
a set of airports in Europe. The database consists of four
tables:

- airports_geo
- countries_region
- all_pre_delays_2025 
- airports_info (runways)

--------------------------------------------------------------
*/

USE flights;

-- display the first 10 rows of the pre-departure delay table
SELECT TOP 10 *
FROM dbo.all_pre_delays_2025;
-- FLT_DEP_1 shows the number of flights departed per day
-- DLY_ALL_PRE_2 shows the total daily delay

-- display the first 10 rows of the airport-geodata table
SELECT TOP 10 *
FROM dbo.airports_geo;
-- GeoPointLat and GeoPointLong contain the geographical info

-- display the first 10 rows of the countries_regions table
SELECT TOP 10 *
FROM dbo.countries_regions;
-- contains geographical region for each country

----- Mean delay and number of flights per airport -----
WITH t AS(
	-- sum up the delay and number of flights over the entire year
	SELECT SUM(DLY_ALL_PRE_2) AS minutes_delay, SUM(FLT_DEP_1) AS number_flights, APT_ICAO AS airport, APT_NAME AS airport_name, STATE_NAME AS country
	FROM dbo.all_pre_delays_2025
	WHERE APT_ICAO IN (
	-- only select airports with daily flights and no missing delay values
		SELECT APT_ICAO AS airport_code
		FROM dbo.all_pre_delays_2025
		WHERE DLY_ALL_PRE_2 IS NOT NULL AND FLT_DEP_1 IS NOT NULL AND FLT_DEP_1 > 0
		GROUP BY APT_ICAO
		HAVING COUNT(*) = 365)
	GROUP BY APT_ICAO, APT_NAME, STATE_NAME)
-- Normalize the summed up delays by dividing by the number of flights
SELECT (minutes_delay / number_flights) AS mean_delay, number_flights, airport, t.airport_name, t.country, s.GeoPointLat, s.GeoPointLong, r.region
FROM t
-- join with dbo.airports_geo to get latitude and longitude values 
LEFT JOIN dbo.airports_geo AS s
ON t.airport = s.ICAO
-- join with dbo.countries_regions to add geographical regions
LEFT JOIN dbo.countries_regions AS r
ON t.country = r.country
ORDER BY mean_delay DESC;
/*
--------------------------------------------------------------
-- The airports with the longest pre-departure delay are in Luxembourg, Turin, Naples, Lisbon and Nice.
Western Europe has pretty high delays in general, whereas the Nordic countries consistently have
lower delays.
--------------------------------------------------------------
*/

----- Mean delay per day grouped by region -----
WITH t AS(
-- Average here as well since there are sometimes duplicate rows in the dataset
SELECT AVG(DLY_ALL_PRE_2 / FLT_DEP_1) AS minutes_delay, FLT_DATE AS flight_date, APT_ICAO AS airport_code, STATE_NAME AS country
FROM dbo.all_pre_delays_2025
WHERE APT_ICAO IN (
	SELECT APT_ICAO AS airport_code
	FROM dbo.all_pre_delays_2025
	WHERE DLY_ALL_PRE_2 IS NOT NULL AND FLT_DEP_1 IS NOT NULL AND FLT_DEP_1 > 0
	GROUP BY APT_ICAO
	HAVING COUNT(*) = 365)
GROUP BY APT_ICAO, STATE_NAME, FLT_DATE)
-- Average the delay across all airports of the same region per day
SELECT AVG(minutes_delay) AS mean_delay, flight_date, r.region
FROM t
-- join with countries_regions to get the region of each airport
LEFT JOIN dbo.countries_regions AS r
ON t.country = r.country
GROUP BY r.region, flight_date
ORDER BY r.region ASC, flight_date ASC;

----- Mean delay per day grouped by region -----
WITH t AS(
-- extract the weekday from the date
SELECT AVG(DLY_ALL_PRE_2 / FLT_DEP_1) AS minutes_delay, DATENAME(dw, FLT_DATE) AS flight_day, APT_ICAO AS airport_code, STATE_NAME AS country
FROM dbo.all_pre_delays_2025
WHERE APT_ICAO IN (
	SELECT APT_ICAO AS airport_code
	FROM dbo.all_pre_delays_2025
	WHERE DLY_ALL_PRE_2 IS NOT NULL AND FLT_DEP_1 IS NOT NULL AND FLT_DEP_1 > 0
	GROUP BY APT_ICAO
	HAVING COUNT(*) = 365)
GROUP BY APT_ICAO, STATE_NAME, DATENAME(dw, FLT_DATE))
SELECT AVG(minutes_delay) AS mean_delay, flight_day, r.region
FROM t
-- join countries_regions table again to get geographical area
LEFT JOIN dbo.countries_regions AS r
ON t.country = r.country
GROUP BY r.region, flight_day
-- this could be more elegant, but extracting ordered weekdays directly is nice for visulization
ORDER BY r.region ASC, CASE
	WHEN flight_day = 'Monday' THEN 1
	WHEN flight_day = 'Tuesday' THEN 2
	WHEN flight_day = 'Wednesday' THEN 3
	WHEN flight_day = 'Thursday' THEN 4
	WHEN flight_day = 'Friday' THEN 5
	WHEN flight_day = 'Saturday' THEN 6
	WHEN flight_day = 'Sunday' THEN 7
END ASC;
/*
--------------------------------------------------------------
-- Tuesday shows the lowest delay independent of region, whereas
Saturday is the day with the longest average delays.
--------------------------------------------------------------
*/

----- Average and standard deviation of runways for each region -----
SELECT AVG(CAST(t.runways AS FLOAT)) AS mean_runways, STDEV(CAST(t.runways AS FLOAT)) AS sd_runways, s.region
FROM dbo.airports_info AS t
LEFT JOIN dbo.all_pre_delays_2025 AS r
ON t.airport = r.APT_ICAO
LEFT JOIN dbo.countries_regions AS s
ON r.STATE_NAME = s.country
GROUP BY s.region
ORDER BY mean_runways DESC;
/*
--------------------------------------------------------------
-- Airports in Western Europe have the highest average number
of runways at 2.3 followed by Nordic countries at 2. Last are
the British aisles at 1.33.
--------------------------------------------------------------
*/

----- Cross-variation in delay per airport -----
SELECT (STDEV(DLY_ALL_PRE_2) / AVG(DLY_ALL_PRE_2)) AS delay_cv, APT_NAME AS airport_name
FROM dbo.all_pre_delays_2025
WHERE APT_ICAO IN (
	SELECT APT_ICAO AS airport_code
	FROM dbo.all_pre_delays_2025
	WHERE DLY_ALL_PRE_2 IS NOT NULL AND FLT_DEP_1 IS NOT NULL AND FLT_DEP_1 > 0
	GROUP BY APT_ICAO
	HAVING COUNT(*) = 365)
GROUP BY APT_NAME
ORDER BY delay_cv DESC;
/*
--------------------------------------------------------------
-- Cross-variation can give an overview about the volatility in
delays. Torino shows the highest cross-variation, and it is one
of the airports with the highest delays. However, Stavanger and
Bergen also show high cross-variation and they have quite low
delays. Needs to be analyzed in more detail.
--------------------------------------------------------------
*/





