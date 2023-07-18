To run this calibration file you have to prepare your own raw IMU sensor data:
```matlab
load('IMU_data.mat');
```
The 'IMU_data.mat' has the following form:    
    n X 9  'acc_S03' data matrix containing raw accelerometer data;   
    n X 9  'gyro_S03' data matrix containing raw gyroscope data:   
    n X 9  'mag_S03' data matrix containing raw magnetometer data:  
where  
    n (number of rows): data length.    
    9 (number of columns): pelvis data in 1st-3rd column; left thigh data in 4th-6th column; right thigh data in 7th-9th column.

The final calibration matrices are:
```matlab
Rafsf_pelvis, R_afsf_left, Rafsf_right
```  
