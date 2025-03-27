export interface SensorReading {
    asset_id: string;
    temperature: number;
    pressure: number;
    vibration: number;
    energy_consumption: number;
    timestamp?: string;
  }
  
  export interface ErrorResponse {
    error: string;
  }
  
  export interface SuccessResponse {
    message: string;
  }
  
  // Request params interface
  export interface SensorParams {
    id?: string;
  }
  
  // Request query interface
  export interface SensorQuery {
    timestamp?: string;
  }
  
  // Request body interface
  export type SensorRequestBody = Omit<SensorReading, 'timestamp'>;