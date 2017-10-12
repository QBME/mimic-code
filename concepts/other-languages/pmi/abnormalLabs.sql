-- really needs to account for patient age (at time of test and gender

DROP TABLE IF exists D_LABMEAN;

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

SELECT 
e.*,
IF( e.VALUENUM < l.meanValue , "low","high") as indicator,
(e.VALUENUM - l.meanValue)/l.stdValue as stdevsFromMean
FROM MIMIC.LABEVENTS e, D_LABMEAN l, PATIENTS p
WHERE e.ITEMID = l.ITEMID
AND e.VALUEUOM = l.VALUEUOM
AND e.FLAG = "abnormal"
AND p.SUBJECT_ID = e.SUBJECT_ID
AND p.GENDER = l.GENDER
AND FLOOR(DATEDIFF(e.CHARTTIME,p.DOB)/365.25/5)*5 = l.ageCat
;

DROP TABLE IF exists D_LABREFRANGE;

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

