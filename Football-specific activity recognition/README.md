# Model Training
If you want to train your model, please run 'train.m' and use your training data：  
```matlab
load('train_data.mat');  
```
The data should be a n x 13 matrix. n is the number of your training data points. For each instance, the first 12 columns should be the left hip tri-axial angles (XYZ), left hip tri-axial angular velocities (XYZ), right hip tri-axial angles (XYZ), and right hip tri-axial angular velocities (XYZ). The last column for each sample should be the class label (the class should start with '0').  

Running the 'train.m' file will generate an 'xgboost_model.xgb' file saving the model and a 'model_config.mat' file saving the model configuration information.   

The model used in this thesis is saved as 'xgboost_model_auto.xgb' with the configuration file 'model_auto_config.mat'  

# Model Testing  
If you want to test the trained model's performance, please run 'test.m' using your configuration file and test data:
```matlab
load('test_data.mat');
load('model_config.mat');
```
please make sure that 
The test data should also be a n x 13 matrix, having the same format as the training data.  
'test.m' will plot the result's confusion matrix and calculate the model performance (accuracy, precision, recall, F1-score, etc) automatically.
  


