<!-- /*
  # InsightHub IIoT Monitoring System Schema

  1. New Tables
    - `plants`: Manufacturing facilities
      - `id` (uuid, primary key)
      - `name` (text)
      - `location` (text)
      - `created_at` (timestamp)
      - `updated_at` (timestamp)
    
    - `assets`: Industrial equipment/machines
      - `id` (uuid, primary key)
      - `plant_id` (uuid, foreign key)
      - `name` (text)
      - `model` (text)
      - `serial_number` (text)
      - `status` (text)
      - `installation_date` (date)
      - `created_at` (timestamp)
      - `updated_at` (timestamp)
    
    - `sensor_readings`: Real-time sensor data
      - `id` (uuid, primary key)
      - `asset_id` (uuid, foreign key)
      - `timestamp` (timestamp)
      - `temperature` (decimal)
      - `pressure` (decimal)
      - `vibration` (decimal)
      - `energy_consumption` (decimal)
    
    - `alerts`: System alerts and notifications
      - `id` (uuid, primary key)
      - `asset_id` (uuid, foreign key)
      - `type` (text)
      - `severity` (text)
      - `message` (text)
      - `status` (text)
      - `created_at` (timestamp)
      - `resolved_at` (timestamp)
      - `resolved_by` (uuid, foreign key)
    
    - `maintenance_logs`: Equipment maintenance records
      - `id` (uuid, primary key)
      - `asset_id` (uuid, foreign key)
      - `performed_by` (uuid, foreign key)
      - `type` (text)
      - `description` (text)
      - `performed_at` (timestamp)
      - `next_maintenance_date` (date)
      - `created_at` (timestamp)
    
    - `user_roles`: Custom roles for users
      - `id` (uuid, primary key)
      - `user_id` (uuid, foreign key)
      - `role` (text)
      - `created_at` (timestamp)

  2. Security
    - Enable RLS on all tables
    - Create policies for admin, engineer, and operator roles
    - Admins have full access to all tables
    - Engineers can read all data and manage maintenance
    - Operators can only read data and create alerts
*/ -->

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create enum types
CREATE TYPE alert_severity AS ENUM ('low', 'medium', 'high', 'critical');
CREATE TYPE alert_status AS ENUM ('active', 'acknowledged', 'resolved');
CREATE TYPE asset_status AS ENUM ('operational', 'maintenance', 'fault', 'offline');
CREATE TYPE user_role AS ENUM ('admin', 'engineer', 'operator');

-- Plants table
CREATE TABLE plants (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    name text NOT NULL,
    location text NOT NULL,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Assets table
CREATE TABLE assets (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    plant_id uuid REFERENCES plants(id) ON DELETE CASCADE,
    name text NOT NULL,
    model text NOT NULL,
    serial_number text UNIQUE NOT NULL,
    status asset_status DEFAULT 'operational',
    installation_date date NOT NULL,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Sensor readings table
CREATE TABLE sensor_readings (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    asset_id uuid REFERENCES assets(id) ON DELETE CASCADE,
    timestamp timestamptz DEFAULT now(),
    temperature decimal,
    pressure decimal,
    vibration decimal,
    energy_consumption decimal,
    
    -- Add constraints for valid ranges
    CONSTRAINT valid_temperature CHECK (temperature >= -50 AND temperature <= 150),
    CONSTRAINT valid_pressure CHECK (pressure >= 0),
    CONSTRAINT valid_vibration CHECK (vibration >= 0),
    CONSTRAINT valid_energy CHECK (energy_consumption >= 0)
);

-- Alerts table
CREATE TABLE alerts (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    asset_id uuid REFERENCES assets(id) ON DELETE CASCADE,
    type text NOT NULL,
    severity alert_severity NOT NULL,
    message text NOT NULL,
    status alert_status DEFAULT 'active',
    created_at timestamptz DEFAULT now(),
    resolved_at timestamptz,
    resolved_by uuid REFERENCES auth.users(id)
);

-- Maintenance logs table
CREATE TABLE maintenance_logs (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    asset_id uuid REFERENCES assets(id) ON DELETE CASCADE,
    performed_by uuid REFERENCES auth.users(id),
    type text NOT NULL,
    description text NOT NULL,
    performed_at timestamptz NOT NULL,
    next_maintenance_date date,
    created_at timestamptz DEFAULT now()
);

-- User roles table
CREATE TABLE user_roles (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
    role user_role NOT NULL,
    created_at timestamptz DEFAULT now(),
    UNIQUE(user_id)
);

-- Enable Row Level Security
ALTER TABLE plants ENABLE ROW LEVEL SECURITY;
ALTER TABLE assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE sensor_readings ENABLE ROW LEVEL SECURITY;
ALTER TABLE alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE maintenance_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;

-- Create helper function to get user role
CREATE OR REPLACE FUNCTION get_user_role()
RETURNS user_role AS $$
BEGIN
    RETURN (
        SELECT role
        FROM user_roles
        WHERE user_id = auth.uid()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Plants policies
CREATE POLICY "Admins have full access to plants"
    ON plants
    FOR ALL
    TO authenticated
    USING (get_user_role() = 'admin')
    WITH CHECK (get_user_role() = 'admin');

CREATE POLICY "Engineers and operators can view plants"
    ON plants
    FOR SELECT
    TO authenticated
    USING (get_user_role() IN ('engineer', 'operator'));

-- Assets policies
CREATE POLICY "Admins have full access to assets"
    ON assets
    FOR ALL
    TO authenticated
    USING (get_user_role() = 'admin')
    WITH CHECK (get_user_role() = 'admin');

CREATE POLICY "Engineers and operators can view assets"
    ON assets
    FOR SELECT
    TO authenticated
    USING (get_user_role() IN ('engineer', 'operator'));

-- Sensor readings policies
CREATE POLICY "All authenticated users can view sensor readings"
    ON sensor_readings
    FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "System can insert sensor readings"
    ON sensor_readings
    FOR INSERT
    TO authenticated
    WITH CHECK (get_user_role() IN ('admin', 'engineer'));

-- Alerts policies
CREATE POLICY "All authenticated users can view alerts"
    ON alerts
    FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Engineers and operators can create alerts"
    ON alerts
    FOR INSERT
    TO authenticated
    WITH CHECK (get_user_role() IN ('admin', 'engineer', 'operator'));

CREATE POLICY "Engineers and admins can update alerts"
    ON alerts
    FOR UPDATE
    TO authenticated
    USING (get_user_role() IN ('admin', 'engineer'))
    WITH CHECK (get_user_role() IN ('admin', 'engineer'));

-- Maintenance logs policies
CREATE POLICY "All authenticated users can view maintenance logs"
    ON maintenance_logs
    FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Engineers can create and update maintenance logs"
    ON maintenance_logs
    FOR ALL
    TO authenticated
    USING (get_user_role() IN ('admin', 'engineer'))
    WITH CHECK (get_user_role() IN ('admin', 'engineer'));

-- User roles policies
CREATE POLICY "Admins have full access to user roles"
    ON user_roles
    FOR ALL
    TO authenticated
    USING (get_user_role() = 'admin')
    WITH CHECK (get_user_role() = 'admin');

CREATE POLICY "Users can view their own role"
    ON user_roles
    FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());

-- Create indexes for better query performance
CREATE INDEX idx_sensor_readings_asset_timestamp ON sensor_readings(asset_id, timestamp);
CREATE INDEX idx_alerts_asset_status ON alerts(asset_id, status);
CREATE INDEX idx_maintenance_logs_asset ON maintenance_logs(asset_id);
CREATE INDEX idx_assets_plant ON assets(plant_id);