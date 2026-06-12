USE obd_driver_db;

-- Q1: Aggressive driving % per vehicle
SELECT 
    vehicle_id,
    COUNT(*) as total_readings,
    SUM(CASE WHEN driving_style = 'AGGRESSIVE' THEN 1 ELSE 0 END) as aggressive_count,
    ROUND(SUM(CASE WHEN driving_style = 'AGGRESSIVE' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as aggressive_pct
FROM obd_readings
GROUP BY vehicle_id
ORDER BY aggressive_pct DESC;

-- Q2: Average speed and RPM per driving style
SELECT 
    driving_style,
    ROUND(AVG(speed), 2) as avg_speed,
    ROUND(AVG(engine_rpm), 2) as avg_rpm,
    ROUND(AVG(throttle_pos), 2) as avg_throttle
FROM obd_readings
GROUP BY driving_style
ORDER BY avg_speed DESC;

-- Q3: Peak hour aggressive driving
SELECT 
    trip_hour,
    COUNT(*) as total_readings,
    SUM(CASE WHEN driving_style = 'AGGRESSIVE' THEN 1 ELSE 0 END) as aggressive_events,
    ROUND(SUM(CASE WHEN driving_style = 'AGGRESSIVE' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as aggressive_pct
FROM obd_readings
GROUP BY trip_hour
ORDER BY aggressive_events DESC;

-- Q4: Fault vehicles ranking
SELECT 
    vehicle_id,
    SUM(fault_count) as total_faults,
    SUM(has_fault) as fault_events,
    RANK() OVER (ORDER BY SUM(fault_count) DESC) as fault_rank
FROM obd_readings
GROUP BY vehicle_id
ORDER BY total_faults DESC;

-- Q5: Engine temperature vs driving style
SELECT 
    driving_style,
    ROUND(AVG(engine_coolant_temp), 2) as avg_coolant_temp,
    ROUND(MAX(engine_coolant_temp), 2) as max_coolant_temp
FROM obd_readings
GROUP BY driving_style
ORDER BY avg_coolant_temp DESC;

-- Q6: Rolling avg speed per vehicle (window function)
SELECT 
    vehicle_id,
    timestamp,
    speed,
    ROUND(AVG(speed) OVER (
        PARTITION BY vehicle_id 
        ORDER BY timestamp 
        ROWS BETWEEN 9 PRECEDING AND CURRENT ROW
    ), 2) as rolling_avg_speed
FROM obd_readings
LIMIT 100;

-- Q7: Top 5 most dangerous vehicles
SELECT 
    v.vehicle_id,
    v.mark,
    v.model,
    v.car_year,
    ROUND(SUM(CASE WHEN r.driving_style = 'AGGRESSIVE' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as aggressive_pct,
    SUM(r.fault_count) as total_faults
FROM obd_readings r
JOIN vehicles v ON r.vehicle_id = v.vehicle_id
GROUP BY v.vehicle_id, v.mark, v.model, v.car_year
ORDER BY aggressive_pct DESC
LIMIT 5;

-- Q8: Driver safety score (lower = safer)
SELECT 
    vehicle_id,
    ROUND(
        (SUM(CASE WHEN driving_style = 'AGGRESSIVE' THEN 1 ELSE 0 END) * 100.0 / COUNT(*)) * 0.6 +
        (AVG(speed) / 120 * 100) * 0.4
    , 2) as safety_risk_score,
    CASE 
        WHEN (SUM(CASE WHEN driving_style = 'AGGRESSIVE' THEN 1 ELSE 0 END) * 100.0 / COUNT(*)) < 5 THEN 'SAFE'
        WHEN (SUM(CASE WHEN driving_style = 'AGGRESSIVE' THEN 1 ELSE 0 END) * 100.0 / COUNT(*)) < 20 THEN 'MODERATE'
        ELSE 'RISKY'
    END as safety_label
FROM obd_readings
GROUP BY vehicle_id
ORDER BY safety_risk_score DESC;

USE obd_driver_db;

-- View: driver safety summary
CREATE VIEW driver_safety_summary AS
SELECT 
    v.vehicle_id,
    v.mark,
    v.model,
    v.car_year,
    COUNT(*) as total_readings,
    ROUND(AVG(r.speed), 2) as avg_speed,
    ROUND(AVG(r.engine_rpm), 2) as avg_rpm,
    SUM(r.fault_count) as total_faults,
    ROUND(SUM(CASE WHEN r.driving_style = 'AGGRESSIVE' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as aggressive_pct,
    CASE 
        WHEN SUM(CASE WHEN r.driving_style = 'AGGRESSIVE' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) < 5 THEN 'SAFE'
        WHEN SUM(CASE WHEN r.driving_style = 'AGGRESSIVE' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) < 20 THEN 'MODERATE'
        ELSE 'RISKY'
    END as safety_label
FROM obd_readings r
JOIN vehicles v ON r.vehicle_id = v.vehicle_id
GROUP BY v.vehicle_id, v.mark, v.model, v.car_year;

-- Stored Procedure: GetDriverScore
DELIMITER //
CREATE PROCEDURE GetDriverScore(IN p_vehicle_id VARCHAR(10))
BEGIN
    SELECT 
        vehicle_id,
        mark,
        model,
        avg_speed,
        avg_rpm,
        total_faults,
        aggressive_pct,
        safety_label
    FROM driver_safety_summary
    WHERE vehicle_id = p_vehicle_id;
END //
DELIMITER ;

-- Test the view
SELECT * FROM driver_safety_summary ORDER BY aggressive_pct DESC;

-- Test the stored procedure
CALL GetDriverScore('car11');