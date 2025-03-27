import express, { Request, Response } from 'express';
import cors from 'cors';
import { createClient } from '@supabase/supabase-js';
import { 
  SensorReading, 
  ErrorResponse, 
  SuccessResponse, 
  SensorParams,
  SensorQuery,
  SensorRequestBody
} from './types.js';

const app = express();
const port = 3000;

// Initialize Supabase client
const supabaseClient = createClient(
  import.meta.env.VITE_SUPABASE_URL,
  import.meta.env.VITE_SUPABASE_SERVICE_ROLE_KEY
);

// Middleware
app.use(express.json());
app.use(cors());

// Validate sensor reading data
function validateSensorData(data: unknown): string | null {
  const sensorData = data as Partial<SensorReading>;
  
  if (!sensorData.asset_id || typeof sensorData.asset_id !== 'string') {
    return 'Invalid asset_id';
  }

  const numericFields: (keyof SensorReading)[] = ['temperature', 'pressure', 'vibration', 'energy_consumption'];
  for (const field of numericFields) {
    const value = sensorData[field];
    if (typeof value !== 'number' || isNaN(value)) {
      return `Invalid ${field}`;
    }
  }

  // Validate ranges based on database constraints
  if (sensorData.temperature! < -50 || sensorData.temperature! > 150) {
    return 'Temperature must be between -50 and 150';
  }
  if (sensorData.pressure! < 0) {
    return 'Pressure must be non-negative';
  }
  if (sensorData.vibration! < 0) {
    return 'Vibration must be non-negative';
  }
  if (sensorData.energy_consumption! < 0) {
    return 'Energy consumption must be non-negative';
  }

  return null;
}

// Sensor data ingestion route with proper TypeScript generics
app.post<SensorParams, SuccessResponse | ErrorResponse, SensorRequestBody, SensorQuery>(
  '/api/ingest-sensor/:id?',
  async (
    req: Request<SensorParams, SuccessResponse | ErrorResponse, SensorRequestBody, SensorQuery>,
    res: Response<SuccessResponse | ErrorResponse>
  ): Promise<void> => {
    try {
      // Get JWT token from Authorization header
      const authHeader = req.headers.authorization;
      if (!authHeader?.startsWith('Bearer ')) {
        res.status(401).json({ error: 'Missing or invalid Authorization header' });
        return;
      }

      const token = authHeader.split(' ')[1];

      // Verify JWT token
      const { data: { user }, error: authError } = await supabaseClient.auth.getUser(token);
      if (authError || !user) {
        res.status(401).json({ error: 'Invalid token' });
        return;
      }

      // Validate request body
      const validationError = validateSensorData(req.body);
      if (validationError) {
        res.status(400).json({ error: validationError });
        return;
      }

      // Store sensor reading in database
      const { error: insertError } = await supabaseClient
        .from('sensor_readings')
        .insert({
          asset_id: req.body.asset_id,
          temperature: req.body.temperature,
          pressure: req.body.pressure,
          vibration: req.body.vibration,
          energy_consumption: req.body.energy_consumption,
          timestamp: req.query.timestamp || new Date().toISOString(),
        });

      if (insertError) {
        console.error('Error inserting sensor data:', insertError);
        res.status(500).json({ error: 'Failed to store sensor reading' });
        return;
      }

      res.status(200).json({ message: 'Sensor reading stored successfully' });
      return;

    } catch (error) {
      console.error('Error processing request:', error);
      res.status(500).json({ error: 'Internal server error' });
      return;
    }
  }
);

// Start server
app.listen(port, () => {
  console.log(`Server running on port ${port}`);
});