clear; 
clc;
close all;
%% Initialization
% load raw IMU data 
load('IMU_data.mat');

% Define sliding window parameters for MAD claculations
window_size = 500;
overlap = 25;

% Initialize IMU data container for calibration 
fs = 500;
static_duration = 3; 
heading_duration = 3;
acc_StaticCalibPelvis = zeros(static_duration*fs,3);
acc_StaticCalibLeft = zeros(static_duration*fs,3);
acc_StaticCalibRight = zeros(static_duration*fs,3);
mag_StaticCalibPelvis = zeros(static_duration*fs,3);
mag_StaticCalibLeft = zeros(static_duration*fs,3);
mag_StaticCalibRight = zeros(static_duration*fs,3);
gyro_HeadCalibLeft = zeros(heading_duration*fs,3);
gyro_HeadCalibRight = zeros(heading_duration*fs,3);

% Paramters controlling the while loop
i = 1;
static_time = 0;
func_time = 0 ;
calib_status = 0;
eps=1e-8;

%% Read in the raw IMU data using the sliding window
while calib_status == 0
    acc_window = acc_S03((i-1)*overlap+1:(i-1)*overlap+window_size,:);
    gyro_window = gyro_S03((i-1)*overlap+1:(i-1)*overlap+window_size,:);
    mag_window = mag_S03((i-1)*overlap+1:(i-1)*overlap+window_size,:);
    
    % Calaulte the MAD value of the raw pelvis acc data in the current window 
    mad = MAD(acc_window(:,1:3));
    
        % If it is identified as 'standing'
        if mad <= 1.5 && static_time-3<-eps
            % Store the corresponding acc and mag data
            acc_StaticCalibPelvis(static_time*fs+1:static_time*fs+overlap,:) = acc_window(1:overlap,1:3);
            acc_StaticCalibLeft(static_time*fs+1:static_time*fs+overlap,:) = acc_window(1:overlap,4:6);
            acc_StaticCalibRight(static_time*fs+1:static_time*fs+overlap,:) = acc_window(1:overlap,7:9);
            mag_StaticCalibPelvis(static_time*fs+1:static_time*fs+overlap,:) = mag_window(1:overlap,1:3);
            mag_StaticCalibLeft(static_time*fs+1:static_time*fs+overlap,:) = mag_window(1:overlap,4:6);
            mag_StaticCalibRight(static_time*fs+1:static_time*fs+overlap,:) = mag_window(1:overlap,7:9);
            static_time = static_time + 0.05;
            
        % If it is identified as 'walking'
        elseif mad >= 1.75 && mad <= 3.5 && func_time-3<-eps
            % Store the corresponding gyro data
            gyro_HeadCalibLeft(func_time*fs+1:func_time*fs+overlap,:) = gyro_window(1:overlap,4:6);
            gyro_HeadCalibRight(func_time*fs+1:func_time*fs+overlap,:) = gyro_window(1:overlap,7:9);    
            func_time = func_time + 0.05;         
        end
        
        % If enough IMU data is collected, end the loop
        if (static_time-3) > -eps && (func_time-3) > -eps
            calib_status = 1;
        end
    i = i+1;
end
%% Vertical calibration

% Pelvis sensor
y_pelvis = mean(acc_StaticCalibPelvis);
y_pelvis = y_pelvis/norm(y_pelvis);
z_pelvis = cross([1 0 0],y_pelvis);
z_pelvis = z_pelvis/norm(z_pelvis);
x_pelvis = cross(y_pelvis,z_pelvis);
x_pelvis = x_pelvis/norm(x_pelvis);
Rvfsf_pelvis = [x_pelvis;y_pelvis;z_pelvis];

% Left thigh sensor
y_left = mean(acc_StaticCalibLeft);
y_left = y_left/norm(y_left);
z_left = cross([1 0 0],y_left);
z_left = z_left/norm(z_left);
x_left = cross(y_left,z_left);
x_left = x_left/norm(x_left);
Rvfsf_left = [x_left;y_left;z_left];

% Right thigh sensor
y_right = mean(acc_StaticCalibRight);
y_right = y_right/norm(y_right);
z_right = cross([1 0 0],y_right);
z_right = z_right/norm(z_right);
x_right = cross(y_right,z_right);
x_right = x_right/norm(x_right);
Rvfsf_right = [x_right;y_right;z_right];

%% Heading calibration

% Left thigh sensor
gyro_vf_Left = gyro_HeadCalibLeft * Rvfsf_left';
gyro_Left = gyro_vf_Left(:,[3,1]);
C_left = pca(gyro_Left,'Centered',false);
gamma_left = -atan2(C_left(2,1),C_left(1,1));
Rafvf_left=[cos(gamma_left) 0 sin(gamma_left); 0 1 0; -sin(gamma_left) 0 cos(gamma_left)];

% Right thigh sensor
gyro_vf_Right = gyro_HeadCalibRight * Rvfsf_right';
gyro_Right = gyro_vf_Right(:,[3,1]);
C_right = pca(gyro_Right,'Centered',false);
gamma_right = -pi-atan2(C_right(2,1),C_right(1,1));
Rafvf_right=[cos(gamma_right) 0 sin(gamma_right); 0 1 0; -sin(gamma_right) 0 cos(gamma_right)];

% Final transformation matrix for two thigh sensors
Rafsf_left = Rafvf_left * Rvfsf_left;
Rafsf_right = Rafvf_right * Rvfsf_right;

% Using mag data during the standing period and two thigh calibration results to calibrate the pelvis sensor
mag_left = mag_StaticCalibLeft*Rafsf_left';
mag_right = mag_StaticCalibRight*Rafsf_right';
mag_pelvis = mag_StaticCalibPelvis*Rvfsf_pelvis';

theta1 = atan2(mean(mag_left(:,1)),mean(mag_left(:,3)));
theta2 = atan2(mean(mag_right(:,1)),mean(mag_right(:,3)));
theta3 = atan2(mean(mag_pelvis(:,1)),mean(mag_pelvis(:,3)));
gamma_pelvis = mean([theta1,theta2])-theta3;

% Final transformation matrix for the pelvis sensor
Rafvf_pelvis=[cos(gamma_pelvis) 0 sin(gamma_pelvis); 0 1 0; -sin(gamma_pelvis) 0 cos(gamma_pelvis)];
Rafsf_pelvis = Rafvf_pelvis * Rvfsf_pelvis;
 

%% Function calculating the MAD value 
function mad = MAD(acc)
    temp = sqrt(acc(:,1).^2 + acc(:,2).^2 + acc(:,3).^2);
    mad = sum(abs(temp-mean(temp)))/500;
end

