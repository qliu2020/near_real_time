function model = xgboost_train(Xtrain,ytrain,params,max_num_iters,early_stop,model_filename)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%5
% set some parameters manually:
early_stopping_rounds = 10; % use CV with early_stopping_rounds== [10]   
missing = single(NaN);      % set a value to be treated as "missing" 

% set max number of iterations for learning
if isempty(max_num_iters)
    max_num_iters = 999; % == num_boost_round
end    
        
% parse xgboost parameters:
%%% default in https://stackoverflow.com/questions/36071672/using-xgboost-in-c:
if isempty(params)
    params.booster           = 'gbtree';
    params.objective         = 'multi:softprob';
    params.num_class         = 5;
    params.max_depth         = 5;
    params.eta               = 0.1;
    params.min_child_weight  = 1;
    params.subsample         = 0.9;
    params.colsample_bytree  = 1;
    params.num_parallel_tree = 1;
end

%%%default using early stop strategy
if isempty(early_stop)
    early_stop = 1;
end

%%% set parameters
param_fields = fields(params);
for i=1:length(param_fields)
    eval(['params.' param_fields{i} ' = num2str(params.' param_fields{i} ');'])
end

%%% load the xgboost library
if not(libisloaded('xgboost'))
    cwd = pwd; cd ..\lib
    loadlibrary('xgboost')
    cd(cwd)
end

%%% split train/validation 
ind = zeros(length(ytrain), 1);
s = RandStream('mlfg6331_64'); 
for c = 1:str2double(params.num_class)
    c_idx = find(ytrain == c-1); 
    n_c = length(c_idx);   
    n_val = round(n_c * 0.2);  
    val_idx = randsample(s,c_idx, n_val, false); 
    ind(val_idx) = 1;
end
iters_reached = 0;

% post-process input data
rows = uint64(sum(ind~=1)); % use uint64(size(Xtrain,1)) in case of no CV
cols = uint64(size(Xtrain,2));

% create relevant pointers
train_ptr = libpointer('singlePtr',single(Xtrain(ind~=1,:)')); % the transposed (cv)training set is supplied to the pointer
train_labels_ptr = libpointer('singlePtr',single(ytrain(ind~=1)));

h_train_ptr = libpointer;
h_train_ptr_ptr = libpointer('voidPtrPtr', h_train_ptr);

% convert input matrix to DMatrix
calllib('xgboost', 'XGDMatrixCreateFromMat', train_ptr, rows, cols, missing, h_train_ptr_ptr);

% handle the labels (target variable)
labelStr = 'label';
calllib('xgboost', 'XGDMatrixSetFloatInfo', h_train_ptr, labelStr, train_labels_ptr, rows);

% create the booster and set some parameters
h_booster_ptr = libpointer;
h_booster_ptr_ptr = libpointer('voidPtrPtr', h_booster_ptr);
len = uint64(1);

calllib('xgboost', 'XGBoosterCreate', h_train_ptr_ptr, len, h_booster_ptr_ptr);
for i=1:length(param_fields)
    eval(['calllib(''xgboost'', ''XGBoosterSetParam'', h_booster_ptr, ''' param_fields{i} ''', ''' eval(['params.' param_fields{i}]) ''');'])
end
%%% for example:
% calllib('xgboost', 'XGBoosterSetParam', h_booster_ptr, 'booster', 'gbtree');
% calllib('xgboost', 'XGBoosterSetParam', h_booster_ptr, 'objective', 'binary:logistic'); % 'reg:linear' , 'binary:logistic'
% calllib('xgboost', 'XGBoosterSetParam', h_booster_ptr, 'max_depth', '5');
% calllib('xgboost', 'XGBoosterSetParam', h_booster_ptr, 'eta', '0.1');
% calllib('xgboost', 'XGBoosterSetParam', h_booster_ptr, 'min_child_weight', '1');
% calllib('xgboost', 'XGBoosterSetParam', h_booster_ptr, 'subsample', '1'); % '1', '0.5'
% calllib('xgboost', 'XGBoosterSetParam', h_booster_ptr, 'colsample_bytree', '1');
% calllib('xgboost', 'XGBoosterSetParam', h_booster_ptr, 'num_parallel_tree', '1');
% calllib('xgboost', 'XGBoosterSetParam', h_booster_ptr, 'eval_metric', 'logloss'); % eg: 'logloss' , 'auc' , 'mae'. NOTE: there is no way to provide early_stopping_rounds inside params
% see https://blog.cambridgespark.com/hyperparameter-tuning-in-xgboost-4ff9100a3b2f
% see https://machinelearningmastery.com/avoid-overfitting-by-early-stopping-with-xgboost-in-python/

% initialize
log_loss = []; % logistic loss      - for CV performance evaluation

% create a test set
h_test_ptr = libpointer;
h_test_ptr_ptr = libpointer('voidPtrPtr', h_test_ptr);
test_ptr = libpointer('singlePtr',single(Xtrain(ind==1,:)')); % the transposed (cv)training set is supplied to the pointer
yCV      = ytrain(ind==1); % not supplied to xgboost.dll
rows = uint64(sum(ind==1)); % use uint64(size(Xtrain,1)) in case of no CV
cols = uint64(size(Xtrain,2));
calllib('xgboost', 'XGDMatrixCreateFromMat', test_ptr, rows, cols, missing, h_test_ptr_ptr);

% perform up to max_num_iters learning iterations. Stop learning if eval_metric is not improved over last early_stopping_rounds (number of) iterations
for iter = 0:max_num_iters
    % disp(['iter (cv ' num2str(kk) ') = ' num2str(iter)])
    calllib('xgboost', 'XGBoosterUpdateOneIter', h_booster_ptr, int32(iter), h_train_ptr);

    %%%  Make predictions on a CV test set
    % predict
    out_len = uint64(0);
    out_len_ptr = libpointer('uint64Ptr', out_len);
    f = libpointer('singlePtr');
    f_ptr = libpointer('singlePtrPtr', f);
    option_mask = int32(0);
    ntree_limit = uint32(0);
    training = int32(0);
    calllib('xgboost', 'XGBoosterPredict', h_booster_ptr, h_test_ptr, option_mask, ntree_limit, training, out_len_ptr, f_ptr);

    % extract predictions
    n_outputs = out_len_ptr.Value; % n_outputs = n_validation*num_class
    setdatatype(f,'singlePtr',n_outputs);

    YhatCV = double(f.Value); % display the predictions (in case objective == 'binary:logistic' : display the predicted probabilities)
    YhatCV = reshape(YhatCV',str2double(params.num_class),[])';
    % YhatCV = round(YhatCV); % so that we get the label

    % use AUC as evaluation metric
    loss = multiclass_logloss(yCV,YhatCV);
    log_loss = [log_loss; loss];
    if  early_stop == 1
        if length(log_loss) > early_stopping_rounds && log_loss(iter-early_stopping_rounds+2) == min(log_loss(iter-early_stopping_rounds+2:end))
            iters_reached = iter-early_stopping_rounds+2;
            break
        end
    else
         iters_reached = iter;
    end
end

% free xgboost internal structures
if exist('h_train_ptr','var')
    calllib('xgboost', 'XGDMatrixFree',h_train_ptr); clear h_train_ptr
end
if exist('h_test_ptr','var')
    calllib('xgboost', 'XGDMatrixFree',h_test_ptr); clear h_test_ptr
end

% plot loss curve
figure(1);
plot(log_loss);
disp('optimal iterations :');
disp(iters_reached);

% save model
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
model                = struct;
model.iters_optimal  = iters_reached; % number of iterations performs by xgboost
model.h_booster_ptr  = h_booster_ptr; % pointer to the final model
model.params         = params;        % just for info
model.missing        = missing;       % value considered "missing"
model.model_filename = '';            % initialize: filename for model (to be saved)

if ~(isempty(model_filename) || strcmp(model_filename,''))
    calllib('xgboost', 'XGBoosterSaveModel', h_booster_ptr_ptr, model_filename);
    model.model_filename = model_filename; % 'xgboost_model.xgb'
end


if exist('h_booster_ptr','var')
    calllib('xgboost', 'XGBoosterFree',h_booster_ptr); clear h_booster_ptr
    %disp('pointer free');
end


