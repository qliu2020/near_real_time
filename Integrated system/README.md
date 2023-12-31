'System.m' is the integrated system described in thesis Chapter 4.
## System Input
* Raw IMU sensor data 
  ```matlab
  load('IMU_data.mat');
  ```
  The input data file should include 3 matrices: 
  * 'acc_S03': n x 9 accelerometer readouts [pelvis, left thigh, right thigh]  
  * 'gyro_S03': n x 9 gyroscope readouts [pelvis, left thigh, right thigh]  
  * 'mag_S03': n x 9 magnetometer readouts [pelvis, left thigh, right thigh]   
 
## System Output
* Data to be displayed in the user interface
  ```matlab
   'UI_data.mat'
  ```
  This data file contains the following variables: 
  * Lower limbs (pelvis and left/right thigh) orientations
  ```matlab
  quat_pelvis, quat_left, quat_right
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
  * Time when the system finished calibration
  ```matlab
  ind_calib_finished
  ```
