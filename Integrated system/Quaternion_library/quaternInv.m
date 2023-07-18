function q_inverse = quaternInv(q)
%QUATERNINV Converts a quaternion to its inverse
%
%   q_inverse = quaternInv(q)
%
%   Converts a quaternion to its inverse.
%
%	Date                Author       
%	07/03/2017          Erik Wilmes      

    q_inverse = [q(:,1) -q(:,2) -q(:,3) -q(:,4)]./(norm(q).^2);
end