clear; 
clc;
close all;
%%
load('your_test_data.mat');
load('model_config.mat');
test_set = dataset_test;
Xtest = test_set(:,1:end-1); 
ytest = test_set(:,end);
Yhat = xgboost_test(Xtest,ytest,model,1);

% plot confusion matrix
plot_confusion(ytest, Yhat);

% evaluate model performance
[c_matrix,~,~]= confusion.getMatrix(ytest,Yhat);
[Result,RefereceResult]= confusion.getValues(c_matrix);
