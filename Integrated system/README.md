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
(Data to be displayed in the user interface)
* Lower limbs orientations
```matlab
q_pelvis, q_leftthigh, q_rightthigh 
```
* Hip flexion angles
```matlab
flexExLH, flexExRH
```
* Hip joint loads
```matlab
lhload, rhload
```
* Activity recognition results  
```matlab
Output_label
```
