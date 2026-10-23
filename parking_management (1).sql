-- ============================================================
-- PARKING MANAGEMENT SYSTEM
-- Database: parking_management
-- DBMS: MySQL
-- ============================================================

DROP DATABASE IF EXISTS parking_management;
CREATE DATABASE parking_management;
USE parking_management;

-- ============================================================
-- 1. TABLE CREATION
-- ============================================================

CREATE TABLE USER (
    User_ID INT AUTO_INCREMENT PRIMARY KEY,
    Name VARCHAR(100) NOT NULL,
    Phone VARCHAR(15) NOT NULL,
    Email VARCHAR(100) NOT NULL UNIQUE,
    User_Type VARCHAR(20) NOT NULL
);

CREATE TABLE VEHICLE (
    Vehicle_ID INT AUTO_INCREMENT PRIMARY KEY,
    Vehicle_No VARCHAR(20) NOT NULL,
    Vehicle_Type VARCHAR(30) NOT NULL,
    User_ID INT NOT NULL,
    FOREIGN KEY (User_ID) REFERENCES USER(User_ID)
);

CREATE TABLE PARKING_AREA (
    Area_ID INT AUTO_INCREMENT PRIMARY KEY,
    Area_Name VARCHAR(100) NOT NULL,
    Location VARCHAR(100) NOT NULL,
    Total_Slots INT NOT NULL
);

CREATE TABLE PARKING_SLOT (
    Slot_ID INT AUTO_INCREMENT PRIMARY KEY,
    Slot_Number VARCHAR(20) NOT NULL,
    Slot_Type VARCHAR(30) NOT NULL,
    Status VARCHAR(20) NOT NULL,
    Area_ID INT NOT NULL,
    FOREIGN KEY (Area_ID) REFERENCES PARKING_AREA(Area_ID)
);

CREATE TABLE PARKING_RECORD (
    Record_ID INT AUTO_INCREMENT PRIMARY KEY,
    Vehicle_ID INT NOT NULL,
    Slot_ID INT NOT NULL,
    Entry_Time DATETIME NOT NULL,
    Exit_Time DATETIME NULL,
    Duration INT NULL,
    Amount DECIMAL(10,2) NULL,
    FOREIGN KEY (Vehicle_ID) REFERENCES VEHICLE(Vehicle_ID),
    FOREIGN KEY (Slot_ID) REFERENCES PARKING_SLOT(Slot_ID)
);

CREATE TABLE PAYMENT (
    Payment_ID INT AUTO_INCREMENT PRIMARY KEY,
    Record_ID INT NOT NULL UNIQUE,
    Amount DECIMAL(10,2) NOT NULL,
    Payment_Date DATETIME NOT NULL,
    Payment_Mode VARCHAR(30) NOT NULL,
    FOREIGN KEY (Record_ID) REFERENCES PARKING_RECORD(Record_ID)
);

-- ============================================================
-- 2. SAMPLE DATA
-- ============================================================

INSERT INTO USER (Name, Phone, Email, User_Type) VALUES
('Amey Sawant', '9876543210', 'amey@example.com', 'Normal'),
('Rahul Sharma', '9876543211', 'rahul@example.com', 'Normal'),
('Priya Patil', '9876543212', 'priya@example.com', 'Normal'),
('Admin User', '9876543213', 'admin@example.com', 'Admin');

INSERT INTO VEHICLE (Vehicle_No, Vehicle_Type, User_ID) VALUES
('MH12AB1234', 'Car', 1),
('MH14CD5678', 'Bike', 1),
('MH12EF9012', 'Car', 2),
('MH14GH3456', 'Bike', 3),
('MH12IJ7890', 'Car', 4);

INSERT INTO PARKING_AREA (Area_Name, Location, Total_Slots) VALUES
('Main Gate Parking', 'Main Gate', 20),
('Academic Block Parking', 'Academic Block', 15),
('Hostel Parking', 'Hostel Block', 25);

INSERT INTO PARKING_SLOT (Slot_Number, Slot_Type, Status, Area_ID) VALUES
('A01', 'Car', 'Available', 1),
('A02', 'Car', 'Available', 1),
('A03', 'Bike', 'Available', 1),
('A04', 'Bike', 'Available', 1),
('B01', 'Car', 'Available', 2),
('B02', 'Bike', 'Available', 2),
('B03', 'Car', 'Available', 2),
('C01', 'Car', 'Available', 3),
('C02', 'Bike', 'Available', 3),
('C03', 'Bike', 'Available', 3);

INSERT INTO PARKING_RECORD
(Vehicle_ID, Slot_ID, Entry_Time, Exit_Time, Duration, Amount)
VALUES
(1, 1, '2026-10-10 09:00:00', '2026-10-10 12:00:00', 180, 60.00),
(2, 3, '2026-10-10 10:00:00', '2026-10-10 13:30:00', 210, 40.00),
(3, 5, '2026-10-11 08:30:00', '2026-10-15 12:30:00', 6000, 2000.00),
(4, 6, '2026-10-11 09:15:00', NULL, NULL, NULL);

UPDATE PARKING_SLOT
SET Status = 'Occupied'
WHERE Slot_ID IN (5, 6);

INSERT INTO PAYMENT
(Record_ID, Amount, Payment_Date, Payment_Mode)
VALUES
(1, 60.00, '2026-10-10 12:05:00', 'UPI'),
(2, 40.00, '2026-10-10 13:35:00', 'Cash'),
(3, 2000.00, '2026-10-15 12:35:00', 'UPI');

-- ============================================================
-- 3. STORED FUNCTION
-- Calculates parking amount at Rs.20 per started hour.
-- Minimum charge for up to 60 minutes is Rs.20.
-- ============================================================

DELIMITER //

CREATE FUNCTION CalculateParkingAmount(minutes INT)
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
    DECLARE hours INT;

    IF minutes <= 60 THEN
        RETURN 20.00;
    ELSE
        SET hours = CEIL(minutes / 60);
        RETURN hours * 20.00;
    END IF;
END //

DELIMITER ;

-- ============================================================
-- 4. TRIGGERS
-- ============================================================

DELIMITER //

CREATE TRIGGER before_parking_record_insert
BEFORE INSERT ON PARKING_RECORD
FOR EACH ROW
BEGIN
    DECLARE v_status VARCHAR(20);

    SELECT Status
    INTO v_status
    FROM PARKING_SLOT
    WHERE Slot_ID = NEW.Slot_ID;

    IF v_status = 'Occupied' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Parking slot is already occupied.';
    END IF;
END //

CREATE TRIGGER after_parking_record_insert
AFTER INSERT ON PARKING_RECORD
FOR EACH ROW
UPDATE PARKING_SLOT
SET Status = 'Occupied'
WHERE Slot_ID = NEW.Slot_ID //

DELIMITER ;

-- ============================================================
-- 5. STORED PROCEDURE
-- Completes parking, calculates duration and amount,
-- and makes the slot available again.
-- ============================================================

DELIMITER //

CREATE PROCEDURE CompleteParking(
    IN p_Record_ID INT,
    IN p_Exit_Time DATETIME
)
BEGIN
    DECLARE v_Duration INT;
    DECLARE v_Amount DECIMAL(10,2);
    DECLARE v_Slot_ID INT;

    SELECT Slot_ID
    INTO v_Slot_ID
    FROM PARKING_RECORD
    WHERE Record_ID = p_Record_ID;

    SET v_Duration = TIMESTAMPDIFF(
        MINUTE,
        (SELECT Entry_Time FROM PARKING_RECORD WHERE Record_ID = p_Record_ID),
        p_Exit_Time
    );

    SET v_Amount = CalculateParkingAmount(v_Duration);

    UPDATE PARKING_RECORD
    SET Exit_Time = p_Exit_Time,
        Duration = v_Duration,
        Amount = v_Amount
    WHERE Record_ID = p_Record_ID;

    UPDATE PARKING_SLOT
    SET Status = 'Available'
    WHERE Slot_ID = v_Slot_ID;
END //

DELIMITER ;

-- ============================================================
-- 6. DML / CRUD EXAMPLES
-- ============================================================

-- CREATE / INSERT
-- INSERT INTO VEHICLE (Vehicle_No, Vehicle_Type, User_ID)
-- VALUES ('MH12XX9999', 'Car', 1);

-- READ / SELECT
SELECT * FROM USER;
SELECT * FROM VEHICLE;
SELECT * FROM PARKING_AREA;
SELECT * FROM PARKING_SLOT;
SELECT * FROM PARKING_RECORD;
SELECT * FROM PAYMENT;

-- Useful joined report
SELECT
    PR.Record_ID,
    U.Name,
    V.Vehicle_No,
    PS.Slot_Number,
    PR.Entry_Time,
    PR.Exit_Time,
    PR.Duration,
    PR.Amount
FROM PARKING_RECORD PR
JOIN VEHICLE V ON PR.Vehicle_ID = V.Vehicle_ID
JOIN USER U ON V.User_ID = U.User_ID
JOIN PARKING_SLOT PS ON PR.Slot_ID = PS.Slot_ID;

-- UPDATE example
-- UPDATE PARKING_SLOT
-- SET Status = 'Available'
-- WHERE Slot_ID = 1;

-- DELETE example
-- DELETE FROM PAYMENT
-- WHERE Payment_ID = 1;

-- ============================================================
-- 7. FUNCTION / PROCEDURE TESTS
-- ============================================================

SELECT CalculateParkingAmount(30) AS Amount_For_30_Minutes;
SELECT CalculateParkingAmount(180) AS Amount_For_180_Minutes;

-- Procedure example:
-- CALL CompleteParking(4, '2026-10-21 12:00:00');

-- ============================================================
-- 8. DCL
-- ============================================================

DROP USER IF EXISTS 'parking_admin'@'localhost';
DROP USER IF EXISTS 'parking_user'@'localhost';

CREATE USER 'parking_admin'@'localhost' IDENTIFIED BY 'Admin@123';

GRANT ALL PRIVILEGES
ON parking_management.*
TO 'parking_admin'@'localhost';

CREATE USER 'parking_user'@'localhost' IDENTIFIED BY 'User@123';

GRANT SELECT, INSERT, UPDATE
ON parking_management.*
TO 'parking_user'@'localhost';

FLUSH PRIVILEGES;

-- Verify privileges
SHOW GRANTS FOR 'parking_admin'@'localhost';
SHOW GRANTS FOR 'parking_user'@'localhost';

-- ============================================================
-- 9. VERIFICATION QUERIES
-- ============================================================

SELECT
    (SELECT COUNT(*) FROM USER) AS Users,
    (SELECT COUNT(*) FROM VEHICLE) AS Vehicles,
    (SELECT COUNT(*) FROM PARKING_AREA) AS Areas,
    (SELECT COUNT(*) FROM PARKING_SLOT) AS Slots,
    (SELECT COUNT(*) FROM PARKING_RECORD) AS Records,
    (SELECT COUNT(*) FROM PAYMENT) AS Payments;

SHOW TRIGGERS;

SHOW FUNCTION STATUS
WHERE Db = 'parking_management';

SHOW PROCEDURE STATUS
WHERE Db = 'parking_management';

-- ============================================================
-- END OF PARKING MANAGEMENT SYSTEM DATABASE
-- ============================================================
