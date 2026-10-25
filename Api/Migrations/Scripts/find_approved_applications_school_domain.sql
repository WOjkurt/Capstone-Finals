-- Read-only query to list approved applications whose EnrollmentResponse email already ends with @dbtc-cebu.edu.ph.
SELECT 
    ea."ApplicationID",
    ea."Status",
    ea."StudentUserID",
    ea."SchoolEmail",
    er."ResponseID",
    er."EmailAddress" AS "PersonalEmail",
    ea."CreatedAt"
FROM "EnrollmentApplications" ea
JOIN "EnrollmentResponses" er ON ea."ResponseID" = er."ResponseID"
WHERE ea."Status" = 2 -- Approved (EnrollmentApplicationStatus.Approved)
  AND LOWER(er."EmailAddress") LIKE '%@dbtc-cebu.edu.ph';
