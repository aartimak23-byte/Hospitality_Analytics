Create database hospitality;
Use hospitality;

-- Total Revenue
select sum(revenue_realized) as total_revenue from fact_bookings;

-- Total Bookings
Select count(booking_id) as total_bookings from fact_bookings;

-- Total Capacity
select sum(capacity) as total_capacity from fact_aggregated_bookings;

-- Total Sucessful Booking
select count(Booking_id) as successful_Bookings from fact_bookings;

-- Occupancy
select (sum(successful_bookings)*100/sum(capacity)) as occpancy_percent from fact_aggregated_bookings;

-- average rating
select avg(ratings_given) as avg_rating from fact_bookings where ratings_given is not null;

---- no of days
select count(distinct date) as no_of_days from dim_date;

-- Cancellation rate
SELECT 
(COUNT(CASE WHEN booking_status = 'Cancelled' THEN 1 END) * 100.0) / COUNT(*) AS cancellation_percent
FROM fact_bookings;

-- Total Checked out and total no show Bookings
SELECT 'No Show' AS status, COUNT(*) AS total_bookings
FROM fact_bookings
WHERE booking_status = 'No Show'
UNION ALL
SELECT 'CheckedOut' AS status, COUNT(*) AS total_bookings
FROM fact_bookings
WHERE booking_status = 'CheckedOut';

-- Booking % by platform --- by window function
SELECT booking_platform,
COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS booking_percent
FROM fact_bookings
GROUP BY booking_platform;

-- Realisation %
SELECT (SUM(revenue_realized) * 100.0 / SUM(total_bookings)) AS realisation_percent
FROM fact_bookings;

-- Revenue per available rooms
SELECT d.date,
COUNT(fb.booking_id) AS total_bookings,
SUM(fab.capacity) AS total_capacity
FROM dim_date d
LEFT JOIN fact_bookings fb 
ON d.date = fb.booking_date
LEFT JOIN fact_aggregated_bookings fab
ON d.date = fab.check_in_date
GROUP BY d.date
ORDER BY d.date;

-- Daily sellable room nights
SELECT check_in_date,
SUM(capacity) AS DSRN
FROM fact_aggregated_bookings
GROUP BY check_in_date
ORDER BY check_in_date;

-- Daily Booked Room nights
SELECT CAST(COUNT(*) AS DECIMAL) / NULLIF(COUNT(DISTINCT booking_date), 0) AS dbrn
FROM fact_bookings;

-- RevPar (Revenue Available per room)
WITH daily_revenue AS (SELECT check_in_date AS date, SUM(revenue_realized) AS total_revenue
FROM fact_bookings
WHERE UPPER(booking_status) = 'CHECKEDOUT'
GROUP BY check_in_date),
daily_rooms AS (SELECT check_in_date as date, SUM(capacity) AS total_rooms
FROM fact_aggregated_bookings
GROUP BY check_in_date)
SELECT CAST(SUM(dr.total_revenue) AS DECIMAL) / NULLIF(SUM(drs.total_rooms), 0) AS revpar
FROM daily_revenue dr
JOIN daily_rooms drs 
ON dr.date = drs.date;

-- Week Over Week Change
WITH weekly_revenue AS (SELECT WEEK(dd.date) AS week_number,SUM(fb.revenue_realized) AS current_week_revenue
FROM fact_bookings fb
JOIN dim_date dd 
ON fb.booking_date = dd.date
WHERE UPPER(fb.booking_status) = 'CHECKEDOUT'
GROUP BY WEEK(dd.date))
SELECT week_number,current_week_revenue,
LAG(current_week_revenue) OVER (ORDER BY week_number) AS last_week_revenue,
ROUND(((current_week_revenue - LAG(current_week_revenue) OVER (ORDER BY week_number)) 
/ NULLIF(LAG(current_week_revenue) OVER (ORDER BY week_number), 0)) * 100, 2) AS revenue_wow_change
FROM weekly_revenue
ORDER BY week_number;

-- stored Procedure

DELIMITER $$
USE `hospitality`$$
CREATE PROCEDURE `calculate_daily_metrics` ()
BEGIN
INSERT INTO daily_metrics (total_revenue, occupancy_percentage)
SELECT
SUM(fb.revenue_realized) AS total_revenue,
(CAST(COUNT(CASE WHEN fb.booking_status = 'CheckedOut' THEN 1 END) AS DECIMAL(10,2))
/ NULLIF(SUM(fab.capacity),0)) * 100 AS occupancy_percentage
FROM fact_bookings fb
JOIN fact_aggregated_bookings fab
ON fb.check_in_date = fab.check_in_date;
END$$

DELIMITER ;
call calculate_daily_metrics();







