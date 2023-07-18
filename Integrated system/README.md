'System.m' is the integrated system described in thesis Chapter 4.
## System Input
* Raw IMU sensor data 
```matlab
load('IMU_data.mat');
```
> The input data file should include 3 matrices: 
  >> 'acc_S03': n x 9 accelerometer readouts [pelvis, left thigh, right thigh]  
  >> 'gyro_S03': n x 9 gyroscope readouts [pelvis, left thigh, right thigh]  
  >> 'mag_S03': n x 9 magnetometer readouts [pelvis, left thigh, right thigh]   
 
## System Output
* Calibration parameters
```matlab
q_calib_pelvis, q_calib_left, q_calib_right
```
* Joint angles
```matlab
lefthip_xRot, lefthip_yRot, lefthip_zRot, righthip_xRot, righthip_yRot, righthip_zRot 
```
* Joint angular velocities
```matlab
lefthip_angularVel, righthip_angularVel 
```
* Joint loads
```matlab
lhload, rhload
```
* Activity recognition results  
```matlab
Output_label
```
