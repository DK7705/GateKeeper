-- =============================================================================
-- Database Initialization Script
-- Creates databases for User Service and Order Service
-- =============================================================================

-- Create databases
CREATE DATABASE userdb;
CREATE DATABASE orderdb;

-- Grant permissions
GRANT ALL PRIVILEGES ON DATABASE userdb TO appuser;
GRANT ALL PRIVILEGES ON DATABASE orderdb TO appuser;
