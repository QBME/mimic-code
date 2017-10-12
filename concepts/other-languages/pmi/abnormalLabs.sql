-- really needs to account for patient age (at time of test and gender

DROP TABLE IF exists D_LABMEAN;

-- generate a table with the mean and std of the results of a test
-- on a gender specific and age range specific way
CREATE TABLE D_LABMEAN as
(
SELECT
e.ITEMID,
AVG(VALUENUM) as meanValue,
STD(VALUENUM) as stdValue,
FLOOR(DATEDIFF(e.CHARTTIME,p.DOB)/365.25/5)*5 as ageCat,
p.GENDER,
e.VALUEUOM
FROM MIMIC.LABEVENTS e,
PATIENTS p
WHERE e.VALUEUOM IS NOT null
AND FLOOR(DATEDIFF(e.CHARTTIME,p.DOB)/365.25/5)*5 < 120
AND p.SUBJECT_ID = e.SUBJECT_ID
GROUP BY e.ITEMID, e.VALUEUOM, FLOOR(DATEDIFF(e.CHARTTIME,p.DOB)/365.25/5)*5, p.GENDER
);

ALTER TABLE D_LABMEAN add index (ITEMID,VALUEUOM,ageCat,GENDER);

ALTER TABLE LABEVENTS 
ADD COLUMN INDICATOR char DEFAULT NULL,
ADD COLUMN DEGREE float DEFAULT NULL;

UPDATE LABEVENTS e, D_LABMEAN l, PATIENTS p
SET e.INDICATOR=IF(e.VALUENUM<l.meanValue, "L","H")
WHERE e.ITEMID = l.ITEMID
AND e.VALUEUOM = l.VALUEUOM
AND e.FLAG = "abnormal"
AND p.SUBJECT_ID = e.SUBJECT_ID
AND p.GENDER = l.GENDER
AND FLOOR(DATEDIFF(e.CHARTTIME,p.DOB)/365.25/5)*5 = l.ageCat;

UPDATE LABEVENTS e, D_LABMEAN l, PATIENTS p
SET e.DEGREE=(e.VALUENUM - l.meanValue)/l.stdValue
WHERE e.ITEMID = l.ITEMID
AND e.VALUEUOM = l.VALUEUOM
AND p.SUBJECT_ID = e.SUBJECT_ID
AND p.GENDER = l.GENDER
AND l.stdValue>0
AND FLOOR(DATEDIFF(e.CHARTTIME,p.DOB)/365.25/5)*5 = l.ageCat;

-- SELECT 
-- e.*,
-- IF( e.VALUENUM < l.meanValue , "low","high") as indicator,
-- (e.VALUENUM - l.meanValue)/l.stdValue as stdevsFromMean
-- FROM MIMIC.LABEVENTS e, D_LABMEAN l, PATIENTS p
-- WHERE e.ITEMID = l.ITEMID
-- AND e.VALUEUOM = l.VALUEUOM
-- AND e.FLAG = "abnormal"
-- AND p.SUBJECT_ID = e.SUBJECT_ID
-- AND p.GENDER = l.GENDER
-- AND FLOOR(DATEDIFF(e.CHARTTIME,p.DOB)/365.25/5)*5 = l.ageCat
-- ;


-- The idea here was to find the smallest abnormal result above the mean of the results 
-- grouped by gender and age band to determine the highest limit of normal
-- This doesn't really work as there is not enough data and patients are all abnormal.
SELECT 
MAX(e.VALUENUM) as lowerLimitNormal,
COUNT(*) as sampleSize,
e.ITEMID,
e.VALUEUOM, 
l.ageCat, 
l.GENDER
FROM MIMIC.LABEVENTS e, D_LABMEAN l, PATIENTS p
WHERE e.ITEMID = l.ITEMID
AND e.VALUEUOM = l.VALUEUOM
AND e.VALUENUM < l.meanValue
AND e.FLAG = "abnormal"
AND p.SUBJECT_ID = e.SUBJECT_ID
AND p.GENDER = l.GENDER
AND FLOOR(DATEDIFF(e.CHARTTIME,p.DOB)/365.25/5)*5 = l.ageCat
GROUP BY e.ITEMID, e.VALUEUOM, l.ageCat, l.GENDER;

SELECT 
MIN(e.VALUENUM) as upperLimitNormal,
COUNT(*) as sampleSize,
e.ITEMID,
e.VALUEUOM, 
l.ageCat, 
l.GENDER
FROM MIMIC.LABEVENTS e, D_LABMEAN l, PATIENTS p
WHERE e.ITEMID = l.ITEMID
AND e.VALUEUOM = l.VALUEUOM
AND e.VALUENUM > l.meanValue
AND e.FLAG = "abnormal"
AND p.SUBJECT_ID = e.SUBJECT_ID
AND p.GENDER = l.GENDER
AND FLOOR(DATEDIFF(e.CHARTTIME,p.DOB)/365.25/5)*5 = l.ageCat
GROUP BY e.ITEMID, e.VALUEUOM, l.ageCat, l.GENDER;

