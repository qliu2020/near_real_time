classdef Madgwick_Filter < handle
    % MADGWICK_FILTER --> Algorithm that computes pitch and roll using a
    % quaternion based madgwick gradient descent algorithm. The algorithm
    % assumes x to be the longitudinal axis (horizontal component of earth 
    % magnetic field, y the vertical axis and z the lateral axis.
    %
    % Adapted from SOH Madgwick (2010)
    %
    %   Date Created            Last Modified               Author
    %    16-03-2017              25-05-2018                 Erik Wilmes
    %
    %   Last modification - Added initializing time (tInit) and
    %   initializing beta (bInit), which specifies algorithm gain (bInit)
    %   the first nr of seconds (tInit) to ensure fast initial convergence
    
    %%  Public Properties
    
    properties (Access = public)
        fs = 100;                   % Sample Period
        Quaternion = [1 0 0 0];     % Initial Quaternion
        Beta = 0.033;               % Algorithm gain
        tInit = 3;                  % Initializing period in s
        bInit = 3;                  % Initializing filter gain
        t = 0;                      % time
        b = [0 0 0 0];
    end
    
    %% Public Methods
    
    methods (Access = public)
        % function to get input filter parameters
        function obj = Madgwick_Filter(varargin)
            for i = 1:2:nargin
                if  strcmp(varargin{i},'fs'), obj.fs = varargin{i+1};
                elseif  strcmp(varargin{i},'Quaternion'), obj.Quaternion = varargin{i+1};
                elseif  strcmp(varargin{i},'Beta'), obj.Beta = varargin{i+1};
                elseif  strcmp(varargin{i},'tInit'), obj.tInit = varargin{i+1};
                elseif  strcmp(varargin{i},'bInit'), obj.bInit = varargin{i+1};
                else error('Invalid argument');
                end
            end
        end
        
        % Madgwick gradient descent algorithm
        
        function obj = UpdateIMU(obj,GyroData,AccData,MagData)
            % UPDATEIMU --> updates orientation IMU
            %
            % Inputs:     obj -->       current settings and status algorithm
            %             AccData -->   Accelerometer acceleration vector
            %             GyroData -->  Gyroscope angular velocity vector
            %             MagData -->   Magnetic field vector
            %
            % Output:     obj -->       updated status algorithm
            
            %------------- Initialize algorithm -----------------%
            
            % Assign variables to make algorithm readable
            q = obj.Quaternion;                 % Quaternion
            dt = 1/obj.fs;                      % stepsize delta
            t = obj.t;
            
            % assign algorithm gain
            if t < obj.tInit
                beta = obj.bInit;
            else
                beta = obj.Beta;
            end
            
            if norm(AccData) ~= 0 
                % Normalize Accelerometer data
                AccData = AccData / norm(AccData);
            end
            
            if norm(MagData) ~=0
                % Normalize Magnetometer data
                MagData = MagData / norm(MagData);
            end
            
            % Accelerometer quaternion
            q_acc = [0 AccData(1) AccData(2) AccData(3)];
            
            % Angular velocity quaternion
            q_gyro = [0 GyroData(1) GyroData(2) GyroData(3)];
            
            % Magnetic field quaternion
            q_mag = [0 MagData(1) MagData(2) MagData(3)];
            
            % Reference direction of Earth's magnetic field
            h = quaternProd(q, quaternProd(q_mag, quaternConj(q)));
            %            h = [0 0.387332494402697  -0.921940095006061  0];
            h = [0 norm([h(2) h(4)]) h(3) 0];
            
            b=h;
            
            if norm(h) ~=0
                b = h/norm(h);
            end
            
            
            %---- Gradient descent algorithm corrective step ----%
            
            % Define objective function
            F = [2 * (q(1)*q(4)+q(2)*q(3))-AccData(1);
                q(1)^2-q(2)^2+q(3)^2-q(4)^2-AccData(2);
                2*(q(3)*q(4)-q(1)*q(2))-AccData(3);
                b(2)*(q(1)^2+q(2)^2-q(3)^2-q(4)^2) + 2*b(3)*(q(1)*q(4)+q(2)*q(3)) + 2*b(4)*(q(2)*q(4)-q(1)*q(3))-MagData(1);
                2*b(2)*(q(2)*q(3)-q(1)*q(4)) + b(3)*(q(1)^2-q(2)^2+q(3)^2-q(4)^2) + 2*b(4)*(q(1)*q(2)+q(3)*q(4))-MagData(2);
                2*b(2)*(q(1)*q(3)+q(2)*q(4))+2*b(3)*(q(3)*q(4)-q(1)*q(2)) + b(4)*(q(1)^2-q(2)^2-q(3)^2+q(4)^2)-MagData(3)];
            
            % Define Jacobian
            J = [2*q(4),                                2*q(3),                                 2*q(2),                                  2*q(1);
                2*q(1),                                 -2*q(2),                                2*q(3),                                  -2*q(4);
                -2*q(2),                                -2*q(1),                                2*q(4),                                  2*q(3);
                2*b(2)*q(1)+2*b(3)*q(4)-2*b(4)*q(3),    2*b(2)*q(2)+2*b(3)*q(3)+2*b(4)*q(4),    -2*b(2)*q(3)+2*b(3)*q(2)-2*b(4)*q(1),    -2*b(2)*q(4)+2*b(3)*q(1)+2*b(4)*q(2);
                -2*b(2)*q(4)+2*b(3)*q(1)+2*b(4)*q(2),   2*b(2)*q(3)-2*b(3)*q(2)+2*b(4)*q(1),    2*b(2)*q(2)+2*b(3)*q(3)+2*b(4)*q(4),     -2*b(2)*q(1)-2*b(3)*q(4)+2*b(4)*q(3);
                2*b(2)*q(3)-2*b(3)*q(2)+2*b(4)*q(1),    2*b(2)*q(4)-2*b(3)*q(1)-2*b(4)*q(2),    2*b(2)*q(1)+2*b(3)*q(4)-2*b(4)*q(3),     2*b(2)*q(2)+2*b(3)*q(3)+2*b(4)*q(4)];
            
            % Corrective step
            step = (J'*F);
            
            % normalize step
            step = step/norm(step);
            
            % Compute quaternion rate of change
            q_dot = 0.5*quaternProd(q,q_gyro) - beta * step';
            
            %--------------- Update orientation quaternion ------------%
            
            % Integrative step to update orientation quaternion
            q = q + q_dot * dt;
            
            % Normalize quaternion
            q = q / norm(q);
            
            % Assign updated quaternion to object
            obj.Quaternion = q;
            
            % update time
            t = t+dt;
            obj.t = t;
            
            obj.b = b;
        end
    end
end

