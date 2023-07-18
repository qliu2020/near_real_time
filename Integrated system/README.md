'System.m' is the integrated system described in thesis Chapter 4.
## System Input
* Raw IMU sensor data 
```matlab
load('IMU_data.mat');
```
> The input data file should include 3 matrices: 
  >> 'acc_S03': n x 9 accelerometer readouts [pelvis x 3, left thigh x 3, right thigh x 3]  
  >> 'gyro_S03': n x 9 gyroscope readouts [pelvis x 3, left thigh x 3, right thigh x 3]  
  >> 'mag_S03': n x 9 magnetometer readouts [pelvis x 3, left thigh x 3, right thigh x 3]   
 
## System Output
* Calibration 
* Joint 
* Joint load
* Activity recognition result  
```matlab
Output_label
```
