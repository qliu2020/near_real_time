function loss = multiclass_logloss(y_true, y_pred)
% 计算多分类问题的对数损失
% y_true: 真实标签，大小为 [n_samples, 1]，每个元素是一个整数，表示样本的真实类别
% y_pred: 预测标签概率，大小为 [n_samples, n_classes]，每个元素是一个概率值，表示该样本属于每个类别的概率
% loss: 对数损失，一个实数

n_samples = size(y_true, 1);
%n_classes = size(y_pred, 2);
logloss = 0;

for i = 1:n_samples
    y_true_i = y_true(i)+1; %从 0 开始递增
    %y_true_i = y_true(i); %从 1 开始递增
    y_pred_i = y_pred(i,:);
    y_pred_i = max(min(y_pred_i, 1-10^-15), 10^-15); % 防止出现 log(0) 的情况
    logloss = logloss + log(y_pred_i(y_true_i)) ;
end

loss = -1/n_samples * logloss;

