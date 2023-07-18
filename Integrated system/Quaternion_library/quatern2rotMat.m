function R = quatern2rotMat(q)

q = (q.*(1./sqrt(sum(q.^2,2))))';

% Reshape the quaternions in the depth dimension
q2 = reshape(q,[4 1 size(q,2)]);

s = q2(1,1,:);
x = q2(2,1,:);
y = q2(3,1,:);
z = q2(4,1,:);

% Explicitly define concatenation dimension for codegen
tempR = cat(1, 1 - 2*(y.^2 + z.^2),   2*(x.*y - s.*z),   2*(x.*z + s.*y),...
2*(x.*y + s.*z), 1 - 2*(x.^2 + z.^2),   2*(y.*z - s.*x),...
2*(x.*z - s.*y),   2*(y.*z + s.*x), 1 - 2*(x.^2 + y.^2) );

R = reshape(tempR, [3, 3, length(s)]);
R = permute(R, [2 1 3]);
end