clear; 
clc;
close all;
addpath( 'D:\课件\研二\Thesis\dataset\Dataset RUG - Soccer Specific Training Drill\S03\HAR\complete_4_drill');
%%
load('train_500_90_auto.mat');

train_set = dataset_train;
Xtrain = train_set(:,1:end-1);
ytrain = train_set(:,end);

% Training parameters
model_filename = 'xgboost_model.xgb';
params = [];
max_num_iters = 900;
early_stop= 1; 
model = xgboost_train(Xtrain,ytrain,params,max_num_iters,early_stop,model_filename); 

% Save the model configurations
save('model_config.mat','model');
