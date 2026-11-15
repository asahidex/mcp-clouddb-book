CREATE TABLE products (id int PRIMARY KEY, name text NOT NULL, price int NOT NULL);
INSERT INTO products VALUES (1,'apple',120),(2,'banana',80),(3,'cherry',300),(4,'grape',250),(5,'lemon',100),(6,'melon',800),(7,'orange',150),(8,'peach',200);
CREATE USER mcp_readonly WITH LOGIN;
GRANT rds_iam TO mcp_readonly;
GRANT CONNECT ON DATABASE appdb TO mcp_readonly;
GRANT USAGE ON SCHEMA public TO mcp_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO mcp_readonly;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT ON TABLES TO mcp_readonly;
