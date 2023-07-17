clear; 
clc;
close all;
addpath( 'D:\课件\研二\Thesis\dataset\Dataset RUG - Soccer Specific Training Drill\S03\HAR\complete_4_drill');
%%
load('test_500_90_auto.mat');
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