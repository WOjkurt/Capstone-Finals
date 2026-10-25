-- Read-only query to find duplicate lower(Email) values in the Users table.
SELECT 
    LOWER("Email") AS normalized_email,
    COUNT(*) AS count,
    ARRAY_AGG("UserID") AS user_ids
FROM "Users"
GROUP BY LOWER("Email")
HAVING COUNT(*) > 1;
