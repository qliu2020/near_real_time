function DCM = quatern2dcm(q)
%% quatern2dcm: Function that calculates direct cosine matrix from quaternion
% Input:    q --> quaternion as input
% Output:   DCM --> direct cosine matrix as output
%
%    Author            Date Created                Last modified
%   Erik Wilmes         13-03-2017                  13-03-2017

%% Calculate DCM

% pre-allocate
DCM = NaN(3,3)

% Calculate
DCM(1,1) = q(1).^2 + q(2).^2 - q(3).^2 - q(4).^2;
DCM(1,2) = 2 * (q(2)*q(3) + q(1)*q(4));
DCM(1,3) = 2 * (q(2)*q(4) - q(1)*q(3));

DCM(2,1) = 2 * (q(2)*q(3) - q(1)*q(4));
DCM(2,2) = q(1).^2 - q(2).^2 + q(3).^2 - q(4).^2;
DCM(2,3) = 2 * (q(3)*q(4) + q(1)*q(2));

DCM(3,1) = 2 * (q(2)*q(4) + q(1)*q(3));
DCM(3,2) = 2 * (q(3)*q(4) - q(1)*q(2));
DCM(3,3) = q(1).^2 - q(2).^2 - q(3).^2 + q(4).^2;