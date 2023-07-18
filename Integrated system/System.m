clear;
clc;
close all;
addpath('Quaternion_library\');
%%
% load raw IMU data
load('IMU_S03_1st_drill.mat');
acc_raw = acc_S03;
gyro_raw = gyro_S03;
mag_raw = mag_S03;

% Time parameters
tIndex = 1;
n_sample = size(acc_raw,1);
window_size = 500;
fs = 500;
fps = 20;
n = round(fs/fps); % Number of samples to be processed in one iteration

% Read and store data in 500x3 windows
acc_window = [zeros(n,9);acc_raw(1:window_size-n,:)];
gyro_window = [zeros(n,9);gyro_raw(1:window_size-n,:)];
mag_window = [zeros(n,9);mag_raw(1:window_size-n,:)];

% Initialize calibration parameters
q_calib_pelvis = zeros(1,4);
q_calib_left = zeros(1,4);
q_calib_right = zeros(1,4);
calib_status = 0;
static_time = 0;
func_time = 0 ;
eps = 1e-8;
ind_calib_finished = 0;

% Orientation filter setting
IMU_p = Madgwick_Filter('fs', fs,'Quaternion',[-0.0358, -0.2831, -0.0184, 0.9582],'Beta', 0.043,'tInit',0,'bInit',3);  
IMU_l = Madgwick_Filter('fs', fs,'Quaternion',[0.1822, 0.8456, 0.0016, -0.5017],'Beta', 0.043,'tInit',0,'bInit',3);
IMU_r = Madgwick_Filter('fs', fs,'Quaternion',[-0.0545, 0.4975, 0.0246, 0.8654],'Beta', 0.043,'tInit',0,'bInit',3);
  
% Initialize sensor orientation
q_pelvis = zeros(n,4);
q_leftthigh = zeros(n,4);
q_rightthigh = zeros(n,4);

quat_pelvis = zeros(n_sample,4);
quat_left = zeros(n_sample,4);
quat_right = zeros(n_sample,4);
% Initialize joint orientations
q_lefthip = zeros(n,4);
q_righthip = zeros(n,4);

% Initialize joint kinematics
lefthip_xRot = zeros(window_size,1);
lefthip_yRot = zeros(window_size,1);
lefthip_zRot = zeros(window_size,1);

righthip_xRot = zeros(window_size,1);
righthip_yRot = zeros(window_size,1);
righthip_zRot = zeros(window_size,1);
 
gyro_pelvis =  zeros(n,3);
gyro_leftthigh = zeros(n,3);
gyro_rightthigh =  zeros(n,3);

lefthip_angularVel = zeros(window_size,3);
righthip_angularVel = zeros(window_size,3);

% Activity regognition parameters
overlap = 4; 
window_joint_data = zeros(window_size,12);
frame_num = fix((n_sample-window_size)/n)+1;
class_num = 5;

% Load XGBoost lib files
load('model_auto_config.mat');
if not(libisloaded('xgboost'))
    cwd = pwd; cd ..\lib
    loadlibrary('xgboost')
    cd(cwd)
end

% Initialize model pointers
h_train_ptr = libpointer;
h_train_ptr_ptr = libpointer('voidPtrPtr', h_train_ptr);
h_booster_ptr = libpointer;
h_booster_ptr_ptr = libpointer('voidPtrPtr', h_booster_ptr);
len = uint64(0); 
calllib('xgboost', 'XGBoosterCreate', h_train_ptr_ptr, len, h_booster_ptr_ptr);
calllib('xgboost', 'XGBoosterLoadModel', h_booster_ptr_ptr, model.model_filename);

rows = uint64(1);
cols = uint64(12);
h_test_ptr = libpointer;
h_test_ptr_ptr = libpointer('voidPtrPtr', h_test_ptr);

out_len = uint64(0);
out_len_ptr = libpointer('uint64Ptr', out_len);
f = libpointer('singlePtr');
f_ptr = libpointer('singlePtrPtr', f);
option_mask = int32(0);
ntree_limit = uint32(0);
training = int32(0);

% Initialize activity recognition model's input and output
ind_after_calib = 0 ;
input = zeros(1,12);
output_matrix = zeros(5,frame_num+n);
output_label= zeros(1,n_sample);

% Initialize parameters for load calculation
lefthip_angle_acc = zeros(1,n-1);
righthip_angle_acc = zeros(1,n-1);

lhload = zeros(1,n_sample);
rhload = zeros(1,n_sample);
flexExLH = zeros(1,n_sample);
flexExRH = zeros(1,n_sample);
%%
while tIndex<n_sample-window_size
   
    
    if tIndex + n <n_sample-window_size
        tIndex = tIndex + n;
    else
        tIndex = n_sample-window_size;
    end

    m = tIndex+window_size-n : tIndex+window_size-1;
    
    % Read 25 new data points and disgard oldest 25 samples
    acc_window(1:window_size-n,:) = acc_window(n+1:end,:);
    acc_window(window_size-n+1:end,:) = acc_raw(m,:);
    gyro_window(1: window_size-n,:) =  gyro_window(n+1:end,:);
    gyro_window( window_size-n+1:end,:) =  gyro_raw(m,:);
    mag_window(1: window_size-n,:) =  mag_window(n+1:end,:);
    mag_window( window_size-n+1:end,:) =  mag_raw(m,:);

    % update orientation
    for i =1: n
         IMU_p.UpdateIMU( gyro_window(i,1:3), acc_window(i,1:3),  mag_window(i,1:3));
         IMU_l.UpdateIMU( gyro_window(i,4:6), acc_window(i,4:6),  mag_window(i,4:6));
         IMU_r.UpdateIMU( gyro_window(i,7:9), acc_window(i,7:9),  mag_window(i,7:9));
         q_pelvis(i,:) =  IMU_p.Quaternion;
         q_leftthigh(i,:) =  IMU_l.Quaternion;
         q_rightthigh(i,:) =  IMU_r.Quaternion;
    end
    
    if calib_status == 0
        % If the system is not calibrated
        
        mad = MAD(acc_window(:,1:3));
 
        % If it is identified as 'standing'
        if mad <= 1.5 && static_time-3<-eps
            % Store the corresponding acc and mag data
            ind_static = round(static_time*fs);
            acc_StaticCalibPelvis( ind_static+1: ind_static+n,:) = acc_window(1:n,1:3);
            acc_StaticCalibLeft( ind_static+1: ind_static+n,:) = acc_window(1:n,4:6);
            acc_StaticCalibRight( ind_static+1: ind_static+n,:) = acc_window(1:n,7:9);
            mag_StaticCalibPelvis( ind_static+1: ind_static+n,:) = mag_window(1:n,1:3);
            mag_StaticCalibLeft( ind_static+1: ind_static+n,:) = mag_window(1:n,4:6);
            mag_StaticCalibRight( ind_static+1: ind_static+n,:) = mag_window(1:n,7:9);
            static_time = static_time + 0.05;
            
        % If it is identified as 'walking'
        elseif mad >= 1.75 && mad <= 3.5 && func_time-3<-eps
            % Store the corresponding gyro data
            ind_func= round(func_time*fs);
            gyro_HeadCalibLeft( ind_func+1: ind_func+n,:) = gyro_window(1:n,4:6);
            gyro_HeadCalibRight( ind_func+1: ind_func+n,:) = gyro_window(1:n,7:9);    
            func_time = func_time + 0.05;         
        end
        
        % If enough IMU data is collected, end the loop
        if (static_time-3) > -eps && (func_time-3) > -eps
            calib_status = 1;
            ind_calib_finished = tIndex; 
            [q_calib_pelvis,q_calib_left,q_calib_right] = Calib(acc_StaticCalibPelvis,acc_StaticCalibLeft,acc_StaticCalibRight,...
                gyro_HeadCalibLeft,gyro_HeadCalibRight,mag_StaticCalibPelvis,mag_StaticCalibLeft,mag_StaticCalibRight);
        end
    else
        % convert orientation to be alligned with global reference frame
         q_pelvis = quatmultiply(q_pelvis, q_calib_pelvis);
         q_leftthigh = quatmultiply( q_leftthigh, q_calib_left);
         q_rightthigh = quatmultiply( q_rightthigh, q_calib_right);

         quat_pelvis(tIndex-n:tIndex-1,:) = q_pelvis;
         quat_left(tIndex-n:tIndex-1,:) = q_leftthigh;
         quat_right(tIndex-n:tIndex-1,:) = q_rightthigh;
        % Caluculate joint quaternion
         q_lefthip = quatmultiply(quatinv(q_pelvis), q_leftthigh);
         q_righthip = quatmultiply(quatinv(q_pelvis), q_rightthigh);

        % Get joint kinematics
        lefthip_xRot(1:window_size-n) = lefthip_xRot(n+1:end);
        lefthip_yRot(1:window_size-n) = lefthip_yRot(n+1:end);
        lefthip_zRot(1:window_size-n) = lefthip_zRot(n+1:end);
        [lefthip_zRot(window_size-n+1:end),...
         lefthip_xRot(window_size-n+1:end),...
         lefthip_yRot(window_size-n+1:end)] = quat2angle(q_lefthip,'ZXY');

        righthip_xRot(1:window_size-n) = righthip_xRot(n+1:end);
        righthip_yRot(1:window_size-n) = righthip_yRot(n+1:end);
        righthip_zRot(1:window_size-n) = righthip_zRot(n+1:end);
        [righthip_zRot(window_size-n+1:end),...
         righthip_xRot(window_size-n+1:end),...
         righthip_yRot(window_size-n+1:end)] = quat2angle(q_righthip,'ZXY');


        gyro_pelvis = quatrotate(q_calib_pelvis, gyro_window(1:n,1:3));
        gyro_leftthigh = quatrotate(q_calib_left, gyro_window(1:n,4:6));
        gyro_rightthigh = quatrotate(q_calib_right, gyro_window(1:n,7:9));

        lefthip_angularVel(1:window_size-n,:) = lefthip_angularVel(n+1:end,:);
        lefthip_angularVel(window_size-n+1:end,:) = quatrotate(q_lefthip,-gyro_pelvis)+gyro_leftthigh;
        righthip_angularVel(1:window_size-n,:) = righthip_angularVel(n+1:end,:);
        righthip_angularVel(window_size-n+1:end,:) = quatrotate(q_righthip,-gyro_pelvis)+gyro_rightthigh; 
    
        % Recognize football-specifc activites
        ind_after_calib = ind_after_calib+1;
        
        if mod(ind_after_calib,overlap) == 1
            % Compute mean joint kinematics as the model input
            window_joint_data = [rad2deg(lefthip_xRot)';rad2deg(lefthip_yRot)';rad2deg(lefthip_zRot)'; rad2deg(lefthip_angularVel)';...
                           rad2deg(righthip_xRot)';rad2deg(righthip_yRot)';rad2deg(righthip_zRot)';rad2deg(righthip_angularVel)']';
            if ind_after_calib<round(window_size/n)
                input = mean(window_joint_data(round(window_size-ind_after_calib*n)+1:end,:))';
            else 
                input = mean(window_joint_data)';
            end
            test_ptr = libpointer('singlePtr',single(input));   
            calllib('xgboost', 'XGDMatrixCreateFromMat', test_ptr, rows, cols, model.missing, h_test_ptr_ptr);
            calllib('xgboost', 'XGBoosterPredict', h_booster_ptr, h_test_ptr, option_mask, ntree_limit, training, out_len_ptr, f_ptr);

            % Extract predictions
            n_outputs = out_len_ptr.Value;
            setdatatype(f,'singlePtr',n_outputs);
            prob = double(f.Value); % predictions probabilities
            prob = reshape(prob',n_outputs,[]);

            % Compute output label using best-score postprocessing  
            output_matrix(:,ind_after_calib:ind_after_calib+round(window_size/n)-1) = output_matrix(:,ind_after_calib:ind_after_calib+round(window_size/n)-1)+prob; 
            [~,ind]= max(output_matrix(:,ind_after_calib:ind_after_calib+overlap-1)); 
            label = mode(ind)-1;
            k = (ind_after_calib-1)*n+1:(ind_after_calib-1+overlap)*n; %1:100,101:200,....
            k = k + ind_calib_finished-1;
            output_label(k) = label;
        end

        % Calculate joitn load
        lefthip_angle_acc = rad2deg(diff(lefthip_angularVel([window_size-n+1,end],:)))*fs/(n-1);
        lhload(tIndex-n:tIndex-1) = sum(lefthip_angle_acc.^2)/1e8;
                
        righthip_angle_acc = rad2deg(diff(righthip_angularVel([window_size-n+1,end],:)))*fs/(n-1);
        rhload(tIndex-n:tIndex-1) = sum(righthip_angle_acc.^2)/1e8;  
        
        flexExLH(tIndex-n:tIndex-1) = 180-rad2deg(lefthip_zRot(window_size-n+1:end));
        flexExRH(tIndex-n:tIndex-1) = 180-rad2deg(righthip_zRot(window_size-n+1:end));
    end
end

%%
function mad = MAD(acc)
    temp = sqrt(acc(:,1).^2 + acc(:,2).^2 + acc(:,3).^2);
    mad = sum(abs(temp-mean(temp)))/500;
end

function [q_pelvis,q_left,q_right] = Calib(acc_StaticCalibPelvis,acc_StaticCalibLeft,acc_StaticCalibRight,gyro_HeadCalibLeft,gyro_HeadCalibRight,mag_StaticCalibPelvis,mag_StaticCalibLeft,mag_StaticCalibRight)
    y_pelvis = mean(acc_StaticCalibPelvis);
    y_pelvis = y_pelvis/norm(y_pelvis);
    z_pelvis = cross([1 0 0],y_pelvis);
    z_pelvis = z_pelvis/norm(z_pelvis);
    x_pelvis = cross(y_pelvis,z_pelvis);
    x_pelvis = x_pelvis/norm(x_pelvis);
    Rvfsf_pelvis = [x_pelvis;y_pelvis;z_pelvis];

    y_left = mean(acc_StaticCalibLeft);
    y_left = y_left/norm(y_left);
    z_left = cross([1 0 0],y_left);
    z_left = z_left/norm(z_left);
    x_left = cross(y_left,z_left);
    x_left = x_left/norm(x_left);
    Rvfsf_left = [x_left;y_left;z_left];

    y_right = mean(acc_StaticCalibRight);
    y_right = y_right/norm(y_right);
    z_right = cross([1 0 0],y_right);
    z_right = z_right/norm(z_right);
    x_right = cross(y_right,z_right);
    x_right = x_right/norm(x_right);
    Rvfsf_right = [x_right;y_right;z_right];

    gyro_vf_Left = gyro_HeadCalibLeft * Rvfsf_left';
    gyro_Left = gyro_vf_Left(:,[3,1]);
    C_left = pca(gyro_Left,'Centered',false);
    gamma_left = -atan2(C_left(2,1),C_left(1,1));
    Rafvf_left=[cos(gamma_left) 0 sin(gamma_left); 0 1 0; -sin(gamma_left) 0 cos(gamma_left)];

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
    
    q_pelvis= rotm2quat(Rafsf_pelvis);
    q_left = rotm2quat(Rafsf_left);
    q_right = rotm2quat(Rafsf_right);

end